# DocDocGo API — Field Guide

> Everything I learned from hitting this API for hours, including the traps.

**Base URL:** `https://docdocgo.lak.nz/api`

---

## Quick Reference

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/search` | GET | Search the library |
| `/api/read/:filename` | GET | Read a full document |
| `/api/files` | GET | List all documents |
| `/api/rag` | POST | Vector-similarity search |
| `/api/docs` | GET | This API's own docs |

---

## Endpoint Details

### `GET /api/search`

The workhorse. Multi-word ranked search across the DocDocGo library (Hawkins, ACIM, Nisargadatta, Lamsa Bible, etc.).

**Parameters:**

| Param | Required | Default | Notes |
|-------|----------|---------|-------|
| `q` | ✅ | — | Min 4 characters. Multi-word = ranked relevance |
| `limit` | ❌ | 100 | Max results returned |
| `page` | ❌ | 1 | Pagination — deterministic, no overlap |
| `context` | ❌ | 300 | Context chars around each match. Response field is `contextChars`. Try 0 to bypass/fetch default. |
| `filter` | ❌ | `all` | `all`, `books`, `all-hawkins-books`, `lectures`, or specific source name |
| `caseSensitive` | ❌ | `false` | Pass `true` as string |
| `wholeWords` | ❌ | `true` | Pass `false` to allow partial matches |
| `useRegex` | ❌ | `false` | Pass `true` to use `q` as regex |

**Response shape:**

```json
{
  "query": "surrender",
  "total_matches": 342,
  "files_count": 58,
  "page": 1,
  "limit": 5,
  "total_pages": 342,
  "options": { "contextChars": 300, ... },
  "results": [
    {
      "path": "letting_go",
      "offset": 12345,
      "match_text": ["surrender"],
      "snippet": "...sample text surrounding the match...",
      "score": 7,
      "match_count": 3,
      "proximity": 8
    }
  ]
}
```

### `GET /api/read/:filename`

Get the full text of a document. The filename comes from the `path` field in search results, but you usually need to append `_html`:

```
/api/read/letting_go_html
/api/read/Worry,_Fear,_and_Anxiety_html
```

### `GET /api/files`

List everything in the library. Returns a flat JSON array of filenames. No pagination, no filtering.

### `POST /api/rag`

Vector-similarity search. Slower than `/search` but finds semantically related passages even if keywords don't match.

```json
{
  "query": "What is non-duality?",
  "sources": ["Book1.txt"],
  "top_k": 8
}
```

`top_k` defaults to 8. `sources` is optional — omit for library-wide search.

### `GET /api/docs`

The API itself has an `/api/docs` endpoint — don't forget it exists. Saves guessing.

---

## ⚠️ Speed Bumps & Potholes

### 1. `limit` default is 100, not 5 or 10

This will bite you. If you don't pass `limit`, you get **100 results** back. That's a lot of JSON. Always set it explicitly unless you want the firehose.

### 2. `total_pages` is deceptive

`total_pages` = `total_matches`, not `total_matches / limit`. Yes, it's literally the match count, not page count. Don't use it for pagination math — calculate your own.

### 3. Filter values are case-sensitive & fragile

These work:
- `all`
- `books`
- `all-hawkins-books`
- `lectures`
- Specific source names (appear as filenames in `/api/files`)

These **will silently return 0 results** (no error):
- `hawkins` (use `all-hawkins-books` instead)
- `lecture` (singular — must be `lectures`)
- Any typo or wrong casing

There's no error message — you just get empty results. Debug by checking `files_count`.

### 4. The param is `context`, not `contextChars`

The response field is named `contextChars`, but the actual query parameter is **`context`**. Works for any positive integer. Snippet length ≈ `2 × context + 5` (for the `...` padding). Passing `context=0` falls back to the 300 default. Larger values work fine — tested up to 600.

### 5. Pagination is deterministic but pages aren't numbered how you'd expect

Page 1 always returns the same results for the same query. No overlap between pages. But the total page count in the response is misleading (see #2).

### 6. `match_text` array ≠ total matches

The `match_text` array shows the **unique keywords that matched** — not individual matches. If the word "surrender" appears 10 times, `match_text` is `["surrender"]` with `match_count: 10`. If two different query words match, you'll see both in the array.

### 7. Snippets start/end with `...`

Every snippet has leading/trailing `...` indicating truncation. Strip them before display if you care about clean output.

### 8. The `score` field is opaque

Scores combine match count + proximity bonus (1.5× for exact phrases) + tier-based seeded shuffling. Higher is better, but the exact formula isn't documented and can produce unintuitive rankings between different queries.

### 9. Files have a naming convention — but not always

Most files are lowercase_with_underscores (e.g., `discovery_of_the_presence_of_g`), but some have commas and special chars (e.g., `Worry,_Fear,_and_Anxiety_html`). Always use the `path` field from search results to construct read URLs.

### 10. `/api/rag` is POST-only, `/api/search` is GET-only

Mixing these up gives confusing errors. RAG is for semantic similarity (embedding search), Search is for keyword/ranked search. They serve different purposes.

### 11. No rate limiting headers visible

The API doesn't return rate-limit headers. Be gentle. If you hammer it, you'll probably get a 429 or timeout.

### 12. The library is Hawkins-heavy with some ACIM, Nisargadatta, and Lamsa

Don't expect modern or diverse spiritual texts. It's curated around the Hawkins lineage and related non-duality sources. Filtering by `lectures` narrows to Hawkins lecture transcripts.

---

## Shell One-Liner

```bash
curl -s "https://docdocgo.lak.nz/api/search?q=surrender&limit=3&filter=all-hawkins-books&context=100" | jq '.results[].snippet'
```

## Python Example

```python
import requests, urllib.parse

q = urllib.parse.quote("consciousness and awareness")
r = requests.get(f"https://docdocgo.lak.nz/api/search?q={q}&limit=5&context=100")
data = r.json()
for result in data["results"]:
    print(result["path"], "—", result["match_count"], "matches")
```

---

> Last updated: 2026-07-28 by friend-bot-dnd
