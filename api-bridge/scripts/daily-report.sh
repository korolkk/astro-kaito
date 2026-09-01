#!/bin/bash
# KaitoHub 每日数据报告（昨天网站 + 小红书 + GitHub + 昨日评论 + AI资讯 + 黄金）
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

# ---------- 3. GitHub 数据（当日缓存，避免 504/限流） ----------
echo "【GitHub 数据】"
GHCACHE=/opt/api-bridge/cache
mkdir -p "$GHCACHE" 2>/dev/null
GHDAY=$(TZ='Asia/Shanghai' date '+%Y%m%d')
GH_USE_CACHE=""
# fetch_gh: 命中当日缓存直接返回；否则请求 API（带重试），仅合法 JSON 才写缓存
fetch_gh() {
  if [ -f "$2" ]; then cat "$2"; return 0; fi
  local data
  data=$(curl -s -m 12 --retry 4 --retry-delay 3 --retry-connrefused "$1" 2>/dev/null)
  if echo "$data" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
    echo "$data" > "$2"
    echo "$data"
  fi
}
GH=$(fetch_gh "https://api.github.com/users/korolkk" "$GHCACHE/github-users-$GHDAY.json")
GHREPOS=$(fetch_gh "https://api.github.com/users/korolkk/repos?per_page=100&sort=updated" "$GHCACHE/github-repos-$GHDAY.json")
# 当日请求失败：回退昨日缓存并标注
if [ -z "$GH" ]; then
  GHYDAY=$(TZ='Asia/Shanghai' date -d 'yesterday' '+%Y%m%d')
  if [ -f "$GHCACHE/github-users-$GHYDAY.json" ]; then
    GH=$(cat "$GHCACHE/github-users-$GHYDAY.json")
    GH_USE_CACHE="  (缓存数据: 今日接口不可用，展示昨日快照)"
  fi
fi
if [ -z "$GHREPOS" ]; then
  GHYDAY=$(TZ='Asia/Shanghai' date -d 'yesterday' '+%Y%m%d')
  [ -f "$GHCACHE/github-repos-$GHYDAY.json" ] && GHREPOS=$(cat "$GHCACHE/github-repos-$GHYDAY.json")
fi
if [ -n "$GH" ]; then
  [ -n "$GH_USE_CACHE" ] && echo "$GH_USE_CACHE"
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

# ---------- 4. 昨日评论 ----------
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

# ---------- 5. AI 资讯（Hacker News 并行抓取，失败回退 36kr） ----------
echo "【AI 资讯 TOP5】"
# 尝试拉取 HN top stories（重试 2 次）
curl -s -m 15 "https://hacker-news.firebaseio.com/v0/topstories.json" -o /tmp/hn-ids.json 2>/dev/null
if [ ! -s /tmp/hn-ids.json ]; then
  sleep 3
  curl -s -m 15 "https://hacker-news.firebaseio.com/v0/topstories.json" -o /tmp/hn-ids.json 2>/dev/null
fi
python3 << 'PYEOF'
import json, urllib.request, re
from concurrent.futures import ThreadPoolExecutor
KW = re.compile(r'AI|artificial intelligence|LLM|GPT|OpenAI|Anthropic|Claude|Gemini|DeepMind|model|language model|diffusion|transformer|agent|machine learning|neural|NVIDIA|Nvidia|GPU|CUDA|robot|AGI|Sora|Mistral|Llama|Midjourney|Stable Diffusion|RAG|fine.tun|inference', re.I)
shown = 0
try:
    ids = json.load(open('/tmp/hn-ids.json'))
    if not ids: raise ValueError('empty ids')
    def fetch(i):
        try:
            req = urllib.request.Request(f'https://hacker-news.firebaseio.com/v0/item/{i}.json',
                                         headers={'User-Agent': 'Mozilla/5.0'})
            return json.load(urllib.request.urlopen(req, timeout=6))
        except Exception:
            return None
    with ThreadPoolExecutor(max_workers=8) as ex:
        results = list(ex.map(fetch, ids[:30]))
    hits = []
    for d in results:
        if not d or d.get('type') != 'story' or not d.get('title'):
            continue
        title = d.get('title', '')
        url = d.get('url', '') or ''
        text = (d.get('text') or '')[:200]
        if KW.search(title) or KW.search(url) or KW.search(text):
            hits.append((d.get('score', 0), title))
    hits.sort(reverse=True)
    for score, title in hits[:5]:
        shown += 1
        print(f'  {shown}. [{score}分] {title[:60]}')
except Exception as e:
    shown = -1
if shown == 0:
    print('  (Hacker News 暂无 AI 相关热门话题)')
PYEOF
# HN 失败时回退：36kr 快讯过滤 AI 关键词
if grep -q "Hacker News 暂无" /dev/null; then :; fi
if [ "$(python3 -c "import json; ids=json.load(open('/tmp/hn-ids.json')) if __import__('os').path.exists('/tmp/hn-ids.json') else []; print(len(ids))" 2>/dev/null)" = "0" ]; then
  echo "  (Hacker News 不可用，尝试 36kr 快讯...)"
  curl -s -m 20 "http://127.0.0.1:1200/36kr/newsflashes" -o /tmp/36kr.xml 2>/dev/null
  python3 << 'PYEOF'
import re
KW = re.compile(r'AI|人工智能|大模型|智能|模型|芯片|算力|机器人|英伟达|OpenAI|GPT|LLM', re.I)
try:
    xml = open('/tmp/36kr.xml', errors='ignore').read()
    items = re.findall(r'<item>([\s\S]*?)</item>', xml)
    shown = 0
    for it in items:
        t = re.search(r'<title[^>]*>([^<]*)</title>', it)
        d = re.search(r'<description[^>]*>([\s\S]*?)</description>', it)
        title = t.group(1) if t else ''
        desc = re.sub(r'<[^>]+>', '', d.group(1))[:100] if d else ''
        if KW.search(title) or KW.search(desc):
            shown += 1
            print(f'  {shown}. {title[:60]}')
            if shown >= 5: break
    if shown == 0:
        print('  (今日暂无 AI 相关资讯)')
except Exception as e:
    print('  (AI 资讯获取失败)')
PYEOF
fi
echo

# ---------- 6. 今日黄金 ----------
echo "【今日黄金】"
GOLD=$(curl -s -m 10 -H "Referer: https://finance.sina.com.cn" "https://hq.sinajs.cn/list=gds_AUTD" 2>/dev/null)
echo "$GOLD" | python3 -c "
import sys, re
try:
    # 新浪 hq.sinajs.cn 返回 GBK 编码，需按字节读取并解码
    raw = sys.stdin.buffer.read().decode('gbk', errors='replace')
    m = re.search(r'\"(.*?)\"', raw)
    if not m:
        print('  金价数据获取失败')
        sys.exit(0)
    f = m.group(1).split(',')
    # gds_AUTD 沪金延期: 0现价 3最高 4最低 7结算 8昨结 6时间
    price = float(f[0])
    prev = float(f[8]) if f[8] else float(f[2])
    high, low = float(f[3]), float(f[4])
    chg = (price - prev) / prev * 100 if prev else 0
    arrow = '▲' if chg >= 0 else '▼'
    print(f'  沪金(延期): {price:.2f} 元/克')
    print(f'  今日涨跌: {arrow} {abs(chg):.2f}%  (昨结 {prev:.2f})')
    print(f'  区间: 高 {high:.2f} / 低 {low:.2f}')
except Exception as e:
    print('  金价解析失败:', e)
"
echo
echo "========== 报告结束 =========="
rm -f /tmp/dr-cj.txt /tmp/dr-access.log /tmp/hn-ids.json
