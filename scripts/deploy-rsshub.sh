#!/usr/bin/env bash
#
# 在阿里云服务器上部署自建 RSSHub（用于抓取小红书笔记数据）
# 用法：bash scripts/deploy-rsshub.sh
# 前置：服务器已安装 Docker 或 Node.js 18+
#
# 部署完成后：
#   1. 在 /opt/api-bridge/.env 中配置 XHS_RSSHUB_URL 和 XHS_USER_ID
#   2. systemctl restart api-bridge
#

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
step() { echo -e "\n${CYAN}======== $1 ${NC}"; }
ok()   { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
fail() { echo -e "${RED}✗ $1${NC}"; exit 1; }

RSSHUB_PORT="${RSSHUB_PORT:-1200}"
RSSHUB_DIR="/opt/rsshub"
DATA_DIR="/opt/rsshub/data"

# --------------- 1. 检查环境 ---------------
step "1/4 检查运行环境"
if command -v docker >/dev/null 2>&1; then
  DEPLOY_MODE="docker"
  ok "检测到 Docker，使用容器方式部署"
elif command -v node >/dev/null 2>&1 && node -v | grep -qE '^v(18|20|22|24)'; then
  DEPLOY_MODE="node"
  ok "未检测到 Docker，使用 Node.js 方式部署（$(node -v)）"
else
  fail "未检测到 Docker 或 Node.js 18+，请先安装其一"
fi

# --------------- 2. 配置小红书 Cookie ---------------
step "2/4 配置小红书 Cookie（可选但强烈建议）"
echo ""
echo "从浏览器获取 cookie 的方法："
echo "  1. 用 Chrome 打开 https://www.xiaohongshu.com 并登录"
echo "  2. 按 F12 打开开发者工具 → Network → 刷新页面"
echo "  3. 点击任意请求，复制 Request Headers 中的完整 Cookie 值"
echo ""
echo "不配置 cookie 时 RSSHub 会走无 cookie 回退路径，数据可能不完整。"
if [ -f "$DATA_DIR/cookie.txt" ] && [ -s "$DATA_DIR/cookie.txt" ]; then
  ok "已存在 cookie 文件（$DATA_DIR/cookie.txt），如需更新请重新填写"
fi
mkdir -p "$DATA_DIR"

# --------------- 3. 部署 RSSHub ---------------
step "3/4 部署 RSSHub"

if [ "$DEPLOY_MODE" = "docker" ]; then
  if ! docker inspect rsshub >/dev/null 2>&1; then
    docker run -d \
      --name rsshub \
      --restart unless-stopped \
      -p "${RSSHUB_PORT}:1200" \
      -e NODE_ENV=production \
      -e CACHE_TYPE=memory \
      -e LISTEN_INADDR_ANY=0 \
      -v "$DATA_DIR":/app/data \
      diygod/rsshub:latest
    ok "Docker 容器已启动"
  else
    docker restart rsshub >/dev/null
    ok "Docker 容器已重启"
  fi
else
  if [ ! -d "$RSSHUB_DIR/.git" ]; then
    git clone --depth 1 https://github.com/DIYgod/RSSHub.git "$RSSHUB_DIR"
    cd "$RSSHUB_DIR"
    npm install --omit=dev
  else
    cd "$RSSHUB_DIR"
    git pull
    npm install --omit=dev
  fi

  # systemd 服务
  cat > /etc/systemd/system/rsshub.service << EOF
[Unit]
Description=RSSHub
After=network.target

[Service]
Type=simple
WorkingDirectory=$RSSHUB_DIR
ExecStart=/usr/bin/env NODE_ENV=production CACHE_TYPE=memory npm start
Restart=always
RestartSec=5
Environment=LISTEN_INADDR_ANY=0

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable rsshub
  systemctl restart rsshub
  ok "systemd 服务已启动（rsshub）"
fi

# --------------- 4. 验证 ---------------
step "4/4 验证 RSSHub"
sleep 5
if curl -s -m 10 "http://127.0.0.1:${RSSHUB_PORT}/" | grep -q "RSSHub"; then
  ok "RSSHub 已就绪：http://127.0.0.1:${RSSHUB_PORT}"
else
  warn "RSSHub 可能仍在启动中，请稍后访问 http://127.0.0.1:${RSSHUB_PORT} 验证"
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}  部署完成！下一步配置：${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo ""
echo "1. 将小红书 Cookie 写入（可选）："
echo "   vim $DATA_DIR/cookie.txt"
echo ""
echo "2. 在 /opt/api-bridge/.env 中追加："
echo "   XHS_RSSHUB_URL=http://127.0.0.1:${RSSHUB_PORT}"
echo "   XHS_USER_ID=<你的小红书用户ID>"
echo ""
echo "3. 重启 api-bridge："
echo "   systemctl restart api-bridge"
echo ""
echo "4. 验证："
echo "   curl http://127.0.0.1:${RSSHUB_PORT}/xiaohongshu/user/<你的用户ID>/notes"
echo ""
