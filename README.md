# KaitoHub

Kaito 的个人博客 —— 嵌入式软件工程师，专注 C/C++ 音视频开发。记录技术学习、项目笔记与生活思考。

基于 [Astro 6](https://astro.build) 构建，纯静态生成（SSG），追求 100/100 Lighthouse 性能评分。

## 功能特性

- ✅ **零 JS 默认** — 纯静态 HTML/CSS，交互功能内联实现，不引入 JS 框架
- ✅ **暗色/亮色主题** — 三种模式（亮色/暗色/跟随系统），防 FOUC 闪烁
- ✅ **文章时间轴** — CSS Grid 四栏布局，年份分组，标签筛选 + 分页
- ✅ **全文搜索** — 构建时生成 JSON 索引，客户端实时过滤
- ✅ **评论系统** — 自建 SQLite 后端，支持嵌套回复、点赞、Markdown 渲染
- ✅ **AI 集成** — 文章问答 + 浮动聊天，通过 OpenClaw 兼容 API
- ✅ **管理后台** — 在线编辑文章、审核评论、查看聊天日志、一键部署
- ✅ **SEO 友好** — canonical URL、Open Graph、Twitter 卡片、RSS Feed、Sitemap
- ✅ **响应式设计** — 适配桌面/平板/手机
- ✅ **本地字体** — Atkinson Hyperlegible 自托管，无外部请求

## 🚀 项目结构

```text
├── public/                  # 静态资源（favicon）
├── scripts/                 # 部署与开发辅助脚本
├── api-bridge/              # 独立 Express API 服务（评论、AI、管理后台）
│   ├── server.js            # API 主入口
│   └── package.json
├── src/
│   ├── assets/              # 图片、字体等静态资源
│   │   └── fonts/           # 本地字体文件
│   ├── components/          # Astro 组件
│   │   ├── BaseHead.astro   # <head> 元数据 + 防 FOUC 脚本
│   │   ├── Header.astro     # 导航栏（搜索 + 主题切换）
│   │   ├── Footer.astro     # 页脚（版权 + 返回顶部）
│   │   ├── AiChat.astro     # 浮动 AI 聊天组件
│   │   ├── HeaderLink.astro # 导航链接（活动状态检测）
│   │   └── FormattedDate.astro
│   ├── content/
│   │   └── blog/            # Markdown/MDX 文章（75 篇）
│   ├── layouts/
│   │   └── BlogPost.astro   # 文章页面布局（进度条/TOC/评论/AI问答）
│   ├── pages/               # 路由页面
│   │   ├── index.astro      # 首页
│   │   ├── blog/            # /blog 文章列表 + /blog/:slug 文章详情
│   │   ├── about.astro      # 关于页面
│   │   ├── admin.astro      # 管理后台 SPA
│   │   ├── ai-tools.astro   # AI 工具推荐
│   │   ├── 404.astro        # 错误页面
│   │   ├── rss.xml.js       # RSS Feed
│   │   └── search-index.json.js  # 搜索索引
│   ├── styles/
│   │   └── global.css       # 全局样式（CSS 变量、主题、排版）
│   ├── consts.ts            # 站点常量
│   └── content.config.ts    # 内容集合 schema
├── astro.config.mjs
├── package.json
├── tsconfig.json
└── CLAUDE.md                # Claude Code 开发指引
```

## 🧞 命令

| 命令 | 操作 |
| :--- | :--- |
| `npm install` | 安装依赖 |
| `npm run dev` | 启动开发服务器（Astro :4321 + API Bridge :3001） |
| `npm run build` | 构建生产站点到 `./dist/` |
| `npm run preview` | 本地预览生产构建 |
| `npm run astro -- check` | 类型检查 |
| `npm run astro -- --help` | 获取 Astro CLI 帮助 |

## 🏗️ 架构

```
浏览器 ──→ Nginx (:80/443)
              ├── /        → Astro 静态文件 (dist/)
              └── /api/*   → Express API Bridge (:3001)
                                ├── sql.js (SQLite WASM)
                                └── OpenClaw (AI 聊天/问答)
```

- **Astro** 负责全部前端页面的静态生成
- **API Bridge** 提供评论、AI、管理后台等动态功能的 REST API
- **sql.js** 纯 WASM 实现，零编译依赖，跨平台通吃
- 本地开发时 Vite 自动将 `/api` 代理到 `localhost:3001`

## 📡 API 端点

| 方法 | 端点 | 说明 |
| :--- | :--- | :--- |
| GET | `/api/health` | 健康检查 |
| POST | `/api/chat` | AI 自由聊天 |
| POST | `/api/article-qa` | 文章上下文问答 |
| GET/POST | `/api/comments` | 评论列表 / 提交评论 |
| POST | `/api/comments/:id/like` | 评论点赞 |
| POST | `/api/auth/login` | 管理员登录 |
| GET | `/api/auth/check` | 会话检查 |
| GET/PATCH/DELETE | `/api/admin/comments` | 评论管理 |
| GET/PUT | `/api/admin/articles` | 文章管理 |
| POST | `/api/admin/deploy` | 触发部署 |

## 更新日志

### 2026-06-01 — 站点统计、AI工具页、文章目录、关于时间线、翻页优化

**站点统计卡片**
- 首页侧栏新增站点统计卡片：表格布局 + SVG 图标，显示文章数 / 标签数 / 总字数 / 运行天数 / 最后活动
- 字数计算：读取所有文章 body，清理 Markdown 语法后统计字符数

**AI 工具页面**
- 新建 `src/pages/ai-tools.astro`：AI 工具推荐卡片（Claude / ChatGPT / Copilot / Perplexity / Midjourney / Gemini）+ 开源项目列表
- 导航栏新增「AI工具」入口
- 首页移除开源项目卡片（迁移至 AI 工具页面）

**文章目录 TOC**
- `src/layouts/BlogPost.astro`：新增右侧悬浮目录侧边栏（220px），层级缩进，scroll 驱动高亮激活章节
- 屏幕 ≤1300px 时自动隐藏

**首页头像卡片更新**
- 简介更新为嵌入式工程师身份
- 新增座右铭展示

**关于页面成长历程时间线**
- `src/pages/about.astro`：纵向时间轴 + 卡片式布局，6 个里程碑（倒序）
- 每条含时间范围 / 持续时长 / 副标题 / 详细描述 / 技能标签 / 成就栏
- 真实履历：杭州电子科技大学 → MCM/ICM F 奖 → 字节青训营 → ROS2 实习 → 浙江大华嵌入式

**博客列表页翻页**
- 每页 15 篇文章，客户端 JS 分页
- 箭号 + 数字页码统一风格，悬停 accent 色，当前页加粗
- 与标签筛选联动，URL 参数 `?page=N&tag=xxx`

### 2026-05-28 — 文章标签、时间轴列表、翻页导航

**标签系统**
- `src/content.config.ts`：blog schema 新增 `tags` 字段
- 为全部 77 篇文章添加标签，覆盖 8 个分类：CSP、LeetCode、字节青训营、Git、ROS2、Markdown/MDX、计算机视觉、随笔
- 文章页面和博客列表页以药丸样式展示标签
- 搜索索引包含 tags 字段，支持按标签搜索

**文章页面增强**
- 阅读进度条：页面顶部 sticky 定位，RAF 节流跟随滚动
- 上一篇/下一篇导航：文章底部两栏导航，显示相邻文章标题
- 封面图紧凑化：`720×240`，`object-fit: cover`

**博客列表页时间轴重设计**
- 左侧日期 + 中间圆点连线 + 中间文章信息 + 右侧封面缩略图
- 同一年份只显示一次年份标题，年份切换时圆点高亮
- 悬停动画：圆点放大 1.5 倍 + 主题色光晕扩散，连线同步变色
- 标签筛选栏：顶部药丸按钮，点击过滤文章，URL 参数 `?tag=xxx` 支持直达

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
- `src/consts.ts`：`SITE_TITLE` → `"KaitoHub"`，`SITE_DESCRIPTION` → 中文描述
- `src/components/Footer.astro`：简化为 `© YYYY kaito.`

**首页布局**（`src/pages/index.astro`）
- 1/3 + 2/3 双栏分割，左侧头像卡片，右侧博客文章卡片
- 圆形头像，名称 "Kaito"，中文简介，外链（GitHub / Twitter / Email）
- 最新 5 篇文章按 `pubDate` 降序排列，每篇显示标题/日期/简介，底部 "查看全部文章 →" 链接
- 卡片样式：`border-radius: 20px; box-shadow: 0 2px 12px rgba(var(--black), 0.04)`

**导航栏**（`src/components/Header.astro`）
- 重新设计为卡片风格，与下方内容对齐
- 右上角添加搜索按钮
- 导航栏紧贴视口顶部（上方直角，下方圆角）

**对齐修复**
- 全局添加 `box-sizing: border-box` 解决 `padding` 导致的宽度溢出
- `.hero` 从 Flex 切换为 CSS Grid（`grid-template-columns: 1fr 2fr`）解决 `gap` 导致的溢出
