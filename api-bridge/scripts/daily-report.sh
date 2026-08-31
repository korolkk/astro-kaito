#!/bin/bash
# KaitoHub 每日数据报告（昨天网站 + 小红书 + GitHub + 最新评论）
# 用法: bash /tmp/daily-report.sh
echo "========== KaitoHub 每日数据报告 =========="
echo "生成时间: $(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M %A')"
echo "报告日期: 昨天 $(TZ='Asia/Shanghai' date -d 'yesterday' '+%Y-%m-%d')"
echo

# ---------- 登录 api-bridge ----------
PASS=$(grep '^ADMIN_PASSWORD=' /opt/api-bridge/.env | cut -d= -f2)
curl -s -m 90 -c /tmp/dr-cj.txt -X POST http://127.0.0.1:3001/api/auth/login \
  -H 'Content-Type: application/json' -d "{\"password\":\"$PASS\"}" > /dev/null 2>&1

# ---------- 1. 小红书数据 ----------
echo "【小红书数据】"
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
except Exception as e:
    print('  解析失败:', e)
"
else
  echo "  小红书数据获取失败"
fi
echo

# ---------- 2. 网站数据（昨天访客） ----------
echo "【网站数据 - 昨天访客】"
YDAY=$(TZ='Asia/Shanghai' date -d 'yesterday' '+%Y%m%d')
LOG="/var/log/nginx/access.log-${YDAY}.gz"
if [ -f "$LOG" ]; then
  zcat "$LOG" > /tmp/dr-access.log 2>/dev/null
elif [ -f "/var/log/nginx/access.log-${YDAY}" ]; then
  cat "/var/log/nginx/access.log-${YDAY}" > /tmp/dr-access.log 2>/dev/null
else
  cp /var/log/nginx/access.log /tmp/dr-access.log 2>/dev/null
  echo "  (注意: 昨天日志归档未找到, 展示当前累计数据)"
fi
python3 << 'PYEOF'
import re
from collections import Counter
try:
    lines = open('/tmp/dr-access.log', errors='ignore').read().splitlines()
except:
    lines = []
# 过滤明显扫描器/爬虫 UA
SKIP_UA = re.compile(r'cf-reverse-scanner|python-requests|curl/|wget|bot|crawler|spider|scanner|zgrab|masscan|nmap|headless', re.I)
total = 0
visitors = set()
status = Counter()
paths = Counter()
for line in lines:
    m = re.match(r'(\S+) .*?"(?:GET|POST|HEAD) (\S+) HTTP[^"]*" (\d{3}) .*"([^"]*)"', line)
    if not m:
        continue
    ip, path, code, ua = m.group(1), m.group(2).split('?')[0], m.group(3), m.group(4)
    if SKIP_UA.search(ua or ''):
        continue
    total += 1
    visitors.add(ip)
    status[code] += 1
    if code in ('200', '301') and path not in ('/favicon.ico', '/robots.txt', '/wp-admin/install.php', '/manifest.json', '/sw.js'):
        paths[path] += 1
print(f'  ★ 昨日访客数(独立IP): {len(visitors)} 人')
print(f'  ★ 有效访问次数: {total} 次')
ok = sum(v for k, v in status.items() if k.startswith('2') or k == '301')
print(f'  成功响应(2xx/301): {ok} 次')
print('  热门页面 TOP5:')
for p, c in paths.most_common(5):
    print(f'    {c:>4} {p[:50]}')
PYEOF
echo

# ---------- 3. GitHub 数据 ----------
echo "【GitHub 数据】"
GH=$(curl -s -m 10 https://api.github.com/users/korolkk 2>/dev/null)
GHREPOS=$(curl -s -m 10 "https://api.github.com/users/korolkk/repos?per_page=100&sort=updated" 2>/dev/null)
if [ -n "$GH" ]; then
  echo "$GH" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(f'  关注者: {d.get(\"followers\", 0)} | 关注中: {d.get(\"following\", 0)} | 公开仓库: {d.get(\"public_repos\", 0)}')
except Exception as e:
    print('  解析失败:', e)
"
  echo "$GHREPOS" | python3 -c "
import json, sys
try:
    repos = json.load(sys.stdin)
    if isinstance(repos, list):
        stars = sum(r.get('stargazers_count',0) for r in repos)
        print(f'  仓库总Star: {stars} | 最近更新: {repos[0][\"name\"]} ({repos[0].get(\"updated_at\",\"\")[:10]})' if repos else '  无仓库')
except Exception as e:
    print('  解析失败:', e)
"
else
  echo "  GitHub 数据获取失败"
fi
echo

# ---------- 4. 最新评论（按昨天过滤） ----------
echo "【昨日评论】"
YDAY_STR=$(TZ='Asia/Shanghai' date -d 'yesterday' '+%Y-%m-%d')
STATS=$(curl -s -m 10 -b /tmp/dr-cj.txt http://127.0.0.1:3001/api/admin/stats 2>/dev/null)
echo "$STATS" | YDAY_STR="$YDAY_STR" python3 -c "
import json, sys, os
try:
    d = json.load(sys.stdin)
    yday = os.environ.get('YDAY_STR', '')
    total = d.get('commentTotal', 0)
    print(f'  评论总数: {total} 条')
    recents = d.get('recentComments', [])
    yesterday_new = [c for c in recents if (c.get('created_at') or '').startswith(yday)]
    if yesterday_new:
        print(f'  ★ 昨日新增评论 {len(yesterday_new)} 条:')
        for c in yesterday_new[:5]:
            author = c.get('author') or '匿名'
            print(f'    - {author}: {str(c.get(\"content\",\"\"))[:50]}')
    else:
        print('  (昨天暂无新评论)')
except Exception as e:
    print('  评论数据解析失败:', e)
"
echo
echo "========== 报告结束 =========="
rm -f /tmp/dr-cj.txt /tmp/dr-access.log
