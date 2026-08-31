#!/bin/bash
# KaitoHub 每日数据报告（昨天网站 + 小红书）
# 用法: bash /tmp/daily-report.sh
echo "========== KaitoHub 每日数据报告 =========="
echo "生成时间: $(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M %A')"
echo "报告日期: 昨天 $(TZ='Asia/Shanghai' date -d 'yesterday' '+%Y-%m-%d')"
echo

# ---------- 1. 小红书数据 ----------
echo "【小红书数据】"
PASS=$(grep '^ADMIN_PASSWORD=' /opt/api-bridge/.env | cut -d= -f2)
curl -s -m 90 -c /tmp/dr-cj.txt -X POST http://127.0.0.1:3001/api/auth/login \
  -H 'Content-Type: application/json' -d "{\"password\":\"$PASS\"}" > /dev/null 2>&1
XHS=$(curl -s -m 90 -b /tmp/dr-cj.txt http://127.0.0.1:3001/api/admin/xhs/stats 2>/dev/null)
if [ -n "$XHS" ]; then
  echo "$XHS" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(f'  笔记总数: {d.get(\"noteCount\", 0)} 篇')
    print(f'  累计点赞: {d.get(\"totalLikes\", 0)} | 评论: {d.get(\"totalComments\", 0)} | 收藏: {d.get(\"totalCollects\", 0)}')
    posts = d.get('recentPosts', [])
    if posts:
        print('  最新笔记:')
        for p in posts[:3]:
            dt = (p.get('pubDate') or '')[:10]
            print(f'    - {p.get(\"title\",\"\")[:30]} | {dt} | 赞{p.get(\"likes\",0)}')
    print(f'  (数据截至 {d.get(\"fetchedAt\",\"\")[:19].replace(\"T\",\" \")})')
except Exception as e:
    print('  解析失败:', e)
"
else
  echo "  小红书数据获取失败"
fi
echo

# ---------- 2. 网站数据（昨天） ----------
echo "【网站数据 - 昨天】"
YDAY=$(TZ='Asia/Shanghai' date -d 'yesterday' '+%Y%m%d')
LOG="/var/log/nginx/access.log-${YDAY}.gz"
if [ -f "$LOG" ]; then
  zcat "$LOG" > /tmp/dr-access.log 2>/dev/null
elif [ -f "/var/log/nginx/access.log-${YDAY}" ]; then
  cat "/var/log/nginx/access.log-${YDAY}" > /tmp/dr-access.log 2>/dev/null
else
  # 昨天归档不存在则用当前日志（可能是当天）
  cp /var/log/nginx/access.log /tmp/dr-access.log 2>/dev/null
  echo "  (注意: 昨天的日志归档未找到, 展示的是当前累计数据)"
fi
python3 << 'PYEOF'
import re
from collections import Counter
try:
    lines = open('/tmp/dr-access.log', errors='ignore').read().splitlines()
except:
    lines = []
total = len(lines)
ips = set()
status = Counter()
paths = Counter()
for line in lines:
    m = re.match(r'(\S+) .*?"(?:GET|POST|HEAD) (\S+) HTTP[^"]*" (\d{3})', line)
    if m:
        ips.add(m.group(1))
        path = m.group(2).split('?')[0]
        status[m.group(3)] += 1
        if m.group(3) in ('200', '301') and path not in ('/favicon.ico', '/robots.txt', '/wp-admin/install.php'):
            paths[path] += 1
print(f'  总请求数: {total} 次')
print(f'  独立IP: {len(ips)} 个')
ok = sum(v for k, v in status.items() if k.startswith('2') or k == '301')
print(f'  成功响应(2xx/301): {ok} 次')
print('  热门页面 TOP5:')
for p, c in paths.most_common(5):
    print(f'    {c:>4} {p[:50]}')
PYEOF
echo
echo "========== 报告结束 =========="
rm -f /tmp/dr-cj.txt /tmp/dr-access.log
