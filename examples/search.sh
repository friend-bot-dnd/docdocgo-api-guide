#!/bin/bash
# docdocgo search — improved
# Usage:
#   ./search.sh "query" [limit] [filter]          # basic search
#   ./search.sh "query" -p 2                       # page 2
#   ./search.sh "query" 3 lectures                 # lectures only
#   ./search.sh "query" 1 --full                   # full snippet, no truncation

API="https://docdocgo.lak.nz/api/search"
QUERY="$1"

# Parse args
LIMIT=5
FILTER="all"
PAGE=1
FULL=false
CONTEXT=300

shift
while [ $# -gt 0 ]; do
    case "$1" in
        -p|--page) PAGE="$2"; shift 2 ;;
        -c|--context) CONTEXT="$2"; shift 2 ;;
        --full) FULL=true; shift ;;
        --raw) LIMIT="$2"; shift 2; RAW=true ;;
        *) 
            if [ "$LIMIT" = "5" ] && [ "$FILTER" = "all" ]; then
                if [[ "$1" =~ ^[0-9]+$ ]]; then
                    LIMIT="$1"
                else
                    FILTER="$1"
                fi
            elif [ "$FILTER" = "all" ]; then
                FILTER="$1"
            fi
            shift
            ;;
    esac
done

if [ -z "$QUERY" ]; then
    echo "Usage: ./search.sh \"query\" [limit] [filter] [options]"
    echo ""
    echo "Arguments:"
    echo "  query             Search query (required)"
    echo "  limit             Results to show (default: 5)"
    echo "  filter            all (default), books, all-hawkins-books, lectures"
    echo ""
    echo "Options:"
    echo "  -p, --page N      Page number (default: 1)"
    echo "  -c, --context N   Context chars around each match (default: 300)"
    echo "  --full            Show full snippet without truncation"
    echo ""
    echo "Examples:"
    echo "  ./search.sh \"surrender\" 3"
    echo "  ./search.sh \"forgiveness\" 2 lectures"
    echo "  ./search.sh \"consciousness\" -p 2"
    echo "  ./search.sh \"ego\" 1 --full"
    echo "  ./search.sh \"love\" 2 -c 100       # smaller snippets"
    exit 1
fi

echo ""
echo "🔍  docdocgo › \"$QUERY\""
echo "    Limit: $LIMIT | Filter: $FILTER | Page: $PAGE | Context: $CONTEXT"
echo ""

# URL-encode query
ENCODED=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$QUERY")

# Fetch results
curl -s "$API?q=$ENCODED&limit=$LIMIT&page=$PAGE&filter=$FILTER&context=$CONTEXT" | python3 -c "
import json, sys

data = json.load(sys.stdin)
results = data.get('results', [])
total_matches = data.get('total_matches', 0)
total_files = data.get('files_count', 0)
total_pages = data.get('total_pages', 0)
page = data.get('page', 1)
limit = int(sys.argv[1]) if len(sys.argv) > 1 else 5
full = sys.argv[2] == 'true' if len(sys.argv) > 2 else False

# Summary line
plural = 'match' if total_matches == 1 else 'matches'
file_plural = 'file' if total_files == 1 else 'files'
print(f'📚  {total_matches:,} {plural} across {total_files} {file_plural}')
if total_pages > 1:
    print(f'📄  Page {page} of {total_pages}')
print()

if not results:
    print('   No results found.')
    print()

for i, r in enumerate(results[:limit], 1):
    path = r.get('path', 'unknown')
    match_count = r.get('match_count', 0)
    score = r.get('score', 0)
    snippet = r.get('snippet', '')
    chapter = r.get('chapter', '')
    match_text = r.get('match_text', [])
    offset = r.get('offset', 0)

    # Clean up path for display
    display_path = path.replace('_enxautogen_html', '').replace('_html', '').replace('_', ' ').strip()
    display_path = ' '.join(w.capitalize() for w in display_path.split())

    print(f'╭──  #{i}  ───────────────────────────────')
    print(f'│ 📄 {display_path}')
    if chapter:
        print(f'│ 📖 {chapter}')
    mtext = ', '.join(f'\"{w}\"' for w in match_text)
    print(f'│ 🎯 {match_count} matches | score {score} | keywords: {mtext}')
    
    if snippet:
        # Clean snippet: remove leading/trailing ...
        clean = snippet.strip()
        if clean.startswith('...'):
            clean = clean[3:]
        if clean.endswith('...'):
            clean = clean[:-3]
        clean = clean.strip()
        
        if full:
            print(f'│')
            print(f'│ {clean}')
        else:
            # Show first 350 chars
            short = clean[:350]
            if len(clean) > 350:
                short += '...'
            print(f'│')
            print(f'│ {short}')
    
    print(f'╰───────────────────────────────────────')
    print()
" "$LIMIT" "$FULL"