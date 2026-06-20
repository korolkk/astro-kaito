# CLAUDE.md

本文件为 Claude Code（claude.ai/code）在此仓库中工作时提供指引。

## 常用命令

```
npm run dev      # 启动开发服务器 localhost:4321
npm run build    # 构建到 ./dist/
npm run preview  # 本地预览生产构建
npm run astro -- check  # 类型检查项目
```

未配置测试套件或代码检查工具。

## 项目架构

这是一个 **Astro 6** 博客起步模板，使用 TypeScript、Markdown/MDX 内容集合，内置 RSS 和站点地图支持。

### 路由（基于文件）

- `src/pages/index.astro` → `/`（首页）
- `src/pages/blog/index.astro` → `/blog`（文章列表，时间轴布局，支持标签筛选）
- `src/pages/blog/[...slug].astro` → `/blog/:slug`（单篇文章，使用 `getStaticPaths` 进行 SSG）
- `src/pages/about.astro` → `/about`（使用 BlogPost 布局）
- `src/pages/rss.xml.js` → `/rss.xml`（RSS Feed 端点）
- `src/pages/search-index.json.js` → `/search-index.json`（搜索索引 JSON）

### 内容

博客文章存放在 `src/content/blog/` 中，格式为 `.md` 或 `.mdx`。集合 schema 在 `src/content.config.ts` 中通过 `astro:content` 定义。必填 frontmatter：`title`（字符串）、`description`（字符串）、`pubDate`（日期）。可选：`updatedDate`（日期）、`heroImage`（图片）、`tags`（字符串数组，默认空数组）。

通过 `getCollection('blog')` 加载文章，通过 `render(post)` 渲染文章内容。

### 布局与组件

- **`src/layouts/BlogPost.astro`** — 博客文章和关于页面的共享布局。接收 `title`、`description`、`pubDate`、`updatedDate?`、`heroImage?`、`tags?`、`prevPost?`、`nextPost?` 作为 props，通过 `<slot />` 渲染内容。包含阅读进度条、标签展示、封面图、上一篇/下一篇导航。
- **`src/components/BaseHead.astro`** — `<head>` 元数据（charset、viewport、OG 标签、Twitter 卡片、canonical URL、favicon、字体预加载、防 FOUC 主题脚本）。使用 `Astro.site` 和 `Astro.url`。
- **`src/components/Header.astro`** — 网站头部导航，包含导航链接（首页、博客、关于）、内联搜索框（含搜索索引加载和结果渲染）、主题切换下拉菜单（亮色/暗色/跟随系统）。内部使用 `HeaderLink.astro` 实现激活状态样式。导航栏卡片式设计，上直角下圆角。
- **`src/components/HeaderLink.astro`** — 单个导航链接，通过匹配 `Astro.url.pathname` 检测激活状态。
- **`src/components/Footer.astro`** — 页面底部，包含版权年份和返回顶部按钮（固定右下角，滚动超过 400px 显示）。
- **`src/components/FormattedDate.astro`** — 根据 `Date` prop 渲染 `<time>` 元素。

### 样式与字体

- **`src/styles/global.css`** — 全局样式，包含用于主题的 CSS 自定义属性（颜色变量如 `--accent`、`--black`、`--gray`、`--card-bg`、`--page-bg` 等）。由 `BaseHead.astro` 引入，确保每个页面都加载。
- **字体** — Atkinson Hyperlegible，通过 Astro 的 `fontProviders.local()` 在 `astro.config.mjs` 中本地加载。配置为 CSS 变量 `--font-atkinson`。

### 构建产物中 CSS 的分布

- **全局 CSS**（`global.css`，由 `BaseHead.astro` import）：构建时被 Vite 合并到 `dist/_astro/Header.xxx.css`（与 Header 组件的 scoped 样式打包在一起），通过 `<link rel="stylesheet">` 引入。不在 `<style>` 标签中。
- **页面级 scoped 样式**（如 `index.astro` 中的 `<style>`）：直接内联在 HTML 的 `<style>` 标签中，带 `data-astro-cid` 属性选择器。
- **Lightning CSS 压缩**：Astro 6 使用 Lightning CSS 作为 CSS 压缩器，会自动将 `border-top-left-radius: 0; border-top-right-radius: 0; border-bottom-left-radius: 20px; border-bottom-right-radius: 20px;` 这样的长写法合并回简写 `border-radius:0 0 20px 20px`。验证 CSS 时应检查 `dist/` 产物而非源码。

## 开发规则

### 1. Edit 工具的 tab/space 匹配问题（高频坑）
`.astro` 文件使用 **tab** 缩进。Edit 工具的 `old_string` 若使用空格则匹配失败。
- **单行修改**：用 `replace_all: true`
- **多行修改**：直接用 `Write` 工具重写整个文件，比反复尝试 Edit 更高效

### 2. 对齐问题的根因：`box-sizing` 和 Flex vs Grid
- **始终在全局样式中加入 `box-sizing: border-box`**，否则 `max-width` + `padding` 会导致实际宽度超出预期（content-box 下 padding 加在 width 外面）
- **`1/3 + 2/3` 分栏用 CSS Grid 而非 Flex**：Grid 的 `1fr 2fr` 从扣除 `gap` 后的剩余空间分配比例，Flex 的 `33.333% + 66.666%` + `gap` 会溢出

### 3. 导航栏与页面内容宽度对齐
导航栏 `.nav-inner` 的 `max-width: 1140px` 和 `padding: 0.6em 2em`，页面 `main` 的 `width` 和 `padding-left/right` 必须匹配才能对齐。全局 `main` 的默认 `padding: 3em 1em`，博客列表页需要覆盖为 `width: 1140px; padding-left: 2em; padding-right: 2em` 才能与导航栏严格对齐。

### 4. Hover 下拉菜单的鼠标桥接
`margin-top` 会在按钮与下拉菜单之间产生间隙，鼠标移过间隙时 `:hover` 断开导致菜单消失。
- **修复**：在父容器上添加 `::after { content: ''; position: absolute; inset: 100% 0 auto 0; height: 10px; }` 作为隐形桥接，并将 `margin-top` 缩小到 `1px`

### 5. 主题切换的防闪烁（FOUC）
暗色模式切换脚本必须在 `<head>` 中**同步执行**（阻塞渲染），在首帧绘制前设置 `data-theme`。否则暗色模式用户会看到白色闪烁。使用 `localStorage` 持久化选择，`matchMedia('(prefers-color-scheme: dark)')` 跟随系统。

### 6. 主题色实现模式
- 所有颜色通过 CSS 变量定义，亮色在 `:root`，暗色在 `[data-theme='dark']`
- 卡片背景、页面背景等**必须用变量**（如 `var(--card-bg)`），不能用硬编码的 `#fff` 或 `rgba(255,255,255,1)`
- `color-scheme: light/dark` 属性告诉浏览器使用对应的原生控件样式（滚动条、表单等）

### 7. 浏览器缓存导致"改了但没生效"
CSS 修改后用户反馈"没变化"，常见原因：
- Vite dev server 的 HMR 对 `import` 的 `.css` 文件不总是热更新 → 重启 `npm run dev`
- 浏览器缓存旧 CSS → 硬刷新 `Ctrl+Shift+R`
- 构建后的 CSS 文件名 hash 变化说明内容已更新，若 hash 没变说明内容确实没变

### 8. Astro 图片缓存的清理（关键坑）
替换或删除 `src/assets/` 中的图片后，构建产物可能仍包含旧图片。原因：Astro 在 `node_modules/.astro/assets/` 中维护资产缓存。
- **替换/删除图片后必须执行**：`rm -rf node_modules/.astro dist .astro && npm run build`
- 仅删 `dist/` 不够，`node_modules/.astro/` 是 Vite 的持久化缓存，dev server 也依赖它
- 验证命令：`find . -path "*/node_modules" -prune -o -name "*图片名*" -print`

### 9. Hexo → Astro 博客迁移要点
- **Frontmatter 转换**：`date: YYYY-MM-DD HH:MM:SS` → `pubDate: 'Mon DD YYYY'`，`tags/categories/id` 移除，需生成 `description`
- **CRLF 坑**：Hexo 的 `.md` 文件常使用 Windows CRLF 换行，正则匹配 frontmatter 时需 `\r?\n`
- **图片目录**：Hexo 文章图片放在同名子目录中，迁移后相对路径引用不变，直接复制即可
- **封面图**：迁移后 `blog-placeholder-1~5.jpg` 随机分配 `heroImage`

### 10. Astro 性能优化原则
本项目以 Astro 6 为核心，追求极致页面加载速度。所有开发决策必须遵循 Astro 的"零 JS 默认"理念：
- **默认零 JS**：页面应尽可能为纯静态 HTML/CSS，不引入客户端 JS。交互功能（搜索、主题切换、标签筛选等）的 JS 必须内联在 `<script>` 中，不通过外部文件加载。禁止引入任何 JS 框架（React、Vue 等）。
- **图片优化**：使用 Astro 内置的 `<Image />` 组件自动生成 WebP/AVIF 多格式、多尺寸响应式图片。文章内的本地图片应放在文章同名目录下，由 Astro 自动优化。
- **CSS 管理**：全局样式通过 `BaseHead.astro` import 的 `global.css` 提供（CSS 变量、重置、排版），组件样式使用 `<style>` 标签 scoped 到组件。避免 CSS 框架（Tailwind 等），手写轻量 CSS。
- **字体策略**：使用 `astro.config.mjs` 中 `fontProviders.local()` 本地托管字体，避免外部 Google Fonts 请求。预加载关键字体子集，使用 `font-display: swap` 防止 FOIT。
- **构建产物检查**：每次重大修改后运行 `npm run build`，检查 `dist/` 中是否有不必要的 JS 文件、过大的图片或未压缩的资源。目标：Lighthouse 评分 100/100。
- **缓存策略**：静态资源（图片、字体、CSS）带有内容哈希文件名，可设置长期缓存。HTML 页面使用 `Astro.site` 生成准确的 canonical URL，SEO 友好。

### 11. `is:inline` 脚本与 Astro 模块作用域（关键坑）
Astro 6 默认将 `.astro` 组件中的 `<script>` 处理为 `<script type="module">`，这会导致两个问题：
- **模块作用域隔离**：`document.getElementById()` 在模块脚本顶层获取 DOM 可能返回 null（因为模块延迟执行，DOM 可能已渲染但变量被隔离）
- **全局变量冲突**：多个 `<script is:inline>` 共享全局作用域，同名变量（如 `let ticking`）会报错
- **修复**：所有需要 DOM 操作的脚本必须使用 `<script is:inline>` + IIFE 包裹（`(function() { ... })()`），避免变量冲突
- **事件委托**：当按钮内包含 SVG 子元素时，用 `btn.contains(e.target)` 而非 `e.target === btn`，确保点击子元素也能正确响应

### 12. 时间轴布局与标签筛选模式
博客列表页使用 CSS Grid 四栏时间轴布局：`grid-template-columns: 100px 28px 1fr 160px`（日期 / 圆点连线 / 内容 / 封面）。
- **年份分组**：在 Astro 模板中使用 `let currentYear = 0` 追踪年份，新年份首篇文章添加 `year-break` 类显示年份标题并高亮圆点
- **标签筛选**：客户端 JS 读取 URL `?tag=xxx` 参数，通过 `data-tags` 属性和 `classList.toggle('hidden')` 过滤文章，`history.replaceState()` 更新 URL
- **响应式**：≤800px 隐藏封面列，≤500px 缩窄日期列
- 标签数据从 `getCollection('blog')` 的结果中提取：`[...new Set(posts.flatMap(p => p.data.tags || []))].sort()`

### 13. Astro Scoped CSS 与动态 DOM 元素（关键坑）
Astro 的 `<style>` 标签编译后会生成 `data-astro-cid-HASH` 属性选择器，但 `document.createElement()` 创建的元素**不会自动获得**这个属性，导致 scoped 样式对动态元素**完全不生效**。

- **判断方法**：scoped 的 class 写在 CSS 里但浏览器 DevTools 中元素没有对应样式 → 一定是缺了 cid 属性
- **修复**：遍历父元素的 attributes，找到以 `data-astro-cid` 开头的属性名，然后用 `setAttribute` 应用到所有动态元素

```js
var CID = '';
(function () {
    var root = document.getElementById('mySection');
    if (!root) return;
    for (var i = 0; i < root.attributes.length; i++) {
        if (root.attributes[i].name.indexOf('data-astro-cid') === 0) {
            CID = root.attributes[i].name; break;
        }
    }
})();
function cid(el) { if (CID) el.setAttribute(CID, ''); return el; }

// 所有动态创建的元素都包一层 cid()
var div = cid(document.createElement('div'));
div.className = 'my-scoped-class'; // 现在样式会生效
```

- **注意**：不能用 `getAttribute('data-astro-cid')` 直接读取，因为实际属性名是 `data-astro-cid-xxxxx`（带随机后缀），必须遍历查找前缀匹配

### 14. 评论系统与动态功能的架构模式
站点是纯 SSG（`output: 'static'`），所有需要服务端的功能（评论、AI 聊天、问答、部署 webhook）必须走独立的 **API Bridge**：

- **API Bridge**：Express.js 服务，部署在 `/opt/api-bridge/`，监听 `127.0.0.1:3001`
- **生产环境**：Nginx 将 `/api/*` 代理到 `http://127.0.0.1:3001`
- **本地开发**：Astro dev server（:4321）和 API Bridge（:3001）端口不同，需在 `astro.config.mjs` 中添加 Vite proxy：

```js
vite: {
    server: {
        proxy: { '/api': 'http://localhost:3001' },
    },
},
```

- **API 不可用处理**：前端 fetch 必须处理 404（`resp.status === 404` → 显示"服务未配置"）、429（限流）、网络异常（`catch` → "服务不可用"）
- **安全**：所有 API 端点独立限流（`express-rate-limit`），评论内容用 `textContent` 渲染防 XSS，服务端做长度截断兜底
- **新增 API 端点**：在 `api-bridge/server.js` 中添加路由 + 限流器，部署脚本已自动处理依赖安装和服务重启

### 15. SQLite 选型：sql.js vs better-sqlite3
- **`better-sqlite3`**：Node 原生扩展，同步 API，性能好，但需要本地编译（node-gyp + C++ 工具链）。预编译二进制不一定覆盖所有 Node 版本/平台（比如 Node 24 on Windows 就没有）
- **`sql.js`**：纯 WASM 实现，零编译，跨平台通吃。代价是整个数据库加载到内存，写操作后需手动持久化：

```js
import initSqlJs from 'sql.js';
const SQL = await initSqlJs();
const db = new SQL.Database(buffer); // 从磁盘加载
// ... 操作 ...
const data = db.export();
writeFileSync(dbPath, Buffer.from(data)); // 写回磁盘
```

- **本项目选择 sql.js**：优先保证"任何环境 clone 下来都能跑"，牺牲一点性能换取零配置。评论量不大的场景完全够用

### 16. `mkdir -p` 幂等性（部署脚本安全）
`mkdir -p`（Linux）和 `mkdirSync(path, { recursive: true })`（Node.js）在目录已存在时静默跳过，不报错。部署脚本中放心使用，不会因为重复执行产生冲突。

### 17. Windows 下 node_modules 文件锁定
Windows 上 `rm -rf node_modules` 经常失败（`EBUSY: resource busy or locked`），原因是后台 Node 进程或杀毒软件持有文件句柄。
- **修复**：先 `taskkill /F /IM node.exe` 关闭所有 Node 进程，再删除
- **验证安装**：`npm install` 超时或无响应时，检查是否有残留 node 进程

### 18. Git 提交前检查清单
- `api-bridge/data/` 目录（测试数据库文件）**不能提交**，已在 `.gitignore` 中排除
- 构建产物 `dist/` 不能提交
- `node_modules/` 不能提交
- `.env` 文件（含真实密钥）不能提交，只提交 `.env.example` 模板

### 19. 文章封面图生成策略

为新建文章生成 `heroImage` 封面时，使用 sharp 生成主题渐变色封面（720×240），避免使用通用占位图。

- 封面存放在 `src/assets/covers/` 目录
- 根据文章主题选择配色，例如：
  - AI/机器学习 → 紫蓝色调 `[[88,55,140], [30,60,150]]`
  - 部署/运维 → 青绿色调 `[[15,100,85], [40,140,100]]`
  - 云服务 → 橙红色调 `[[180,80,30], [230,140,60]]`
  - 教程/工具 → 蓝色调 `[[40,60,140], [120,80,200]]`
  - 算法/竞赛 → 深蓝灰色调 `[[30,40,60], [60,90,140]]`
  - 项目实战 → 暖色调 `[[180,100,40], [220,160,80]]`
- 生成脚本模板：

```js
const sharp = require('sharp');
const W = 720, H = 240;
const pixels = Buffer.alloc(W * H * 3);
const [r1, g1, b1] = colors[0];
const [r2, g2, b2] = colors[1];
for (let y = 0; y < H; y++) {
  for (let x = 0; x < W; x++) {
    const t = (x / W + y / H) / 2;
    pixels[(y * W + x) * 3] = Math.round(r1 + (r2 - r1) * t);
    pixels[(y * W + x) * 3 + 1] = Math.round(g1 + (g2 - g1) * t);
    pixels[(y * W + x) * 3 + 2] = Math.round(b1 + (b2 - b1) * t);
  }
}
// 加微噪点纹理后保存
await sharp(pixels, { raw: { width: W, height: H, channels: 3 } })
  .jpeg({ quality: 85 })
  .toFile('src/assets/covers/cover-xxx.jpg');
```

- 生成后在文章 frontmatter 中引用：`heroImage: ../../assets/covers/cover-xxx.jpg`

## 站点配置

全局常量（`SITE_TITLE`、`SITE_DESCRIPTION`）定义在 `src/consts.ts` 中。`astro.config.mjs` 中的 `site` URL 应在上线前从 `https://example.com` 改为实际域名。

**站点 URL**：GitHub `https://github.com/korolkk`，邮箱 `704788475@qq.com`。
