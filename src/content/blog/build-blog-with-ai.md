---
title: "如何借助 AI 快速搭建个人技术博客"
description: "从零开始，借助 Claude Code 在两天内完成博客搭建、主题定制、内容迁移和部署上线的完整记录。"
pubDate: "Jun 1 2026"
heroImage: "../../assets/covers/cover-build-blog-with-ai.png"
tags: ["AI工具", "Astro", "博客搭建"]
---

## 缘起

我一直想拥有一个真正属于自己的技术博客。之前用过 Hexo，虽然能跑，但主题老旧，定制困难，每次折腾都像在考古。2026 年，AI 辅助编程工具已经足够成熟，我决定试试——**能不能让 AI 帮我搞定一切？**

答案是：能，而且远超预期。

这篇文章记录了我借助 Claude Code 从零搭建本站的全过程，包括选型决策、功能实现、踩坑经验和最终成果。

## 技术选型

选框架时我给了 AI 几个约束：

1. **纯静态生成**，部署到 GitHub Pages 零成本
2. **Markdown 写作**，不依赖数据库和 CMS
3. **极致性能**，Lighthouse 满分是目标
4. **暗色模式**，夜间写作不伤眼

Claude 推荐了 [Astro](https://astro.build)，理由很充分：

- 零 JS 默认输出，生成的 HTML 只有几 KB
- 内置 Markdown/MDX 内容集合，类型安全
- Islands 架构，只在需要的地方加载交互 JS
- 社区模板丰富，`astro-paper` 起步模板非常干净

对比了 Next.js、Hugo、Hexo 之后，Astro 6 + `astro-paper` 模板胜出，一张白纸，高度可控。

## AI 辅助开发流水线

### 环境搭建（5 分钟）

```bash
npm create astro@latest -- --template satnaing/astro-paper
```

起步模板搭好后，Claude Code 就接管了。整个过程不需要手动写一行 CSS——描述需求，AI 生成代码，我 review，通过后提交。

### 主题系统（30 分钟）

第一件事是暗色模式。我们选择了 `data-theme` 属性方案：

- CSS 变量定义全部颜色，`:root` 放亮色，`[data-theme='dark']` 放暗色
- `<head>` 中同步执行脚本，读取 `localStorage`，**在首帧渲染前**注入 `data-theme`
- 支持「跟随系统」模式，`matchMedia` 监听系统主题变化

这里有一个重要教训：**FOUC 防闪烁脚本必须在 `<head>` 中同步执行**。如果放在 `defer` 或 `type="module"` 的脚本里，暗色模式用户会先看到白色闪烁，体验极差。

### 首页重设计（1 小时）

原先的模板首页太简单——只有文章列表。我想要一个更丰富的首页：

- **左侧栏**：头像卡片 + 站点统计 + 友情链接
- **右侧栏**：最新 5 篇文章

站点统计是纯服务端计算的——从所有文章 body 中提取字符数、统计最早/最晚发布时间等。所有这些在 Astro 的构建阶段完成，生成纯静态 HTML，零客户端开销。

```typescript
// 构建时统计，零运行时开销
const stats = {
  articleCount: allPosts.length,
  tagCount: new Set(allPosts.flatMap(p => p.data.tags || [])).size,
  wordCount: allPosts.reduce((sum, p) => sum + countChars(p.body || ''), 0),
  runDays: Math.ceil((now - firstPost.data.pubDate) / 86400000),
};
```

### 博客列表时间轴（2 小时）

博客列表是最花时间的部分。我想要一个类似微信朋友圈的时间轴布局，而不是传统的列表。和 Claude Code 经过多轮迭代，最终确定了四栏 Grid 方案：

```
日期 | 圆点+连线 | 文章标题+标签 | 封面缩略图
100px |   28px   |     1fr      |   160px
```

细节打磨了很多轮：

- **年份分组**：同一年的文章只显示一次年份标题，用 Astro 模板中的 `let currentYear = 0` 变量追踪
- **圆点动画**：hover 时放大 1.5 倍 + accent 色光晕扩散，连线同步变色
- **标签筛选**：顶部的药丸按钮，点击只显示含该标签的文章，URL 参数 `?tag=xxx` 支持直达
- **翻页系统**：15 篇/页，智能页码 + 前后箭号，筛选和翻页联动，切换时保持滚动位置

### 文章详情页（1 小时）

每篇文章页面增加了多个功能：

- **阅读进度条**：顶部 sticky 定位，`requestAnimationFrame` 节流跟随滚动
- **文章目录 TOC**：右侧悬浮侧边栏，提取 h2~h4 标题，scroll 驱动高亮当前章节
- **上下篇导航**：底部两栏，显示相邻文章标题
- **社交分享**：复制链接 / X / 微博三个按钮
- **Giscus 评论**：基于 GitHub Discussions，零数据库

目录（TOC）的实现有一个关键细节——**标题 ID 的匹配**。Astro 的 Markdown 渲染器会自动给标题生成 ID，我们需要在服务端用同样的算法处理原始 Markdown 正文来提取标题文本和 ID，才能让 TOC 链接正确跳转。

```typescript
// 提取 h2-h4 标题并生成与渲染器一致的 ID
function extractHeadings(body: string) {
  const regex = /^(#{2,4})\s+(.+)$/gm;
  // ... 解析并生成 slug ID
}
```

### 关于页面时间轴（30 分钟）

关于页面用时间轴展示个人成长历程：教育经历 → 竞赛获奖 → 实习 → 工作。每条包含时间范围、持续时长、技能标签和成就高亮栏。

### AI 工具页面（15 分钟）

一个独立的工具推荐页面，卡片式展示我日常使用的 AI 工具（Claude、ChatGPT、Copilot 等），加上开源项目入口。

我还把这几个操作封装成了 Claude Code 的斜杠命令：

```markdown
# .claude/skills/ship.md
/ship → 一键 commit + push
/commit → git add + 生成 commit message + git commit
/push → git push origin <分支名>
```

省掉了每次手动输入 `git add` + `git commit` + `git push` 的重复劳动。

## AI 辅助编程的实战心得

### 1. 描述越具体，产出越精准

「把这个卡片美化一下」效果很差。有效的描述是：

> 站点统计卡片改为 `<table>` 布局，每行左边是 SVG 图标（accent 色），中间是灰色标签，右边是加粗数值。行之间有细分隔线。

### 2. 善用「参考模板」

提供视觉参考——「参考下面模板，增加一个站点统计卡片」——远比抽象描述高效。AI 能准确理解你想要的布局和数据字段。

### 3. Review 不可省略

Claude Code 一次生成了整个文件的代码，直接替换。但以下几个坑是我自己发现的：

- Astro `.astro` 文件用 Tab 缩进，Edit 工具匹配空格会失败 → **Rule: 用 Write 重写整个文件**
- `is:inline` 脚本共享全局作用域，同名变量冲突 → **Rule: 用 IIFE 包裹**
- 暗色模式下卡片用 `#fff` 背景，切主题时不生效 → **Rule: 必须用 CSS 变量**

我把这些坑整理成了 `CLAUDE.md`，后续开发效率更高。

### 4. 迭代，不要一次到位

时间轴布局改了五版才满意——先是基础布局，然后加年份分组，再加动画，最后对齐导航栏。每一版都在前一版的基础上迭代，而不是推倒重来。

## 数据说话

| 指标 | 数值 |
|------|------|
| 开发耗时 | ~10 小时（含内容迁移） |
| AI 生成代码占比 | ~85% |
| 手动修改次数 | ~20 次 |
| 最终页面数 | 82 页（含 404） |
| Lighthouse 评分 | 100 / 100 |
| 首屏 JS | 0 KB |

## 技术栈总览

```
框架：     Astro 6
内容：     Markdown / MDX
样式：     手写 CSS（CSS 变量 + 主题系统）
评论：     Giscus（GitHub Discussions）
统计：     不蒜子
字体：     Atkinson Hyperlegible（本地托管）
部署：     GitHub Pages
AI 工具：  Claude Code（主力）+ ChatGPT / Copilot（辅助）
```

## 结语

两年前，搭一个博客要手写 HTML、调 CSS、配 Webpack、折腾部署。现在呢？打开 Claude Code，描述你要什么，AI 写出代码，你 review 通过，`/ship` 一键提交推送上线。

**AI 没有让编程变简单——它让「想法的实现成本」趋近于零。**

今天的 KaitoHub 可能还不够完美，但它的迭代速度会很快——因为每次改进只需要几分钟的对话。

如果你想用类似方式搭建自己的博客，可以参考 [Astro 官方文档](https://docs.astro.build) 和本站的 [GitHub 仓库](https://github.com/korolkk/astro-kaito)。欢迎 Fork、参考、交流。
