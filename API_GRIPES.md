# DocDocGo API — Gripes & status

> Living list. Updated 2026-07-31 after search-centering work.

## Fixed

| # | Issue | Status |
|---|-------|--------|
| 1 | `total_pages` was match count | **Fixed** — `ceil(total_matches / limit)` |
| 3 | `context` vs `contextChars` | **Fixed** — both query aliases accepted; response still uses `contextChars` |
| 9 *(new)* | Large `context` chained distant multi-word hits → file-start / WEBVTT snippets | **Fixed** — `groupDistance` (default 250) independent of context; snippets center on exact phrase or densest cluster |
| | camelCase vs short bool params (`caseSensitive` vs `case`) | **Fixed** — both accepted |
| | Silent empty on bad filter | **Improved** — `warning` object when filter matches zero sources |

## Still open

### A. `match_text` is deduped keywords, not spans
**Impact:** Highlighting must re-find the phrase inside `snippet`.  
**Fix idea:** Optional `match_spans: [{start, end, text}]` relative to snippet or document.

### B. No rate-limit headers
Still no `X-RateLimit-*`. Be gentle.

### C. `context=0` falls back to 300
`parseInt(0) || 300` → 300. Documented; could allow explicit minimal windows later.

### D. `/api/files` has no metadata
Flat names only — no author/type/size.

### E. No first-class `/api/passage?path&offset&context`
Less urgent now that search snippets center correctly with large `context`. Still nice for tooling.

### F. Score formula is only partly documented
Described in README behavior section; still opaque for cross-query comparison.

### G. Stop-word list is custom
Includes some function words; excludes negation (`not`/`no`). Multi-word queries with only stop-words fall back to using all tokens.

---

## Integration checklist for search-only bots

- [x] Always pass `limit`
- [x] Prefer full teaching phrases in `q`
- [x] Use `context` 400–800 for Discord quotes
- [x] Do not raise `groupDistance` casually
- [x] Handle `warning` on filters
- [x] Attribute `path`
- [x] Never invent quotes not in `snippet`
