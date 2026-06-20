---
title: "个人博客部署到阿里云服务器全攻略"
description: "从 GitHub Pages 迁移到阿里云 ECS，完整记录 Nginx 配置、SELinux 排障、CI/CD 自动部署的全过程与踩坑经验。"
pubDate: "Jun 7 2026"
heroImage: "../../assets/covers/cover-aliyun.jpg"
tags: ["部署", "Nginx", "阿里云", "CI/CD"]
---

## 缘起

本站一开始部署在 GitHub Pages 上，免费省心，但有两个问题始终让我不太舒服：

1. **访问速度不稳定**，国内加载有时候慢得离谱
2. **URL 带子路径** `/astro-kaito/`，不够清爽

于是一咬牙买了台阿里云 ECS，打算把博客迁移过去。本以为一两个小时搞定，结果踩了一堆坑。这篇文章把整个过程记录下来，给后来人趟个路。

## 服务器选型

阿里云 ECS 新人白嫖价一年 68 块，配置对我这种纯静态博客来说绰绰有余：

| 项目 | 配置 |
|------|------|
| 实例规格 | 2 vCPU / 2 GiB 内存 |
| 操作系统 | Alibaba Cloud Linux 3 |
| 系统盘 | 40 GiB ESSD |
| 带宽 | 按流量计费，5 Mbps 峰值 |

> **为什么选 Alibaba Cloud Linux 3 而不是 Ubuntu？** CentOS 停更后，这是阿里云主推的免费 Linux，对自家 ECS 兼容性最好。

## 第一步：环境搭建

SSH 登录后装 Nginx 和 Node.js。

### 安装 Nginx

```bash
sudo dnf install nginx -y
sudo systemctl start nginx
sudo systemctl enable nginx
```

打开浏览器访问 `http://公网IP`，看到 Nginx 欢迎页说明 OK。

> **注意**：Alibaba Cloud Linux 3 用 `dnf` 而不是 `apt`。一开始我习惯性敲 `apt` 报错 command not found，愣了三秒才反应过来。

### 安装 Node.js 22

Astro 需要 Node.js ≥ 22。直接装官方源：

```bash
curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash -
sudo dnf install nodejs -y
node -v  # 确认版本
```

### 克隆代码并构建

```bash
sudo mkdir -p /var/www/kaitohub
sudo git clone https://github.com/korolkk/astro-kaito.git /var/www/kaitohub
cd /var/www/kaitohub
npm install
npm run build
```

构建完成后 `dist/` 目录就是我们需要部署的纯静态文件。

## 第二步：Nginx 配置

Alibaba Cloud Linux 3 的 Nginx 配置结构和 Ubuntu 不太一样——没有 `sites-available/` 和 `sites-enabled/` 目录，直接就一个 `/etc/nginx/nginx.conf`。

```nginx
user nginx;
worker_processes auto;

events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    sendfile      on;
    tcp_nopush    on;

    # Gzip 压缩
    gzip            on;
    gzip_types      text/plain text/css application/json
                    application/javascript text/xml image/svg+xml;
    gzip_min_length 256;
    gzip_vary       on;

    server {
        listen       80;
        server_name  你的域名.com;

        root   /var/www/kaitohub/dist;
        index  index.html;

        # 静态资源长期缓存（文件名带 hash）
        location /_astro/ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }

        # SPA 风格路由
        location / {
            try_files $uri $uri/ $uri.html /404.html =404;
        }

        error_page 404 /404.html;
    }
}
```

配置检查并重载：

```bash
sudo nginx -t          # 检查语法
sudo systemctl reload nginx
```

## 第三步：SSL 证书

Let's Encrypt 免费证书 + certbot 自动续期：

```bash
sudo dnf install certbot python3-certbot-nginx -y
sudo certbot --nginx -d 你的域名.com
sudo certbot renew --dry-run   # 测试自动续期
```

## 第四步：踩坑记录

前面说的都是顺利的，真正折磨人的是下面这些坑。

### 坑一：页面只有文字，CSS 和图片全部 404

部署完打开网站，白底黑字，像个 1998 年的网页。

**原因**：本站之前部署在 GitHub Pages 上，URL 子路径是 `/astro-kaito/`。`astro.config.mjs` 里写死了 `base: '/astro-kaito'`，所有 CSS/JS/图片的引用路径都带了 `/astro-kaito/` 前缀。Nginx 从根路径 `/` 提供文件，`/astro-kaito/_astro/style.css` 这个路径根本不存在。

**修复**：把 `base` 改成环境变量控制：

```js
// astro.config.mjs
base: process.env.BASE_URL || '/',
```

- 阿里云构建时：`BASE_URL` 未设置，默认 `/`
- GitHub Pages 构建时：GitHub Actions 注入 `BASE_URL: /astro-kaito`

两边都能正确部署。

### 坑二：SELinux 拦截 Nginx 读取文件

Alibaba Cloud Linux 3 默认开启 SELinux（Enforcing 模式）。Nginx 配置明明正确，文件权限也对，但就是返回 403 Forbidden 或 404。

**排查方法**：

```bash
# 查看 SELinux 审计日志
sudo ausearch -m avc -ts recent

# 临时关闭 SELinux 验证是否是它的问题
sudo setenforce 0
```

果然是 SELinux。Nginx 进程的上下文（`httpd_t`）没有权限读取 `/var/www/kaitohub/dist/` 目录下的文件。

**永久修复**（不要关闭 SELinux，而是正确配置）：

```bash
# 安装 SELinux 管理工具
sudo dnf install policycoreutils-python-utils -y

# 设置目录默认 SELinux 上下文（永久生效）
sudo semanage fcontext -a -t httpd_sys_content_t "/var/www/kaitohub/dist(/.*)?"

# 立即应用
sudo restorecon -R /var/www/kaitohub/dist/

# 允许 Nginx 发起网络连接
sudo setsebool -P httpd_can_network_connect on
```

> **教训**：在 Alibaba Cloud Linux 3 / CentOS / RHEL 系系统上部署 Web 服务，SELinux 永远是头号嫌疑犯。文件权限设对了还不够，SELinux 上下文也得对。而且 `semanage` 配好了就一劳永逸，以后每次部署只需跑 `restorecon` 即可。

### 坑三：GitHub Actions 自动部署的五个连环坑

手动 `scp` 上传几次后实在受不了，决定上 CI/CD。结果光是搭 GitHub Actions 自动部署就踩了五个连环坑。

#### 第一步：配置 Secrets

GitHub Actions 需要通过 SSH 连接到阿里云服务器。需要配置两个东西：

1. **SSH 密钥对**：让 GitHub Actions 免密登录服务器
2. **GitHub Secrets**：安全存储密钥和服务器 IP

**本地生成密钥**：

```powershell
# Windows PowerShell 中执行
ssh-keygen -t ed25519 -f "$env:USERPROFILE\.ssh\aliyun-deploy"
```

提示输入密码时直接回车跳过（CI 环境无法交互式输入密码）。

**上传公钥到服务器**：

```powershell
# Windows 没有 ssh-copy-id，用管道代替
type "$env:USERPROFILE\.ssh\aliyun-deploy.pub" | ssh root@你的服务器IP "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

**配置 GitHub Secrets**：打开仓库 Settings → Secrets and variables → Actions，添加两个 Repository secrets：

| Name | Value |
|------|-------|
| `ALIYUN_HOST` | ECS 公网 IP |
| `ALIYUN_SSH_KEY` | `type ~\.ssh\aliyun-deploy` 输出的完整私钥内容 |

#### 连环坑一：第三方 Action 版本不存在

一开始用了 `easingthemes/ssh-deploy@v5`，结果 CI 直接报错：

```
Error: Unable to resolve action `easingthemes/ssh-deploy@v5`, unable to find version `v5`
```

后来查了一下，这个 Action 根本没有 v5 标签。第三方 Action 的版本号说变就变，线上排错极其痛苦。

**修复**：删掉第三方 Action，直接用 GitHub Actions runner 自带的 SSH 和 tar 命令完成部署。零外部依赖，不需要猜版本号。

#### 连环坑二：secrets 不能用于 job 级别 if 条件

为了让没配 Secrets 的仓库也能正常跑 CI（只部署 GitHub Pages、自动跳过阿里云），我写了这样一个条件：

```yaml
jobs:
  deploy-aliyun:
    if: ${{ secrets.ALIYUN_HOST != '' }}   # ❌ 报错！
```

结果 GitHub Actions 解析器直接报错：

```
Unrecognized named-value: 'secrets'. Located at position 1 within expression: secrets.ALIYUN_HOST != ''
```

**原因**：GitHub Actions 不允许在 job 级别的 `if` 表达式中直接访问 `secrets` 上下文，出于安全考虑。

**修复**：先在 step 中通过 `env` 桥接 secret 值，然后用 step output 控制后续步骤：

```yaml
steps:
  - name: Check if Aliyun secrets configured
    id: check
    env:
      HOST: ${{ secrets.ALIYUN_HOST }}
    run: |
      if [ -n "$HOST" ]; then
        echo "configured=true" >> $GITHUB_OUTPUT
      else
        echo "configured=false" >> $GITHUB_OUTPUT
      fi

  - name: Checkout
    if: steps.check.outputs.configured == 'true'
    uses: actions/checkout@v4

  # ... 后续步骤全部加上这个 if 条件
```

#### 连环坑三：服务端缺少 rsync

最初用 rsync 传输文件：

```bash
rsync -avz --delete -e "ssh -i key" dist/ root@$HOST:/var/www/kaitohub/dist/
```

报错：

```
bash: rsync: command not found
rsync: connection unexpectedly closed
```

**原因**：rsync 协议需要**两端**都安装 rsync——你的电脑（CI runner）是发送端，服务器是接收端。Alibaba Cloud Linux 3 默认没装 rsync。

**修复**：改用 tar 管道传输。tar 是 Linux 标配，不需要额外安装任何东西：

```bash
tar -czf - -C dist . | \
  ssh -i key root@$HOST \
    "rm -rf /var/www/kaitohub/dist/* && \
     tar -xzf - -C /var/www/kaitohub/dist/ && \
     restorecon -R /var/www/kaitohub/dist/ && \
     systemctl reload nginx"
```

一句话完成：打包 → 上传 → 解压 → SELinux 修复 → 重载 Nginx。完全不依赖服务端任何非系统自带工具。

#### 连环坑四：tar 解压后 SELinux 上下文丢失

tar 管道解决了传输问题，但 CI 又报了新错误：

```
chcon: can't apply partial context to unlabeled file 'favicon.ico'
```

**原因**：GitHub Actions 的 Ubuntu runner 没有 SELinux（内核就根本不支持），从那里打包的 tar.gz 文件内部不带任何 SELinux 标签。解压到开启了 SELinux 的服务器后，这些文件处于"未标记"（unlabeled）状态，`chcon` 无法对其设置上下文。

**修复**：两件事配合——

1. **服务器端一次性配置**（坑二中已做）：用 `semanage` 设置目录默认上下文
2. **CI 中用 `restorecon` 替代 `chcon`**：`restorecon` 根据策略文件恢复默认上下文，对无标签文件也能正常工作

```bash
# CI 中的命令最终版
tar -czf - -C dist . | \
  ssh -i key root@$HOST \
    "rm -rf /var/www/kaitohub/dist/* && \
     tar -xzf - -C /var/www/kaitohub/dist/ && \
     restorecon -R /var/www/kaitohub/dist/ && \
     systemctl reload nginx"
```

#### 连环坑五：一个仓库两套 base 路径

GitHub Pages 需要 `base: '/astro-kaito'`，阿里云需要 `base: '/'`。同一个仓库要同时部署到两个地方，构建参数不一样。

**解决方案**：workflow 里拆成两个独立的 job，各自用不同的 `BASE_URL` 构建：

```yaml
# 阿里云构建
- name: Build
  run: npm run build
  env:
    BASE_URL: /

# GitHub Pages 构建
- name: Build
  run: npm run build
  env:
    BASE_URL: /astro-kaito
```

两个 job 并行执行，互不干扰，各自产出正确路径的 dist 文件。

### 完整 workflow 最终版

经过上述五个连环坑的打磨，最终的 deploy.yml 如下（阿里云部署部分）：

```yaml
jobs:
  deploy-aliyun:
    runs-on: ubuntu-latest
    steps:
      - name: Check if Aliyun secrets configured
        id: check
        env:
          HOST: ${{ secrets.ALIYUN_HOST }}
        run: |
          if [ -n "$HOST" ]; then
            echo "configured=true" >> $GITHUB_OUTPUT
          else
            echo "configured=false" >> $GITHUB_OUTPUT
          fi

      - name: Checkout
        if: steps.check.outputs.configured == 'true'
        uses: actions/checkout@v4

      - name: Setup Node
        if: steps.check.outputs.configured == 'true'
        uses: actions/setup-node@v4
        with:
          node-version: 22

      - name: Install dependencies
        if: steps.check.outputs.configured == 'true'
        run: npm ci

      - name: Build
        if: steps.check.outputs.configured == 'true'
        run: npm run build
        env:
          BASE_URL: /

      - name: Deploy to Alibaba Cloud
        if: steps.check.outputs.configured == 'true'
        env:
          HOST: ${{ secrets.ALIYUN_HOST }}
          SSH_KEY: ${{ secrets.ALIYUN_SSH_KEY }}
        run: |
          mkdir -p ~/.ssh
          echo "$SSH_KEY" > ~/.ssh/aliyun_deploy_key
          chmod 600 ~/.ssh/aliyun_deploy_key
          ssh-keyscan -H $HOST >> ~/.ssh/known_hosts
          tar -czf - -C dist . | \
            ssh -i ~/.ssh/aliyun_deploy_key root@$HOST \
              "rm -rf /var/www/kaitohub/dist/* && \
               tar -xzf - -C /var/www/kaitohub/dist/ && \
               restorecon -R /var/www/kaitohub/dist/ && \
               systemctl reload nginx"
```

## 最终效果

现在 `git push` 之后，GitHub Actions 自动完成：

1. 用 `base: /` 构建 → tar 推送 + 解压到阿里云 → `restorecon` 修 SELinux → 重载 Nginx
2. 用 `base: /astro-kaito` 构建 → 上传到 GitHub Pages Artifact → 部署到 Pages

整个过程不到 2 分钟，完全自动化。没配 Secrets 的话自动跳过阿里云部署，不影响 GitHub Pages。

## 总结

部署静态博客到阿里云其实不复杂，核心就三件事：

1. **Nginx 指向 dist 目录**
2. **SELinux 文件上下文正确**（`semanage` 一劳永逸，`restorecon` 日常修复）
3. **Astro base 路径匹配实际部署路径**（环境变量控制，多目标构建）

真正花时间的是那些"明明配置都对但就是不工作"的时刻。主要坑都在 CI/CD 环节：

| 坑 | 症状 | 教训 |
|---|------|------|
| 第三方 Action | 版本不存在报错 | 能用原生命令就别用第三方 Action |
| secrets 在 if | workflow 语法报错 | GitHub Actions 有严格的安全限制 |
| rsync 缺失 | 传输失败 | tar 管道是万能替代方案 |
| SELinux 无标签 | chcon 报错 | `semanage` + `restorecon` 才是正确姿势 |

好在我们有 AI——这篇文章中大部分排障过程都是 Claude 一步一步辅助完成的。

如果你也在折腾博客部署，希望这篇踩坑记录能让你少走弯路。
