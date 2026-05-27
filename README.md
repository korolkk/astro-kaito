# Astro 博客起步模板

```sh
npm create astro@latest -- --template blog
```

> 🧑‍🚀 **老手宇航员？** 删掉这个文件，尽情发挥吧！

功能特性：

- ✅ 极简样式（自由定制！）
- ✅ 100/100 Lighthouse 性能评分
- ✅ SEO 友好，支持 canonical URL 和 Open Graph 数据
- ✅ 站点地图（Sitemap）支持
- ✅ RSS Feed 支持
- ✅ Markdown 和 MDX 支持

## 🚀 项目结构

Astro 项目的目录结构如下：

```text
├── public/
├── src/
│   ├── assets/
│   ├── components/
│   ├── content/
│   ├── layouts/
│   └── pages/
├── astro.config.mjs
├── README.md
├── package.json
└── tsconfig.json
```

Astro 会查找 `src/pages/` 目录下的 `.astro` 或 `.md` 文件，每个文件都会根据其文件名暴露为一个路由。

`src/components/` 没什么特别的，只是我们习惯把 Astro/React/Vue/Svelte/Preact 组件放在这里。

`src/content/` 目录包含相关 Markdown 和 MDX 文档的「集合」。使用 `getCollection()` 从 `src/content/blog/` 获取文章，并通过可选的 schema 对 frontmatter 进行类型检查。详见 [Astro 内容集合文档](https://docs.astro.build/en/guides/content-collections/)。

静态资源（如图片）可以放在 `public/` 目录中。

## 🧞 命令

所有命令都在项目根目录的终端中运行：

| 命令                       | 操作                                             |
| :------------------------- | :----------------------------------------------- |
| `npm install`              | 安装依赖                                         |
| `npm run dev`              | 启动本地开发服务器 `localhost:4321`               |
| `npm run build`            | 构建生产站点到 `./dist/`                          |
| `npm run preview`          | 本地预览生产构建，部署前检查                       |
| `npm run astro ...`        | 运行 CLI 命令，如 `astro add`、`astro check`      |
| `npm run astro -- --help`  | 获取 Astro CLI 帮助                               |

## 👀 想了解更多？

查看[官方文档](https://docs.astro.build)或加入我们的 [Discord 服务器](https://astro.build/chat)。

## 致谢

本主题基于精美的 [Bear Blog](https://github.com/HermanMartinus/bearblog/)。

## 更新日志

### 2026-05-28 — 文章标签、时间轴列表、翻页导航

**标签系统**
- `src/content.config.ts`：blog schema 新增 `tags: z.array(z.string()).optional().default([])`
- 为全部 77 篇文章添加标签，覆盖 8 个分类：CSP、LeetCode、字节青训营、Git、ROS2、Markdown/MDX、计算机视觉、随笔
- 文章页面和博客列表页以药丸样式展示标签
- `src/pages/search-index.json.js`：搜索索引包含 tags 字段，支持按标签搜索

**文章页面增强**
- 阅读进度条：页面顶部 sticky 定位，RAF 节流跟随滚动
- 上一篇/下一篇导航：文章底部两栏导航，显示相邻文章标题
- 封面图紧凑化：`720×240`，`object-fit: cover`

**博客列表页时间轴重设计**
- 左侧日期 + 中间圆点连线 + 中间文章信息 + 右侧封面缩略图
- 同一年份只显示一次年份标题，年份切换时圆点高亮
- 悬停动画：圆点放大 1.5 倍 + 主题色光晕扩散，连线同步变色
- 标签筛选栏：顶部药丸按钮，点击过滤文章，URL 参数 `?tag=xxx` 支持直达
- 卡片背景跟随主题切换（`var(--card-bg)`），宽度 1140px 与导航栏对齐

**搜索修复**
- Header 脚本添加 `is:inline` 防止 Astro 处理为 `type="module"` 导致 DOM 操作失败
- 修复点击搜索按钮内 SVG 图标时搜索栏立即关闭的问题（`btn.contains(e.target)` 替代 `e.target !== btn`）
- 所有内联脚本使用 IIFE 包裹避免全局变量冲突

**返回顶部按钮**
- `src/components/Footer.astro`：右下角固定定位，滚动超过 400px 淡入显示，平滑滚动至顶部

### 2026-05-27 — 内容迁移与界面打磨

**主题修复**
- 防 FOUC 脚本从首页移至 `BaseHead.astro`，所有页面统一生效
- Header JS init 补上 `applyTheme` 调用，确保页面加载时主题正确应用

**背景统一**
- 移除主页 `bg-pattern.svg`，改为 CSS 多层背景（光晕 + 点阵 + 渐变），全部使用 CSS 变量跟随主题
- `body` 新增 `background-color: var(--page-bg)`，亮暗色模式底色一致

**首页扩展**
- 左侧新增「开源项目」和「友情链接」卡片，与头像卡片纵向排列
- 右侧仅保留「最新文章」，整体结构改为左窄右宽的两栏布局
- 移除 Twitter 图标，导航栏中文化（首页 / 文章 / 关于）

**内容迁移**
- 从 Hexo 博客迁移 72 篇文章及配套图片目录
- Frontmatter 自动转换（`date` → `pubDate`，自动生成 `description`）
- 为所有文章随机分配封面图（`blog-placeholder-2/3/5.jpg`）

**关于页面**
- 重写为中文个人信息：自我介绍、技术栈、站点说明、联系方式

**站点链接**
- GitHub：`https://github.com/korolkk`，Email：`704788475@qq.com`

### 2026-05-26 — 暗色主题与细节优化

**主题切换**
- 新增暗色模式支持，通过 `[data-theme='dark']` CSS 选择器切换
- 亮色/暗色/跟随系统 三种模式，`localStorage` 持久化
- `<head>` 中阻塞脚本防止 FOUC 闪烁
- 所有卡片背景色使用 CSS 变量（`--card-bg`、`--page-bg`）

**头像卡片美化**
- 头像和名字居中显示
- 移除 sticky 定位，头像随页面滚动

**导航栏调整**
- 圆角仅保留下方（上方为直角紧贴视口顶部）
- 移除 GitHub 图标

**文档中文化**
- `README.md` 和 `CLAUDE.md` 全文翻译为中文

### 2026-05-25 — 首页重设计

重新设计了首页，采用卡片式双栏布局、全新视觉风格和背景图片。

**站点品牌**
- `src/consts.ts`：`SITE_TITLE` → `"KaitoBlog"`，`SITE_DESCRIPTION` → 中文描述
- `src/components/Footer.astro`：简化为 `© YYYY kaito.`

**首页布局**（`src/pages/index.astro`）
- 1/3 + 2/3 双栏分割，左侧头像卡片，右侧博客文章卡片
- 圆形头像，名称 "Kaito"，中文简介，外链（GitHub / Twitter / Email）
- 最新 5 篇文章按 `pubDate` 降序排列，每篇显示标题/日期/简介，底部 "查看全部文章 →" 链接
- `public/bg-pattern.svg` 作为固定背景图（渐变 + 网格 + 波浪线 + 径向光晕）
- 卡片样式：`border-radius: 20px; box-shadow: 0 2px 12px rgba(var(--black), 0.04)`

**导航栏**（`src/components/Header.astro`）
- 重新设计为卡片风格，与下方内容对齐
- 右上角添加搜索按钮
- 导航栏紧贴视口顶部（上方直角，下方圆角）

**对齐修复**
- 全局添加 `box-sizing: border-box` 解决 `padding` 导致的宽度溢出
- `.hero` 从 Flex 切换为 CSS Grid（`grid-template-columns: 1fr 2fr`）解决 `gap` 导致的溢出
