---
title: "博客接入 AI 助手：OpenClaw 桥接方案从零搭建"
description: "从架构设计到前端实现，完整记录在 Astro 静态博客中集成 OpenClaw AI 聊天和文章问答功能的全过程。"
pubDate: "Jun 9 2026"
heroImage: ../../assets/covers/cover-ai-chat-handdrawn.png
tags:
  - AI
  - OpenClaw
  - Astro
  - Node.js
---
## 缘起

博客搭好之后总觉得少了点什么。GitHub 热力图、数字滚动动画、打字机效果都加了，但都是"静态"的趣味功能。我想让博客真的能"对话"——访客可以问我博客里的内容，或者随便聊聊天。

正好我在阿里云 ECS 上跑着 OpenClaw 网关，它提供了标准的 OpenAI 兼容 API。于是花了半天时间，把 AI 聊天和文章问答功能接入了博客前台。

## 架构设计

最直接的方案是让前端直接调 OpenClaw 的 API。但这有几个问题：

1. **安全**：OpenClaw 的管理 token 会暴露在浏览器里
2. **不可控**：没法做限流、没法定制 system prompt
3. **耦合**：前端要知道 OpenClaw 的地址和认证方式

所以加了一层 **API Bridge**（Node.js Express 服务，~250 行）：

```
浏览器 → Nginx → API Bridge (:3001) → OpenClaw (:18789)
```

Bridge 负责三件事：注入 AI 人格、限流保护、格式化响应。前端只和 Bridge 通信，完全不感知后端的 OpenClaw。

## API Bridge 四个端点

| 端点 | 方法 | 功能 |
|------|------|------|
| `/api/chat` | POST | 自由聊天，注入 system prompt 定义 AI 人格 |
| `/api/article-qa` | POST | 文章问答，自动注入文章全文做上下文 |
| `/api/deploy` | POST | Webhook 部署，CI 推送后服务器自动拉取构建 |
| `/api/health` | GET | 健康检查 |

其中 `/api/deploy` 是后来加的——既然 Bridge 已经在跑了，顺便用它接收 GitHub Actions 的部署通知，省掉了 SSH 那一整套东西。

### System Prompt 设计

定义 AI 分身的人格是关键。我给它设了三个维度的约束：

- **身份**：嵌入式软件工程师，专注音视频开发，主攻 C/C++
- **风格**：专业但不枯燥，能用通俗类比解释技术概念，中文为主
- **边界**：只回答技术相关问题，拒绝政治/违法内容，不透露内部配置

这样 AI 的回答风格和博客主题一致，不会出现"我是一个通用 AI 助手"那种出戏的感觉。

### 限流策略

AI 调用是有成本的（即使是本地跑），不加限制容易被滥用。三级限流，全部通过环境变量可调：

| 端点 | 默认限制 | 原因 |
|------|----------|------|
| `/api/chat` | 20 次/分钟/IP | 自由聊天调用频率高 |
| `/api/article-qa` | 10 次/分钟/IP | 附带长文本，最贵 |
| 全局兜底 | 60 次/分钟/IP | 防止异常流量 |

用 `express-rate-limit` 实现，超限返回 HTTP 429，前端会显示 "请求太频繁了，请稍后再试 🌊"。

## 前端组件

遵循 Astro 的"零 JS 默认"理念，全部用内联 `<script is:inline>` + IIFE 实现，不引入任何框架，不增加外部 JS 文件。

### 浮窗 AI 聊天

右下角 48px 紫蓝渐变圆形按钮，比返回顶部按钮更靠上、更显眼。外层有脉冲光环动画，hover 时放大 + 阴影加深。

点击弹出 380×500px 对话框，包含：
- **头部**：💬 Kaito AI · 在线 · 随时可聊
- **消息区**：用户消息靠右紫蓝渐变气泡，AI 回复靠左灰色气泡。不加"你"/"AI"之类的机械标签，靠颜色和位置自然区分，和开场问候 "👋 你好！我是 Kaito 的 AI 分身" 的语气保持一致
- **输入区**：支持 Enter 发送 / Shift+Enter 换行，移动端自动适配
- **打字指示器**：三个跳动圆点，等 AI 回复时不会焦虑

暗色模式自动跟随博客主题，所有颜色走 CSS 变量。

### 文章 AI 问答

每篇博客底部、评论区上方插入一个问答区块：
- 3 个预设问题快捷按钮（核心观点、优缺点、适合人群）
- 自定义输入框
- 回答区带加载动画

点击预设按钮会自动把问题 + 文章标题 + 文章内容（前 8000 字）发给 `/api/article-qa`。Bridge 收到后构造包含完整上下文的 prompt 再请求 OpenClaw，确保回答基于文章内容而不是瞎编。

## 部署

### 服务端

API Bridge 是独立的 Node.js 服务，部署在 `/opt/api-bridge/`，通过 systemd 管理：

```ini
[Service]
ExecStart=/usr/bin/node /opt/api-bridge/server.js
Restart=on-failure
```

依赖 `express` + `cors` + `dotenv` + `express-rate-limit`，轻量到几乎没有开销。

### Nginx 代理

```nginx
location /api/ {
    proxy_pass http://127.0.0.1:3001;
}
```

前端用相对路径 `/api/chat` 发请求，无论 IP 还是域名都能正常工作。

## 总结

整个方案的精髓在于**加一层桥接**。不直接暴露 OpenClaw，换来的是：

- **安全**：token 不泄露到浏览器
- **可控**：限流、定制 prompt 全部在服务端
- **解耦**：前后端各自独立演进，Bridge 还可以顺便干别的事（比如 webhook 部署）
- **零前端框架**：纯内联 JS，不增加页面体积，Lighthouse 评分不受影响

如果你的博客也有本地跑的 AI 服务，这套架构基本可以直接复用——换掉 system prompt 和 OpenClaw 的 API 地址就行。
