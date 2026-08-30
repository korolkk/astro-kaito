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
RSSHUB_DIR="/opt/rsshub/app"
DATA_DIR="/opt/rsshub/data"

# 兼容旧版本：曾把代码直接 clone 到 /opt/rsshub，如已存在则迁移到 app/ 子目录
if [ -d "/opt/rsshub/.git" ] && [ ! -d "$RSSHUB_DIR" ]; then
  warn "检测到旧版目录结构，正在迁移 /opt/rsshub → $RSSHUB_DIR ..."
  mkdir -p "$(dirname "$RSSHUB_DIR")"
  mv /opt/rsshub "$RSSHUB_DIR" 2>/dev/null || true
  # 若迁移失败（data 目录占用），把代码目录移开即可
  if [ ! -d "$RSSHUB_DIR/.git" ] && [ -d /opt/rsshub ]; then
    mkdir -p "$RSSHUB_DIR"
    shopt -s dotglob
    for f in /opt/rsshub/*; do
      [ "$f" = "/opt/rsshub/data" ] && continue
      mv "$f" "$RSSHUB_DIR/" 2>/dev/null || true
    done
    shopt -u dotglob
  fi
  ok "迁移完成"
fi

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

# --------------- 1.5 内存检查：内存不足且无 swap 时自动创建 ---------------
step "1.5/4 检查内存与 Swap"
TOTAL_MEM_MB=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || echo 0)
SWAP_MB=$(awk '/SwapTotal/ {printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || echo 0)
ok "物理内存 ${TOTAL_MEM_MB}MB，Swap ${SWAP_MB}MB"

# 只有 Node 模式需要本地编译依赖；Docker 镜像预构建，无需 swap
if [ "$DEPLOY_MODE" = "node" ]; then
  if [ "$TOTAL_MEM_MB" -gt 0 ] && [ "$TOTAL_MEM_MB" -lt 2048 ] && [ "$SWAP_MB" -eq 0 ]; then
    warn "内存不足 2GB 且无 Swap，npm 安装原生模块（sharp 等）极易被 OOM 杀掉"
    if [ "$(id -u)" -eq 0 ]; then
      if [ -f /swapfile ] && swapon --show | grep -q /swapfile; then
        ok "已存在 /swapfile 且已启用，跳过创建"
      else
        echo ">> 创建 2GB swap（/swapfile）..."
        fallocate -l 2G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=2048 status=none
        chmod 600 /swapfile
        mkswap /swapfile >/dev/null
        swapon /swapfile
        if ! grep -q '^/swapfile ' /etc/fstab; then
          echo '/swapfile none swap sw 0 0' >> /etc/fstab
        fi
        ok "Swap 已创建并启用（2GB），已写入 /etc/fstab 开机自启"
      fi
    else
      warn "当前非 root，无法自动创建 swap。请手动执行："
      echo "  sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile"
      echo "  sudo mkswap /swapfile && sudo swapon /swapfile"
      echo "  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab"
    fi
  elif [ "$SWAP_MB" -gt 0 ]; then
    ok "已有 Swap ${SWAP_MB}MB，可支撑 npm 编译"
  fi
fi

# --------------- 2. 配置小红书 Cookie（强烈建议） ---------------
step "2/4 配置小红书 Cookie"
echo ""
echo "从浏览器获取 cookie 的方法（详见下方说明）："
echo "  1. 用 Chrome 打开 https://www.xiaohongshu.com 并登录"
echo "  2. 按 F12 打开开发者工具 → Network → 刷新页面"
echo "  3. 点击任意请求，在 Request Headers 中找到 Cookie 字段，复制完整值"
echo ""
echo "cookie 将写入 $DATA_DIR/cookie.txt 并注入 RSSHub（环境变量 XIAOHONGSHU_COOKIE）"
mkdir -p "$DATA_DIR"
if [ -f "$DATA_DIR/cookie.txt" ] && [ -s "$DATA_DIR/cookie.txt" ]; then
  ok "已存在 cookie 文件，将使用现有配置（如需更新请编辑 $DATA_DIR/cookie.txt）"
else
  warn "未找到 cookie 文件：$DATA_DIR/cookie.txt"
  warn "RSSHub 将走无 cookie 回退路径，笔记链接可能不完整"
  echo "  之后准备好 cookie 后，执行："
  echo "    vim $DATA_DIR/cookie.txt   # 粘贴完整 cookie 值（单行）"
  echo "    bash scripts/deploy-rsshub.sh   # 重新运行本脚本即可生效"
fi

# 读取 cookie（供后续注入；文件不存在则为空字符串）
XHS_COOKIE=""
if [ -f "$DATA_DIR/cookie.txt" ]; then
  XHS_COOKIE="$(tr -d '\r\n' < "$DATA_DIR/cookie.txt")"
fi

# --------------- 3. 部署 RSSHub ---------------
step "3/4 部署 RSSHub"

if [ "$DEPLOY_MODE" = "docker" ]; then
  # 构建 docker 参数：cookie 存在时注入环境变量
  DOCKER_ENV=(
    -e NODE_ENV=production
    -e CACHE_TYPE=memory
    -e LISTEN_INADDR_ANY=0
  )
  if [ -n "$XHS_COOKIE" ]; then
    DOCKER_ENV+=(-e "XIAOHONGSHU_COOKIE=$XHS_COOKIE")
    ok "已注入 XIAOHONGSHU_COOKIE（${#XHS_COOKIE} 字符）"
  fi
  if ! docker inspect rsshub >/dev/null 2>&1; then
    docker run -d \
      --name rsshub \
      --restart unless-stopped \
      -p "${RSSHUB_PORT}:1200" \
      "${DOCKER_ENV[@]}" \
      -v "$DATA_DIR":/app/data \
      diygod/rsshub:latest
    ok "Docker 容器已启动"
  else
    docker rm -f rsshub >/dev/null 2>&1 || true
    docker run -d \
      --name rsshub \
      --restart unless-stopped \
      -p "${RSSHUB_PORT}:1200" \
      "${DOCKER_ENV[@]}" \
      -v "$DATA_DIR":/app/data \
      diygod/rsshub:latest
    ok "Docker 容器已重建（应用最新 cookie 配置）"
  fi
else
  if [ ! -d "$RSSHUB_DIR/.git" ]; then
    git clone --depth 1 https://github.com/DIYgod/RSSHub.git "$RSSHUB_DIR"
    cd "$RSSHUB_DIR"
    # --legacy-peer-deps：RSSHub 上游 eslint 10 与 eslint-nibble peer 依赖冲突，
    # 官方部署亦使用该参数跳过（见 RSSHub 文档）
    # --no-audit --no-fund：跳过安全审计/赞助提示，减少输出与耗时
    echo ">> npm install（首次安装需 5-15 分钟，请耐心等待）..."
    npm install --omit=dev --legacy-peer-deps --no-audit --no-fund
  else
    cd "$RSSHUB_DIR"
    git pull
    echo ">> npm install（如依赖有更新需几分钟，请耐心等待）..."
    npm install --omit=dev --legacy-peer-deps --no-audit --no-fund
  fi

  # RSSHub 新版为 TS 源码，start 执行 node dist/index.mjs，必须先构建生成 dist/。
  # build 脚本（build:routes + tsdown）依赖 devDependencies 中的构建工具，
  # 用 --omit=dev 安装后需补装：tsx（build:routes）、tsdown、typescript
  echo ">> 补装构建工具（tsx / tsdown / typescript）..."
  npm install --no-save --legacy-peer-deps --no-audit --no-fund tsx tsdown typescript

  echo ">> npm run build（生成 dist/ 产物，需几分钟）..."
  if [ ! -d "$RSSHUB_DIR/dist" ]; then
    npm run build
    ok "构建完成，dist/ 已生成"
  else
    ok "dist/ 已存在，跳过构建"
  fi

  # systemd 服务（cookie 通过 EnvironmentFile 注入）
  cat > /etc/systemd/system/rsshub.service << EOF
[Unit]
Description=RSSHub
After=network.target

[Service]
Type=simple
WorkingDirectory=$RSSHUB_DIR
EnvironmentFile=-$DATA_DIR/rsshub.env
ExecStart=/usr/bin/env NODE_ENV=production CACHE_TYPE=memory npm start
Restart=always
RestartSec=5
Environment=LISTEN_INADDR_ANY=0

[Install]
WantedBy=multi-user.target
EOF
  # 生成环境变量文件（cookie 非空才写入）
  if [ -n "$XHS_COOKIE" ]; then
    printf 'XIAOHONGSHU_COOKIE=%s\n' "$XHS_COOKIE" > "$DATA_DIR/rsshub.env"
    chmod 600 "$DATA_DIR/rsshub.env"
    ok "已写入 XIAOHONGSHU_COOKIE 到 $DATA_DIR/rsshub.env"
  else
    rm -f "$DATA_DIR/rsshub.env"
    warn "未配置 cookie，跳过环境变量文件"
  fi
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
echo "1. 小红书 Cookie（本次已自动注入 RSSHub）："
echo "   - 修改：vim $DATA_DIR/cookie.txt"
echo "   - 生效：重新运行本脚本即可"
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
