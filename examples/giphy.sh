#!/usr/bin/env bash
# ============================================================================
# giphy.sh — GIPHY search + download tool
# ============================================================================
# Usage:
#   ./giphy.sh "search term"          # search, download #1 to /tmp/
#   ./giphy.sh "search term" 3        # download result #3 (1-indexed)
#   ./giphy.sh "search term" --list   # list top 10 with index + title
#   ./giphy.sh "search term" -o out   # custom output filename
#   ./giphy.sh "search term" --url    # just print the URL, don't download
#
# Default rating: g (use --pg or --r13 for broader results)
# ============================================================================

set -euo pipefail

# --- Config ---
KEY_FILE="$(dirname "$0")/.giphy_key"
if [ -f "$KEY_FILE" ]; then
  source "$KEY_FILE"
else
  # fallback: try environment
  GIPHY_API_KEY="${GIPHY_API_KEY:-}"
fi

if [ -z "${GIPHY_API_KEY:-}" ]; then
  echo "❌  No GIPHY API key found."
  echo "    Set GIPHY_API_KEY env var or create $(dirname "$0")/.giphy_key with:"
  echo '    GIPHY_API_KEY="your_key_here"'
  exit 1
fi

LIMIT=10
RATING="g"
LIST_ONLY=false
URL_ONLY=false
OUTPUT_FILE=""
INDEX=1

# --- Parse args ---
POSITIONAL=()
while [ $# -gt 0 ]; do
  case "$1" in
    --list|-l) LIST_ONLY=true; shift ;;
    --url|-u)  URL_ONLY=true; shift ;;
    --pg|--r13) RATING="pg-13"; shift ;;
    --r|--r17) RATING="r"; shift ;;
    -o) OUTPUT_FILE="$2"; shift 2 ;;
    -o*) OUTPUT_FILE="${1:2}"; shift ;;
    --limit) LIMIT="$2"; shift 2 ;;
    --limit=*) LIMIT="${1#*=}"; shift ;;
    [0-9]*) INDEX="$1"; shift ;;
    *) POSITIONAL+=("$1"); shift ;;
  esac
done

QUERY="${POSITIONAL[*]:-}"
if [ -z "$QUERY" ]; then
  echo "Usage: $0 \"search term\" [index|--list|--url] [-o file] [--pg|--r13]"
  echo ""
  echo "Examples:"
  echo "  $0 \"cleaning up\"          # search + download #1"
  echo "  $0 \"funny cat\" 3          # download #3"
  echo "  $0 \"dancing\" --list       # list top 10"
  echo "  $0 \"done\" --url           # just print URL of #1"
  echo "  $0 \"memes\" --pg -o meme   # PG-13 rating, custom name"
  exit 1
fi

# --- Fetch ---
ENCODED=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$QUERY")
RESPONSE=$(curl -s "https://api.giphy.com/v1/gifs/search?api_key=${GIPHY_API_KEY}&q=${ENCODED}&limit=${LIMIT}&rating=${RATING}")

# --- Parse ---
python3 -c "
import json, sys

data = json.load(sys.stdin)
results = data.get('data', [])
if not results:
    print('❌  No results found.')
    sys.exit(1)

list_only = '${LIST_ONLY:-false}' == 'true'
url_only = '${URL_ONLY:-false}' == 'true'
index = int('${INDEX:-1}')
output = '${OUTPUT_FILE}'

title = results[index-1].get('title', '(no title)').strip()
gif_url = results[index-1]['images']['original']['url']
gif_id = results[index-1]['id']

if list_only:
    print(f'📋  Top {len(results)} GIFs for \"$QUERY\":')
    for i, g in enumerate(results, 1):
        t = g.get('title', '(no title)').strip() or '(untitled)'
        print(f'  {i}. {t[:55]}')
    sys.exit(0)

# Show summary
plural = 's' if len(results) > 1 else ''
print(f'🔍  giphy › \"$QUERY\" ({len(results)} result{plural})')
print(f'    #{index}: {title}')
print(f'    ID: {gif_id}')
print(f'    URL: {gif_url}')

if url_only:
    print(gif_url)
    sys.exit(0)

# Download
import urllib.request
if not output:
    safe = ''.join(c if c.isalnum() or c in ' _-' else '_' for c in title[:40]).strip().lower() or 'giphy'
    output = f'{safe}_{gif_id}.gif'
    if not output.startswith('/'):
        output = '/tmp/' + output

urllib.request.urlretrieve(gif_url, output)
size = __import__('os').path.getsize(output)
print(f'    Downloaded: {output} ({size//1024} KB)')
" <<< "$RESPONSE"
