---
title: "从 SSH 到 Webhook：让服务器自己部署自己"
description: "经历了 SSH 端口暴露、5000 条 GitHub IP 白名单、密钥格式踩坑后，最终用 Webhook 方案让服务器自主拉取和部署，顺便踩了三个新坑。"
pubDate: "Jun 9 2026"
heroImage: "../../assets/covers/cover-webhook-self-deploy.png"
tags: ["部署", "CI/CD", "GitHub Actions", "DevOps"]
---

## 起点：SSH 推送方案

之前搭建了 GitHub Actions 自动部署到阿里云，架构很直接：CI 构建 → tar 打包 → SSH 传到服务器 → 解压 → 重载 Nginx。

这套方案跑了一段时间，直到我做了一件事：**把 SSH 端口限制为本机 IP**。

然后 CI 就挂了。

## 问题一：IP 白名单不可行

GitHub Actions 跑在微软云上，IP 段是动态的。我查了一下 GitHub 官方 API，Actions 的 IPv4 段有 **5218 条**。阿里云安全组单条规则上限 100 条，根本加不完。

即使能加完，维护成本也极高——GitHub 不定期增删 IP，每次变更都要手动同步。

## 问题二：SSH 密钥格式坑

在排查过程中还发现一个隐藏问题：GitHub Secrets 中存储的 SSH 私钥，通过 `echo "$SSH_KEY" > file` 写入时会**丢失末尾换行符**，导致 SSH 报 `Load key ... invalid format`。

这玩意儿排查起来极其痛苦——本地测是好的，CI 里就挂。最终用 `printf '%s\n'` 替代 `echo` 解决，但心理上已经对 SSH 方案产生了不信任。

## 换个思路：让服务器主动拉取

与其让 CI 费劲巴拉地推送到服务器，不如反过来：

```
GitHub push → CI 发一个 HTTP POST → 服务器收到 → git pull → build → deploy
```

CI 只负责**通知**，服务器自己完成**拉取和部署**。好处：

- **不需要 SSH**：一个 HTTP 请求就够了
- **不需要开端口**：Nginx 已经在监听 80/443
- **安全组不用改**：现有的 Web 端口复用
- **服务器完全掌控部署逻辑**：不在 CI 里写复杂的 shell

## 实现

### 1. 服务端：新增 `/api/deploy` 端点

在之前写的 API Bridge 服务（Express, 端口 3001）上加了一个 webhook 端点，带密钥校验：

```javascript
app.post('/api/deploy', async (req, res) => {
  const { secret } = req.body;

  if (secret !== DEPLOY_SECRET) {
    return res.status(403).json({ error: '密钥错误' });
  }

  // 先返回 200，部署在后台异步执行
  res.json({ status: 'deploying' });

  runDeploy().catch((err) => {
    console.error('[deploy] 部署失败:', err.message);
  });
});
```

部署逻辑拆成清晰的五步：

```javascript
async function runDeploy() {
  // 1. 拉取最新代码
  run('git fetch origin main && git reset --hard origin/main', REPO_DIR);

  // 2. 先更新 API Bridge 自身依赖（只装不重启，避免杀进程）
  run('npm install --omit=dev', '/opt/api-bridge');

  // 3. 安装博客依赖 + 构建
  run('npm ci', REPO_DIR);
  run('BASE_URL=/ npm run build', REPO_DIR);  // systemd 环境需显式传入

  // 4. Nginx 直接指向构建目录，仅需 SELinux 修复 + 重载
  run('restorecon -R /var/www/kaitohub/dist', REPO_DIR);
  run('systemctl reload nginx', REPO_DIR);

  // 5. 最后才重启 API Bridge（部署全部完成，不怕杀进程）
  run('systemctl restart api-bridge', REPO_DIR);
}
```

注意几个细节：
- **`BASE_URL=/`**：systemd 启动的服务没有这个环境变量，必须显式传入，否则 Astro 不知道 `base` 该用啥
- **步骤顺序**：API Bridge 依赖先装（不重启），博客构建部署完成后最后才 `restart`，避免中途杀进程
- **不用 `cp`**：因为服务器上 `git clone` 的仓库就在 `/var/www/kaitohub`，Nginx 的 `root` 直接指向它的 `dist/` 子目录，构建产物天然就在正确位置，不需要额外复制

### 2. CI 端：一个 curl 搞定

GitHub Actions 的部署步骤从 40 行 SSH 命令简化为 8 行：

```yaml
- name: Trigger Alibaba Cloud deploy
  env:
    HOST: ${{ secrets.ALIYUN_HOST }}
    DEPLOY_SECRET: ${{ secrets.DEPLOY_SECRET }}
  run: |
    curl -X POST "http://$HOST/api/deploy" \
      -H 'Content-Type: application/json' \
      -d "{\"secret\":\"$DEPLOY_SECRET\"}"
```

只需要两个 Secret（`ALIYUN_HOST` + `DEPLOY_SECRET`），不再需要 SSH 私钥。

### 3. Nginx 代理

API Bridge 监听 `127.0.0.1:3001`，Nginx 把 `/api/*` 代理过去：

```nginx
location /api/ {
    proxy_pass http://127.0.0.1:3001;
}
```

`/api/deploy` 自然也在代理范围内，不需要额外开端口。

## 实战中踩的三个坑

### 坑一：Shiki 不认识 `vbnet`

旧博客里有一段代码标记为 `vbnet`，但实际是 Go 代码。之前在 GitHub Actions 上构建时 Shiki 只是警告，换到服务器本地构建后，新版 Shiki 对未知语言处理变严格，直接导致构建失败。

**教训**：代码块的语言标记要写对的，别指望工具一直包容你。

### 坑二：systemd 环境没有 `BASE_URL`

`astro.config.mjs` 里写了 `base: process.env.BASE_URL || '/'`，本意是本地开发默认 `/`，CI 构建时注入。但 systemd 启动的服务压根没有这个环境变量，构建出来的页面路径全乱了。

**教训**：别假设环境变量一定存在，关键变量在命令中显式传入最稳妥。

### 坑三：多余的 `cp` 操作

最开始从 SSH 方案迁移时，顺手保留了 `rm -rf` + `cp -r` 的步骤。结果因为构建目录和 Nginx 目录是同一个，`cp` 报 `same file` 错误。删掉后才发现——根本不需要复制，构建产物已经在正确位置了。

**教训**：换方案时不要把旧逻辑无脑搬过来，想清楚每一步是否还有必要。

## 对比

| | SSH 推送方案 | Webhook 方案 |
|---|---|---|
| CI 配置 | ~40 行 SSH + tar | ~8 行 curl |
| 需要 Secrets | HOST + SSH_KEY | HOST + DEPLOY_SECRET |
| 安全组 | 需开放 22 端口 | 复用 80/443 |
| IP 白名单 | 5000+ 条不可行 | 不需要 |
| SSH 密钥维护 | 生成/分发/轮换 | 不需要 |
| 部署逻辑 | 写在 CI 里 | 服务器端控制 |
| 故障排查 | CI 日志有限 | journalctl -u api-bridge -f |

## 总结

这个方案的思路转变很简单：**从"推"变成"拉"**。

CI 不再负责把文件传到服务器，只发一个信号。服务器收到信号后自己 `git pull`、自己构建、自己部署。少了 SSH 这一层，也少了一大堆麻烦。

而且这个端点本身就架在 API Bridge 上，和 AI 聊天共用同一套基础设施——Nginx 代理、systemd 管理、限流保护。没有任何额外组件。

如果你的项目也在用 GitHub Actions 部署到自有服务器，不妨试试这个思路。只要服务器能访问 GitHub（能 clone 代码），就不需要 SSH。
