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

## 开发规则

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

### 7. Astro 图片缓存的清理（关键坑）
替换或删除 `src/assets/` 中的图片后，构建产物可能仍包含旧图片。原因：Astro 在 `node_modules/.astro/assets/` 中维护资产缓存。
- **替换/删除图片后必须执行**：`rm -rf node_modules/.astro dist .astro && npm run build`
- 仅删 `dist/` 不够，`node_modules/.astro/` 是 Vite 的持久化缓存，dev server 也依赖它
- 验证命令：`find . -path "*/node_modules" -prune -o -name "*图片名*" -print`

### 8. Hexo → Astro 博客迁移要点
- **Frontmatter 转换**：`date: YYYY-MM-DD HH:MM:SS` → `pubDate: 'Mon DD YYYY'`，`tags/categories/id` 移除，需生成 `description`
- **CRLF 坑**：Hexo 的 `.md` 文件常使用 Windows CRLF 换行，正则匹配 frontmatter 时需 `\r?\n`
- **图片目录**：Hexo 文章图片放在同名子目录中，迁移后相对路径引用不变，直接复制即可
- **封面图**：迁移后 `blog-placeholder-1~5.jpg` 随机分配 `heroImage`

## 站点配置

全局常量（`SITE_TITLE`、`SITE_DESCRIPTION`）定义在 `src/consts.ts` 中。`astro.config.mjs` 中的 `site` URL 应在上线前从 `https://example.com` 改为实际域名。

**站点 URL**：GitHub `https://github.com/korolkk`，邮箱 `704788475@qq.com`。
