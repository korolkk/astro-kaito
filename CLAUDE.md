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
- `src/pages/blog/index.astro` → `/blog`（文章列表）
- `src/pages/blog/[...slug].astro` → `/blog/:slug`（单篇文章，使用 `getStaticPaths` 进行 SSG）
- `src/pages/about.astro` → `/about`（使用 BlogPost 布局）
- `src/pages/rss.xml.js` → `/rss.xml`（RSS Feed 端点）

### 内容

博客文章存放在 `src/content/blog/` 中，格式为 `.md` 或 `.mdx`。集合 schema 在 `src/content.config.ts` 中通过 `astro:content` 定义。必填 frontmatter：`title`（字符串）、`description`（字符串）、`pubDate`（日期）。可选：`updatedDate`（日期）、`heroImage`（图片）。

通过 `getCollection('blog')` 加载文章，通过 `render(post)` 渲染文章内容。

### 布局与组件

- **`src/layouts/BlogPost.astro`** — 博客文章和关于页面的共享布局。接收 `title`、`description`、`pubDate`、`updatedDate?`、`heroImage?` 作为 props，通过 `<slot />` 渲染内容。
- **`src/components/BaseHead.astro`** — `<head>` 元数据（charset、viewport、OG 标签、Twitter 卡片、canonical URL、favicon、字体预加载）。使用 `Astro.site` 和 `Astro.url`。
- **`src/components/Header.astro`** — 网站头部导航，包含导航链接（首页、博客、关于）和社交图标链接。内部使用 `HeaderLink.astro` 实现激活状态样式。
- **`src/components/HeaderLink.astro`** — 单个导航链接，通过匹配 `Astro.url.pathname` 检测激活状态。
- **`src/components/Footer.astro`** — 页面底部，包含版权年份。
- **`src/components/FormattedDate.astro`** — 根据 `Date` prop 渲染 `<time>` 元素。

### 样式与字体

- **`src/styles/global.css`** — 全局样式，包含用于主题的 CSS 自定义属性（颜色变量如 `--accent`、`--black`、`--gray` 等）。由 `BaseHead.astro` 引入，确保每个页面都加载。
- **字体** — Atkinson Hyperlegible，通过 Astro 的 `fontProviders.local()` 在 `astro.config.mjs` 中本地加载。配置为 CSS 变量 `--font-atkinson`。

### 构建产物中 CSS 的分布

- **全局 CSS**（`global.css`，由 `BaseHead.astro` import）：构建时被 Vite 合并到 `dist/_astro/Header.xxx.css`（与 Header 组件的 scoped 样式打包在一起），通过 `<link rel="stylesheet">` 引入。不在 `<style>` 标签中。
- **页面级 scoped 样式**（如 `index.astro` 中的 `<style>`）：直接内联在 HTML 的 `<style>` 标签中，带 `data-astro-cid` 属性选择器。
- **Lightning CSS 压缩**：Astro 6 使用 Lightning CSS 作为 CSS 压缩器，会自动将 `border-top-left-radius: 0; border-top-right-radius: 0; border-bottom-left-radius: 20px; border-bottom-right-radius: 20px;` 这样的长写法合并回简写 `border-radius:0 0 20px 20px`。验证 CSS 时应检查 `dist/` 产物而非源码。

## 经验教训 — 2026-05-26

### 1. Edit 工具的 tab/space 匹配问题（高频坑）
`.astro` 文件使用 **tab** 缩进。Edit 工具的 `old_string` 若使用空格则匹配失败。
- **单行修改**：用 `replace_all: true`
- **多行修改**：直接用 `Write` 工具重写整个文件，比反复尝试 Edit 更高效

### 2. 对齐问题的根因：`box-sizing` 和 Flex vs Grid
- **始终在全局样式中加入 `box-sizing: border-box`**，否则 `max-width` + `padding` 会导致实际宽度超出预期（content-box 下 padding 加在 width 外面）
- **`1/3 + 2/3` 分栏用 CSS Grid 而非 Flex**：Grid 的 `1fr 2fr` 从扣除 `gap` 后的剩余空间分配比例，Flex 的 `33.333% + 66.666%` + `gap` 会溢出

### 3. Hover 下拉菜单的鼠标桥接
`margin-top` 会在按钮与下拉菜单之间产生间隙，鼠标移过间隙时 `:hover` 断开导致菜单消失。
- **修复**：在父容器上添加 `::after { content: ''; position: absolute; inset: 100% 0 auto 0; height: 10px; }` 作为隐形桥接，并将 `margin-top` 缩小到 `1px`

### 4. 主题切换的防闪烁（FOUC）
暗色模式切换脚本必须在 `<head>` 中**同步执行**（阻塞渲染），在首帧绘制前设置 `data-theme`。否则暗色模式用户会看到白色闪烁。使用 `localStorage` 持久化选择，`matchMedia('(prefers-color-scheme: dark)')` 跟随系统。

### 5. 主题色实现模式
- 所有颜色通过 CSS 变量定义，亮色在 `:root`，暗色在 `[data-theme='dark']`
- 卡片背景、页面背景等**必须用变量**（如 `var(--card-bg)`），不能用硬编码的 `#fff` 或 `rgba(255,255,255,1)`
- `color-scheme: light/dark` 属性告诉浏览器使用对应的原生控件样式（滚动条、表单等）

### 6. 浏览器缓存导致"改了但没生效"
CSS 修改后用户反馈"没变化"，常见原因：
- Vite dev server 的 HMR 对 `import` 的 `.css` 文件不总是热更新 → 重启 `npm run dev`
- 浏览器缓存旧 CSS → 硬刷新 `Ctrl+Shift+R`
- 构建后的 CSS 文件名 hash 变化说明内容已更新，若 hash 没变说明内容确实没变

### 站点配置

全局常量（`SITE_TITLE`、`SITE_DESCRIPTION`）定义在 `src/consts.ts` 中。`astro.config.mjs` 中的 `site` URL 应在上线前从 `https://example.com` 改为实际域名。

## 更新日志 — 2026-05-25 首页重设计

### 概述
重新设计了首页，采用卡片式双栏布局、全新视觉风格和背景图片。

### 站点品牌
- `src/consts.ts`：`SITE_TITLE` → `"KaitoBlog"`，`SITE_DESCRIPTION` → 中文描述
- `src/components/Footer.astro`：简化为 `© YYYY kaito.`

### 首页（`src/pages/index.astro`）
- **布局**：1/3 + 2/3 双栏分割。左侧：头像卡片（sticky 吸顶）。右侧：博客文章卡片。
- **头像卡片**：圆形头像，名称 "kaito"，中文简介，外链（GitHub / Twitter / Email）。
- **文章卡片**：最新 5 篇文章按 `pubDate` 降序排列，每篇显示标题/日期/简介，底部 "查看全部文章 →" 链接。
- **背景**：`public/bg-pattern.svg`（渐变 + 网格 + 波浪线 + 径向光晕），通过 `.page-wrapper::before { position: fixed; z-index: -1; }` 实现。
- **卡片样式**：所有模块使用 `background: rgba(255,255,255,1); border-radius: 20px; box-shadow: 0 2px 12px rgba(var(--black), 0.04)`。卡片完全不透明 — 背景图仅显示在卡片间隙和两侧。
- **全局 `main` 覆盖**：通过 scoped 样式 `main { width: 100%; max-width: 1140px; padding: 0; background: transparent }` 绕过 `global.css` 中 720px 的限制。

### 导航栏（`src/components/Header.astro`）
- 右上角添加搜索按钮（SVG 放大镜图标）。
- 导航栏重新设计为卡片风格，与下方头像/文章卡片匹配：`border-radius: 20px`，白色背景，相同 `max-width: 1140px` 和 `box-shadow`。
- `header` 元素保持 `background: transparent`，使两侧显示背景图。
- `.nav-inner` 使用 `max-width: 1140px; margin: 0 auto; padding: 0.6em 2em`，与下方 hero 卡片对齐。
- `header` 设置 `padding: 0` — 导航栏紧贴视口顶部。

### 背景图
- `public/bg-pattern.svg` — 静态 SVG，包含渐变填充、细微网格线、波浪曲线和径向光晕点。
- 通过 `.page-wrapper` 上的固定伪元素应用，位于所有内容之后。

### 对齐修复 — 2026-05-25（同日第二次修改）

**错位原因：**
1. 缺少 `box-sizing: border-box` — `.nav-inner` 使用 `content-box`，导致 `padding: 0.6em 2em` 被加在 `max-width: 1140px` **之外**，导航栏卡片比下方的 hero 每侧宽出 2em。
2. Flex 布局 `33.333% / 66.666%` 配合 `flex-shrink: 0` 和 `gap: 2em` 导致溢出（`33.333% + 66.666% + 2em > 100%`）。

**修复方案：**
- **`global.css`**：在文件最顶部添加 `*, *::before, *::after { box-sizing: border-box; }` — padding 现在统一计入宽度计算。
- **`index.astro`**：`.hero` 从 Flex 切换为 CSS Grid（`grid-template-columns: 1fr 2fr`）。Grid 从扣除 gap 后**剩余的空间**中分配 `1fr` / `2fr`，比例数学上精确无误。

### 对齐约束（修复后）
三个水平模块共享完全一致的左右边缘：

| 模块 | 宽度 | 内边距 | 盒模型 | 圆角 |
|---|---|---|---|---|
| `.nav-inner` | 1140px | 0.6em 2em | border-box | 20px |
| `.profile`（grid 子项） | 1fr ≈ 366.67px | 2em | border-box | 20px |
| `.post-feed`（grid 子项） | 2fr ≈ 733.33px | 2em | border-box | 20px |
| `.hero`（grid 容器） | 1140px + 2em gap | 0 | border-box | — |

`.profile` 与 `.post-feed` 之间的间隙（`.hero` 上的 `gap: 2em`）显示背景图。移动端断点切换为 `grid-template-columns: 1fr`。

## 更新日志 — 2026-05-26

### 主题切换（暗色模式）
- **`global.css`**：新增 `:root` 下的 `--card-bg`、`--page-bg` 变量；新增 `[data-theme='dark']` 选择器覆盖所有颜色变量和 `color-scheme`
- **`index.astro`**：所有卡片的 `background: #fff` / `rgba(255,255,255,1)` 替换为 `var(--card-bg)`；页面背景色替换为 `var(--page-bg)`；`<head>` 中添加防 FOUC 阻塞脚本
- **`Header.astro`**：新增主题切换按钮（调色板 SVG 图标）+ hover 下拉菜单（亮色/暗色/跟随系统）；下拉菜单通过 `::after` 伪元素桥接防止鼠标失焦；JS 处理 `localStorage` 持久化和 `prefers-color-scheme` 监听
- **卡片 hover 文字颜色**：`.profile-links a:hover` 的 `color: white` 改为 `color: var(--card-bg)`，确保暗色模式下文字可见

### 头像卡片美化
- 头像和名字居中：`.profile { text-align: center }`，`.profile-links { justify-content: center }`
- 名字改为 `Kaito`（首字母大写）
- 移除 sticky 定位，头像随页面滚动

### 导航栏调整
- 圆角仅保留下方：`border-radius: 0 0 20px 20px`（上方为直角紧贴视口顶部）
- 移除 GitHub 图标及其样式

### 文档中文化
- `README.md` 和 `CLAUDE.md` 全文翻译为中文
