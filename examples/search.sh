#!/bin/bash
# docdocgo GET /api/search helper
# Usage:
#   ./search.sh "query" [limit] [filter]
#   ./search.sh "query" 5 lectures -c 600
#   ./search.sh "query" --partial
#   ./search.sh "query" -p 2

set -euo pipefail
API="${DOCDOCGO_API:-https://docdocgo.lak.nz/api/search}"
UA="${DOCDOCGO_UA:-docdocgo-api-guide/2.1}"

QUERY="${1:-}"
if [ -z "$QUERY" ]; then
  cat <<'USAGE'
Usage: ./search.sh "query" [limit] [filter] [options]

Options:
  -p, --page N         Page (default 1)
  -c, --context N      Snippet padding (default 400)
  -g, --group-distance Max gap for multi-word groups (server default 250)
  --partial            wholeWords=false
  --full               Print full snippets
  --json               Raw JSON

Examples:
  ./search.sh "surrender" 3
  ./search.sh "nothing is causing anything" 5 lectures -c 600
  ./search.sh "ego" 5 all-hawkins-books --partial
USAGE
  exit 1
fi
shift

LIMIT=5
FILTER="all"
PAGE=1
CONTEXT=400
GROUP=""
PARTIAL=false
FULL=false
JSON=false

while [ $# -gt 0 ]; do
  case "$1" in
    -p|--page) PAGE="$2"; shift 2 ;;
    -c|--context) CONTEXT="$2"; shift 2 ;;
    -g|--group-distance) GROUP="$2"; shift 2 ;;
    --partial) PARTIAL=true; shift ;;
    --full) FULL=true; shift ;;
    --json) JSON=true; shift ;;
    *)
      if [[ "$1" =~ ^[0-9]+$ ]] && [ "$LIMIT" = "5" ]; then
        LIMIT="$1"
      elif [ "$FILTER" = "all" ]; then
        FILTER="$1"
      fi
      shift
      ;;
  esac
done

ENCODED=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$QUERY")
URL="$API?q=$ENCODED&limit=$LIMIT&page=$PAGE&filter=$FILTER&context=$CONTEXT"
if [ -n "$GROUP" ]; then URL="$URL&groupDistance=$GROUP"; fi
if [ "$PARTIAL" = true ]; then URL="$URL&wholeWords=false"; fi

echo ""
echo "🔍  docdocgo › \"$QUERY\""
echo "    Limit: $LIMIT | Filter: $FILTER | Page: $PAGE | Context: $CONTEXT"
echo "    GET /api/search"
echo ""

curl -s "$URL" -H "User-Agent: $UA" -H "Accept: application/json" | python3 - "$FULL" "$JSON" <<'PY'
import json, sys, re
full = sys.argv[1] == "True" or sys.argv[1] == "true"
as_json = sys.argv[2] == "True" or sys.argv[2] == "true"
data = json.load(sys.stdin)
if as_json:
    print(json.dumps(data, indent=2)[:12000])
    raise SystemExit(0)
if data.get("warning"):
    print("⚠️ ", data["warning"].get("message"))
    print()
results = data.get("results") or []
print(f"📚  {data.get('total_matches', 0):,} matches · {data.get('files_count', 0)} files · page {data.get('page')}/{data.get('total_pages')}")
opts = data.get("options") or {}
print(f"    contextChars={opts.get('contextChars')} groupDistance={opts.get('groupDistance')}")
print()
q = data.get("query") or ""
for i, row in enumerate(results, 1):
    path = row.get("path", "")
    sn = (row.get("snippet") or "").strip()
    if sn.startswith("..."): sn = sn[3:]
    if sn.endswith("..."): sn = sn[:-3]
    sn = sn.strip()
    m = re.search(re.escape(q), sn, re.I)
    if m:
        sn = sn[:m.start()] + ">>>" + sn[m.start():m.end()] + "<<<" + sn[m.end():]
    if not full and len(sn) > 480:
        hi = sn.find(">>>")
        left = max(0, hi - 140) if hi >= 0 else 0
        sn = ("..." if left else "") + sn[left:left+480] + "..."
    title = path.replace("_enxautogen_html","").replace("_html","").replace("_"," ")
    print(f"#{i} {title}")
    print(f"   path: {path}")
    print(f"   score {row.get('score')} · prox {row.get('proximity')} · offset {row.get('offset')}")
    print(f"   {sn}")
    print()
PY
