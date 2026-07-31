# DocDocGo API — Field Guide

> Practical notes for agents and humans using **search** well.  
> Base: `https://docdocgo.lak.nz/api`

Friend Bot (and this guide’s primary path) uses **`GET /api/search` only**.

---

## Quick reference

| Endpoint | Method | Friend Bot? | Purpose |
|----------|--------|-------------|---------|
| **`/api/search`** | **GET** | **YES — only this** | Keyword / multi-word ranked search + match-centered snippets |
| `/api/read/:filename` | GET | no | Full document (large) |
| `/api/files` | GET | no | List filenames |
| `/api/rag` | POST | no | Vector chunks |
| `/api/docs` | GET | optional | Live parameter docs |

---

## `GET /api/search` (the one that matters)

### Parameters

| Param | Required | Default | Notes |
|-------|----------|---------|-------|
| `q` | ✅ | — | Min **4** characters. Multi-word = ranked relevance |
| `limit` | ❌ | **100** | Always set explicitly (e.g. 5) |
| `page` | ❌ | 1 | Deterministic pages, no overlap |
| `context` | ❌ | 300 | **Snippet padding** chars on each side of the match anchor. Alias: `contextChars` |
| `groupDistance` | ❌ | **250** | Max gap between consecutive word hits to stay in one group. Alias: `group`. **Independent of `context`** |
| `filter` | ❌ | `all` | `all` · `books` · `all-hawkins-books` · `lectures` · exact source path |
| `caseSensitive` | ❌ | false | Alias: `case=true` |
| `wholeWords` | ❌ | true | Alias: `whole=false` for partials (`--partial`) |
| `useRegex` | ❌ | false | Alias: `regex=true` |

### How matching actually works

1. **Tokenize** `q` on whitespace. Light stop-words are dropped from *matching* (not from exact-phrase detection).
2. Find every hit of those keywords in each allowed source (`filter`).
3. **Group** hits when the gap between consecutive hits is **&lt; `groupDistance`** (default 250).  
   - This used to use `context`, so large `-c` chained `"is"` at file start to `"causing"` thousands of chars later → WEBVTT intro junk.  
   - **Fixed:** grouping and padding are separate.
4. For each group, choose an **anchor**:
   - **Exact full-query phrase** near the group if present, else
   - **Densest keyword cluster** (most unique query words in the smallest span).
5. Build `snippet` = text from `anchor - context` … `anchor + context` (whitespace collapsed; leading/trailing `...` if truncated).
6. **Score** ≈ `(unique_keywords_in_group + proximity_bonus) × (1.5 if exact phrase in snippet else 1.0)`.
7. Sort by score, then proximity; near-ties shuffled with a **seeded** PRNG (stable for same params).
8. **Paginate** after sort: `results = all[ (page-1)*limit : page*limit ]`.

### Response shape

```json
{
  "query": "nothing is causing anything",
  "total_matches": 20012,
  "files_count": 236,
  "page": 1,
  "limit": 5,
  "total_pages": 4003,
  "options": {
    "contextChars": 400,
    "groupDistance": 250,
    "maxResults": 5,
    "filter": "lectures",
    "caseSensitive": false,
    "wholeWords": true,
    "useRegex": false
  },
  "results": [
    {
      "path": "Verification_of_Spiritual_Realities_Part_1_enxautogen_html",
      "offset": 353,
      "match_text": ["nothing", "is", "causing", "anything"],
      "snippet": "... That >>>nothing is causing anything<<<. first illusion ...",
      "score": 7.5,
      "match_count": 4,
      "proximity": 27,
      "chapter": "optional for books"
    }
  ],
  "warning": null,
  "docs": "/api/docs"
}
```

| Field | Meaning |
|-------|---------|
| `path` | Source id — attribute quotes with this |
| `offset` | Char offset of the **anchor** (phrase or dense cluster start) |
| `snippet` | Padded text around the anchor — this is your quote material |
| `match_text` | **Unique keywords** in the group (deduped), not every span |
| `match_count` | Count of those unique keywords |
| `proximity` | Span length of the anchor (tighter is better) |
| `score` | Higher is better; exact phrase tends to land at 7.5-ish for 4-word hits |
| `total_pages` | **Real** page count: `ceil(total_matches / limit)` |
| `warning` | Present when `filter` matches no sources (e.g. typo `hawkins`) |

---

## Craft: getting good quotes from search alone

### Prefer phrases
```bash
# strong
curl -sG 'https://docdocgo.lak.nz/api/search' \
  --data-urlencode 'q=nothing is causing anything' \
  --data-urlencode 'limit=5' \
  --data-urlencode 'context=500'

# weaker (sparse keywords, lower chance of exact-phrase bonus)
curl -sG 'https://docdocgo.lak.nz/api/search' \
  --data-urlencode 'q=nothing causing' \
  --data-urlencode 'limit=5'
```

### Context vs groupDistance
| Goal | What to set |
|------|-------------|
| Longer readable quote | Raise **`context`** (400–800). Safe now. |
| Tighter multi-word grouping | Lower **`groupDistance`** (e.g. 120–200) |
| Looser grouping | Raise `groupDistance` (e.g. 400) — use sparingly |

### Filters
| Value | Use |
|-------|-----|
| `all` | Default whole library |
| `books` | Books only |
| `all-hawkins-books` | Hawkins books (not `hawkins`) |
| `lectures` | Lecture transcripts (not `lecture`) |
| exact `path` | Drill into one source from a prior hit |

Bad filters used to fail **silently**. They may now include a `warning` object when no sources match.

### Multi-query habit (agents)
1. Member’s key phrase (`limit=5`, `context=400–600`)
2. Synonym / Hawkins vocabulary (`all-hawkins-books`)
3. Optional lectures pass
4. If empty: shorter term + `wholeWords=false`

### Display tips
- Strip surrounding `...` from snippets for chat.
- Highlight the query phrase inside the snippet when present.
- Attribute cleaned title + raw `path`.
- Don’t dump 10 long hits into Discord — pick 1–3.

---

## Shell one-liners

```bash
# Basic
curl -sG 'https://docdocgo.lak.nz/api/search' \
  --data-urlencode 'q=surrender' \
  --data-urlencode 'limit=3' \
  --data-urlencode 'filter=all-hawkins-books' \
  --data-urlencode 'context=200' | jq '.results[] | {path, score, snippet}'

# Longer centered passage
curl -sG 'https://docdocgo.lak.nz/api/search' \
  --data-urlencode 'q=nothing is causing anything' \
  --data-urlencode 'limit=3' \
  --data-urlencode 'context=600' \
  --data-urlencode 'filter=lectures' | jq -r '.results[0].snippet'
```

### Python

```python
import urllib.parse, urllib.request, json

def search(q, limit=5, filter="all", context=400, page=1, **extra):
    params = {"q": q, "limit": limit, "filter": filter, "context": context, "page": page}
    params.update(extra)
    url = "https://docdocgo.lak.nz/api/search?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": "docdocgo-guide/2", "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=45) as r:
        return json.loads(r.read().decode())

data = search("nothing is causing anything", limit=3, filter="lectures", context=600)
for hit in data["results"]:
    print(hit["path"], hit["score"], hit["snippet"][:200])
```

---

## Other endpoints (not used by Friend Bot)

### `GET /api/read/:filename`
Full document JSON `{ path, content }`. Filenames must match `path` from search. Large payloads — avoid in chat bots.

### `GET /api/files`
Flat list of source names. No metadata.

### `POST /api/rag`
Semantic chunks via embeddings. Different tool; not a substitute for attributable keyword quotes.

### `GET /api/docs`
Live docs (includes `context`, `groupDistance`, aliases).

---

## Pitfalls (updated)

1. **`limit` defaults to 100** — always set it.
2. **`context` ≠ `contextChars` name** — both query names accepted now; response still reports `options.contextChars`.
3. **`case` / `whole` / `regex` vs camelCase** — both accepted now.
4. **Filter typos** — prefer presets; check `warning` / `files_count`.
5. **`match_text` is keywords**, not highlight spans.
6. **Min query length 4** — shorter returns empty.
7. **`context=0`** still falls back to 300 (`parseInt` falsy).
8. **Library scope** — Hawkins-heavy + ACIM / Nisargadatta / Lamsa etc.
9. ~~Large `context` causes file-start WEBVTT snippets~~ — **fixed** via `groupDistance` + phrase-centered anchors (2026-07-31).
10. ~~`total_pages` equals `total_matches`~~ — **fixed** to real page count.

---

## Included examples

```bash
./examples/search.sh "surrender" 3
./examples/search.sh "nothing is causing anything" 5 lectures -c 600
./examples/search.sh "ego" 5 --partial
./examples/tts.sh "Text to speak"
```

---

> Updated: 2026-07-31 — search grouping/centering fix + Friend Bot search-only policy  
> Repo: https://github.com/friend-bot-dnd/docdocgo-api-guide
