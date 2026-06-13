#!/usr/bin/env bash
#
# KaitoHub 手动部署脚本
# 用法：ssh 登录服务器后执行  bash /opt/deploy.sh
# 与 webhook 自动部署逻辑完全一致
#

set -euo pipefail

REPO_DIR="/var/www/kaitohub"
DIST_DIR="/var/www/kaitohub/dist"
API_DIR="/opt/api-bridge"

# --------------- 颜色 ---------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

step()  { echo -e "\n${CYAN}========================================${NC}"; echo -e "${CYAN}$1${NC}"; echo -e "${CYAN}========================================${NC}"; }
ok()    { echo -e "${GREEN}✓${NC} $1"; }
warn()  { echo -e "${YELLOW}⚠${NC} $1"; }
fail()  { echo -e "${RED}✗ $1${NC}"; exit 1; }

# --------------- 1. 拉取代码 ---------------
step "1/4  拉取最新代码"
cd "$REPO_DIR" || fail "无法进入 $REPO_DIR"
echo "当前 HEAD: $(git log --oneline -1)"
git fetch origin main
git reset --hard origin/main
ok "代码已更新到 $(git log --oneline -1)"

# --------------- 2. 安装依赖 + 构建 ---------------
step "2/4  安装依赖 + 构建站点"

# 清理残留进程 + 释放缓存，防止小内存服务器 OOM
echo ">> 清理残留进程..."
pkill -f "npm" 2>/dev/null || true
sleep 2
sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true

# 限制 Node 堆内存 384MB（服务器只有 1.8GB）
export NODE_OPTIONS="--max-old-space-size=384"

# 用 npm install 而非 npm ci —— ci 会全量重装，内存峰值太高
echo ">> npm install ..."
npm install
echo ">> BASE_URL=/ npm run build ..."
BASE_URL=/ npm run build

# 验证构建产物
if [ ! -d "$DIST_DIR" ] || [ -z "$(ls -A "$DIST_DIR" 2>/dev/null)" ]; then
  fail "构建失败：$DIST_DIR 目录为空或不存在"
fi
DIST_COUNT=$(ls "$DIST_DIR" | wc -l)
ok "构建完成，dist/ 包含 ${DIST_COUNT} 个文件/目录"

# --------------- 3. Nginx 部署 ---------------
step "3/4  应用部署（SELinux + Nginx）"
echo ">> restorecon -R $DIST_DIR ..."
restorecon -R "$DIST_DIR"
echo ">> systemctl reload nginx ..."
systemctl reload nginx
ok "Nginx 已重载"

# --------------- 4. 更新 API Bridge ---------------
step "4/4  更新 API Bridge"
cd "$API_DIR" || fail "无法进入 $API_DIR"
echo ">> mkdir -p /opt/api-bridge/data ..."
mkdir -p /opt/api-bridge/data
cp -n .env.example .env 2>/dev/null || true
echo ">> npm install --omit=dev ..."
NODE_OPTIONS="--max-old-space-size=512" npm install --omit=dev
echo ">> systemctl restart api-bridge ..."
systemctl restart api-bridge
ok "API Bridge 已重启"

# --------------- 5. 同步部署脚本到 /opt/ ---------------
echo ">> cp scripts/deploy.sh /opt/deploy.sh ..."
cp "$REPO_DIR/scripts/deploy.sh" /opt/deploy.sh
ok "deploy.sh 已同步到 /opt/deploy.sh"

# --------------- 完成 ---------------
echo ""
echo -e "${GREEN}╔════════════════════════════════╗${NC}"
echo -e "${GREEN}║     ✅ 部署完成！               ║${NC}"
echo -e "${GREEN}╚════════════════════════════════╝${NC}"
echo ""
echo "验证命令："
echo "  curl -s https://kaitolab.net/api/health"
echo "  systemctl status api-bridge nginx"
