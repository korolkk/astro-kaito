---
title: "从 SSH 到 Webhook：让服务器自己部署自己"
description: "经历了 SSH 端口暴露、5000 条 GitHub IP 白名单、密钥格式踩坑后，最终用 Webhook 方案让服务器自主拉取和部署。"
pubDate: "Jun 9 2026"
heroImage: "../../assets/blog-placeholder-about.jpg"
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

在之前写的 API Bridge 服务（Express, 端口 3001）上加了一个 webhook 端点：

```javascript
app.post('/api/deploy', async (req, res) => {
  const { secret } = req.body;

  // 校验密钥（防止陌生人调用）
  if (secret !== DEPLOY_SECRET) {
    return res.status(403).json({ error: '密钥错误' });
  }

  // 先返回 200，部署在后台异步执行
  res.json({ status: 'deploying' });

  // 异步执行部署
  runDeploy();
});

async function runDeploy() {
  // 1. git pull
  execSync('git fetch origin main && git reset --hard origin/main', { cwd: REPO_DIR });

  // 2. 安装依赖 + 构建
  execSync('npm ci && npm run build', { cwd: REPO_DIR });

  // 3. 部署到 Nginx 目录
  execSync('rm -rf /var/www/kaitoblog/dist/* && cp -r dist/* /var/www/kaitoblog/dist/', { cwd: REPO_DIR });
  execSync('restorecon -R /var/www/kaitoblog/dist/');
  execSync('systemctl reload nginx');

  // 4. 更新 API Bridge 自身
  execSync('npm install --omit=dev', { cwd: '/opt/api-bridge' });
  execSync('systemctl restart api-bridge');
}
```

用密钥（`DEPLOY_SECRET`）保护端点，只有持有正确密钥的请求才会触发部署。

### 2. CI 端：一个 curl 搞定

GitHub Actions 的部署步骤从 30 行 SSH 命令简化为：

```yaml
- name: Trigger deploy
  run: |
    curl -X POST "http://${{ secrets.ALIYUN_HOST }}/api/deploy" \
      -H 'Content-Type: application/json' \
      -d '{"secret":"${{ secrets.DEPLOY_SECRET }}"}'
```

只需要两个 Secret：`ALIYUN_HOST`（服务器 IP）和 `DEPLOY_SECRET`（部署密钥）。不再需要 SSH 私钥。

### 3. Nginx 代理

API Bridge 监听 `127.0.0.1:3001`，Nginx 把 `/api/*` 代理过去：

```nginx
location /api/ {
    proxy_pass http://127.0.0.1:3001;
}
```

`/api/deploy` 自然也在代理范围内，不需要额外开端口。

## 对比

| | SSH 推送方案 | Webhook 方案 |
|---|---|---|
| CI 配置 | ~40 行 SSH + tar | ~8 行 curl |
| 需要 Secrets | HOST + SSH_KEY | HOST + DEPLOY_SECRET |
| 安全组 | 需开放 22 端口 | 复用 80/443 |
| IP 白名单 | 5000+ 条不可行 | 不需要 |
| SSH 密钥维护 | 生成/分发/轮换 | 不需要 |
| 部署逻辑 | 写在 CI 里 | 服务器端控制 |
| 故障排查 | CI 日志有限 | journalctl 完整日志 |

## 总结

这个方案的思路转变很简单：**从"推"变成"拉"**。

CI 不再负责把文件传到服务器，只发一个信号。服务器收到信号后自己 `git pull`、自己构建、自己部署。少了 SSH 这一层，少了一大堆麻烦。

而且这个端点本身就架在 API Bridge 上，和 AI 聊天共用同一套基础设施——Nginx 代理、systemd 管理、限流保护。没有任何额外组件。

如果你的项目也在用 GitHub Actions 部署到自有服务器，不妨试试这个思路。只要服务器能访问 GitHub（clone 代码），就不需要 SSH。
