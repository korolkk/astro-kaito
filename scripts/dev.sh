#!/usr/bin/env bash
# 开发脚本：同时启动 Astro 和 API Bridge
# 用法: bash scripts/dev.sh
# Ctrl+C 同时停止两个服务

set -e

API_BRIDGE_DIR="$(dirname "$0")/../api-bridge"
ASTRO_DIR="$(dirname "$0")/.."

echo "=== KaitoHub 开发模式 ==="
echo ""

cleanup() {
	echo ""
	echo "正在停止所有服务..."
	kill $API_PID 2>/dev/null || true
	wait $API_PID 2>/dev/null || true
	echo "已全部停止"
	exit 0
}
trap cleanup INT TERM

# 1. 启动 API Bridge（后台）
echo "[1/2] 启动 API Bridge (localhost:3001)..."
cd "$API_BRIDGE_DIR"
npm run dev &
API_PID=$!
cd "$ASTRO_DIR"

# 等待 API Bridge 启动
sleep 1

# 2. 启动 Astro Dev Server（前台）
echo "[2/2] 启动 Astro (localhost:4321)..."
echo ""
echo "Ctrl+C 停止全部服务"
echo ""

npm run dev

# 如果 Astro 退出，清理后台进程
cleanup
