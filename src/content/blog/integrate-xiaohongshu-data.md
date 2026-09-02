---
title: "给博客接入小红书数据：从 RSSHub 到自研 Chromium 直抓的折腾之旅"
description: "想在首页展示小红书最新笔记、后台统计互动数据？记录从自建 RSSHub、解决 OOM 与依赖冲突，到最终用无头浏览器直抓页面数据的完整踩坑过程与解决方案。"
pubDate: "Aug 31 2026"
heroImage: "../../assets/covers/cover-xiaohongshu-handdrawn.png"
tags: ["小红书", "爬虫", "RSSHub", "Docker", "部署", "踩坑记录"]
---

## 缘起

这个博客的首页一直有「GitHub 贡献」热力图，用的是第三方 API。某天忽然想到：为什么不把小红书账号的数据也接进来？在首页展示最新笔记、后台统计点赞评论，让个人站点更"活"一点。

需求很明确：
1. 首页展示最新 1-2 篇小红书图文（封面、标题、互动数据）
2. 后台管理页统计点赞、评论、收藏等数据

听起来简单，实际走下来却是九九八十一难。这篇文章把完整的折腾过程记录下来，希望能帮到同样想在自建站点接入小红书数据的朋友。

## 方案选型：为什么选 RSSHub

第一步就碰壁了。调研之后发现：

- **小红书官方开放平台**：个人开发者申请不到笔记数据读取权限（需要企业资质）
- **直接调小红书网页接口**：需要登录态 cookie，且接口有 `x-s` 签名校验
- **第三方数据服务**：需要付费订阅

最后选择了 **自建 RSSHub**——它是开源的 RSS 生成器，内置小红书路由，只需要在服务器上部署一个实例，再配置小红书 cookie 即可。

```
GitHub 账号 → RSSHub（抓取小红书）→ api-bridge（缓存+聚合）→ 首页/后台展示
```

## 第一关：服务器上装 Docker

服务器是阿里云 1.8GB 内存的小机子，系统是 Alibaba Cloud Linux。`dnf install docker` 装完之后发现——装的是 **podman**（Docker CLI 兼容层），没有 docker daemon，但 `docker` 命令可以直接用，问题不大。

真正的坑在**拉取镜像**：国内服务器直连 Docker Hub 直接被拒（连接超时）。解决方法是配置镜像加速源：

```ini
# /etc/containers/registries.conf
unqualified-search-registries = ["docker.io"]

[[registry]]
prefix = "docker.io"
location = "docker.1panel.live"
```

配置后 `docker pull diygod/rsshub:latest` 成功。

## 第二关：podman 端口映射失效

镜像拉下来了，容器也启动了，日志显示 "RSSHub is running"，但宿主机 curl 却 `Connection refused`。排查半天发现：**podman 的 CNI 端口映射虽然声明了 `-p 1200:1200`，但流量根本进不了容器**（容器内访问自己正常，宿主机访问被拒）。

解决方法：改用 **host 网络模式**，容器直接监听宿主机端口，绕开端口转发：

```bash
docker run -d --name rsshub --network=host diygod/rsshub:latest
```

## 第三关：Node 模式部署的连环坑

以为 Docker 搞定就万事大吉？手动部署脚本还准备了 Node 模式（服务器没 Docker 时），这一路更是坑连坑：

### 1. git clone 目录冲突

脚本先 `mkdir -p /opt/rsshub/data` 创建了父目录，之后 `git clone` 到 `/opt/rsshub` 时报"目标路径已存在且非空"。修复：代码目录改到 `/opt/rsshub/app`，与数据目录分离。

### 2. GitHub 直连超时

国内服务器访问 `github.com` 经常 `RPC failed`。给脚本加了**镜像自动回退**：直连失败依次尝试 `gh-proxy.com`、`ghfast.top` 等镜像，重试 3 轮。

### 3. npm 依赖冲突

`npm install` 报 `ERESOLVE`：RSSHub 上游的 eslint 10 与 eslint-nibble 的 peer 依赖（只支持 7/8/9）冲突。解决：加 `--legacy-peer-deps`。

### 4. OOM 被杀

这是最折磨人的一个。npm 安装原生模块（sharp 等）时内存爆掉，进程被系统 OOM killer 干掉，提示就是一句"已终止"。1.8GB 内存 + 常驻的 openclaw 网关（占 400MB+），根本不够。

解决：给服务器加 2GB swap：

```bash
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab
```

### 5. 缺 dist 构建产物

装完依赖启动服务，报 `Cannot find module dist/index.mjs`。原来 RSSHub 新版是 TypeScript 源码，需要先 `npm run build` 生成产物，而 build 依赖 devDependencies 里的构建工具（tsx/tsdown/typescript），`--omit=dev` 安装后缺失。补装构建工具再 build 解决。

## 第四关：Cookie 的两类之分

一路披荆斩棘终于把 RSSHub 跑起来了，结果请求小红书路由返回 `503`，日志提示"小红书未返回用户数据"。

用无头浏览器直接探测页面，发现**页面其实正常加载**（标题都显示出来了），但 RSSHub 就是解析不到数据。扒了它的源码才发现：

- RSSHub 先用 `edith.xiaohongshu.com/api/sns/web/v2/user/me` 校验 cookie，要求返回 `code === 0`
- 我最初提供的 cookie 是**小红书创作中心（creator）**的登录态（字段带 `x-user-id-creator`），RSSHub 的小红书 user 路由用的是**普通网页版**接口，两类凭证不通用
- 换成网页版 cookie（含 `web_session`）后，API 校验依然不过（小红书对该接口有签名要求）
- 即便走 Puppeteer 回退，RSSHub 解析 `__INITIAL_STATE__.user` 的结构也跟不上小红书最近的页面改版

**结论：RSSHub 上游与小红书最新页面结构不兼容**，只能等它更新。但我不打算干等。

## 最终方案：自研 Chromium 直抓

既然 Chromium 能打开页面、页面里也有完整数据，那为什么不自己解析？

调研发现小红书页面把数据塞在 `window.__INITIAL_STATE__` 这个全局对象里，笔记数据路径是：

```
__INITIAL_STATE__.user.notes._value[0][N].noteCard
```

字段结构（用 Chromium 实测确认）：

```js
{
  noteId: "6a93e8e8...",
  displayTitle: "H.264和H.265，嵌入式怎么选",
  time: 1788078312000,          // 毫秒时间戳
  interactInfo: { likedCount: "1" },
  cover: { url: "http://sns-webpic-qc.xhscdn.com/..." },
  user: { nickname: "小师傅KK" }
}
```

于是直接在 api-bridge 里写了个抓取器：用 playwright-core 启动无头 Chromium → 注入 cookie → 打开用户主页 → 解析 `__INITIAL_STATE__` → 提取笔记列表，带 10 分钟缓存。RSSHub 作为备用通道保留（上游修复后自动切换）。

### 给无头浏览器装 Chromium 也是一场战斗

服务器 1.8GB 内存，在 RSSHub 容器里 `npm install playwright` 直接 OOM。换个思路：

1. **宿主机空目录装 playwright-core**（避开 RSSHub 巨大的依赖树，几乎不吃内存）
2. **从 npmmirror 镜像下载 Chromium**（默认的 cdn.playwright.dev 国内访问不了）：

```bash
export PLAYWRIGHT_BROWSERS_PATH=/opt/pw-tmp/browsers
export PLAYWRIGHT_DOWNLOAD_HOST=https://cdn.npmmirror.com/binaries/playwright
npx playwright-core install chromium
```

3. 宿主机 `dnf` 安装 Chromium 系统依赖（libglib、libnss3、libgbm 等一堆）
4. 浏览器启动参数加内存保护：

```js
chromium.launch({
  headless: true,
  args: ['--no-sandbox', '--disable-dev-shm-usage', '--disable-gpu', '--single-process'],
});
```

### 数据终于通了

抓取器上线后，`/api/xhs/posts` 返回真实数据。首页展示最新笔记卡片、后台统计点赞数，全部跑通。

有意思的是：DOM 探测确认账号当前**公开笔记只有 1 篇**——不是抓不到，是数据本来就这么多。😂

## 第五关：封面图的防盗链

数据通了，但首页封面上来就"不显示"。排查发现小红书 CDN 有**防盗链**：

1. 封面 URL 里的 `!nc_n_webp_mw_1` 这类参数**不能去掉**，去掉后返回 403
2. 浏览器端直接加载 `sns-webpic-qc.xhscdn.com` 仍会被 referrer 拦截

解法：**后端代理**。api-bridge 加一个 `/api/xhs/cover` 接口，服务器带着小红书 Referer 抓图转发给浏览器，附 1 小时缓存：

```js
app.get('/api/xhs/cover', async (req, res) => {
  // 校验域名白名单 → fetch 小红书 CDN（带 Referer）→ 转发图片
});
```

## 第六关：Service Worker 缓存背刺

封面正常了，但发现一个诡异现象：**强刷封面正常，普通刷新就不显示，再强刷又恢复**。

根因在 Service Worker：我之前的 sw.js 对非导航请求是"缓存优先"，`/api/xhs/posts` 和 `/api/xhs/cover` 都被缓存了。普通刷新时返回**缓存的旧 API 响应**，旧数据里的封面是**已过期的 CDN 签名链接**（403），封面就挂了。

修复：**SW 跳过所有 `/api/*` 请求**（动态数据不缓存，交给服务端 Cache-Control 管理），缓存版本升级并清理旧缓存。

```js
// sw.js fetch handler
if (url.pathname.startsWith('/api/')) return; // 动态数据不拦截
```

## 顺带踩的坑：Astro scoped CSS 不管动态元素

小红书卡片是 JS 动态创建的（`document.createElement`），而它的样式写在了 `index.astro` 的 scoped `<style>` 里。Astro 的 scoped CSS 会给选择器加 `data-astro-cid` 属性，**动态元素没有这个属性，样式全部失效**——点赞图标变成 305px 大图、间距全乱。

用 Chromium 检查渲染后的 DOM 才发现（`getComputedStyle` 显示 svgWidth: 305px），教训是：**动态渲染组件的样式必须放 global.css**。

## 收获与总结

这一趟下来，几个核心经验值得记住：

1. **自建数据源选型**：小红书这类强反爬平台，官方 API 门槛高、第三方接口不稳定，自研无头浏览器抓取反而是最可控的方案
2. **小内存服务器**：swap 是标配；npm 装依赖挑空目录避开依赖树；Docker 镜像优先于本地编译
3. **国内网络环境**：GitHub、Docker Hub、playwright CDN 都要提前想好镜像源
4. **Service Worker 是双刃剑**：缓存优先策略绝不能用于 API 动态数据，含签名时效的 URL 只能走网络
5. **Astro scoped CSS 的边界**：JS 动态元素的样式要放全局

现在博客首页能实时展示小红书最新笔记，后台能看互动统计——虽然目前只有 1 篇笔记，但基础设施已经就绪，以后发新笔记自动同步。折腾的过程本身就是最好的学习，希望这篇文章能帮你少走几个坑。
