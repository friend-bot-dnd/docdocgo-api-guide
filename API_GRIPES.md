# DocDocGo API — Gripes & Suggested Fixes

> Filed 2026-07-28 after extensive integration testing.
> Repo: https://github.com/friend-bot-dnd/docdocgo-api-guide
>
> These are the friction points that cost time when integrating. Each entry
> describes the problem, why it matters, and a suggested fix.

---

## 1. `total_pages` is actually `total_matches`

**Problem:** The response field `total_pages` contains the total match count, not
the number of pages. With `limit=5` and `total_matches=8265`, the API returns
`total_pages: 8265`. This makes pagination math unreliable unless you already
know the field is misnamed.

**Impact:** Anyone writing a paginated UI has to guess whether `total_pages`
means pages or matches. The wrong assumption produces off-by-8000 errors.

**Fix:** Rename to `total_matches` (which already exists alongside it) or make
`total_pages` actually compute `ceil(total_matches / limit)`.

---

## 2. Silent failures on bad filter values

**Problem:** Passing `filter=hawkins` instead of `filter=all-hawkins-books`, or
`filter=lecture` instead of `lectures`, returns zero results with no error, no
warning, and no hint about valid values. Same for any unrecognised filter
string.

**Impact:** Hard to distinguish "no content found" from "wrong filter name."
Debugging requires cross-referencing against `/api/docs` or trial-and-error.

**Fix:** Return a `warning` or `available_filters` field when an unrecognised
filter is given. Or at minimum, return an error for filter values that match
nothing. Even a `404` would be more informative than a silent empty result set.

---

## 3. Parameter name ≠ response field name

**Problem:** The query parameter for context width is `context`, but the
response object names it `contextChars`. If you read the response to figure out
what parameters to send, you'll send `contextChars` and it will be silently
ignored.

**Impact:** One extra round of debugging to discover the rename. Feels like a
bug until you figure it out.

**Fix:** Either rename the response field to `context` (matching the parameter),
or accept both `context` and `contextChars` as query parameters.

---

## 4. `match_text` is deduplicated keywords, not match spans

**Problem:** `match_text` returns unique query terms that hit somewhere in the
document — not the actual text fragments that matched. A search for "surrender
acceptance" where only "surrender" appears in the snippet might still list both
words in `match_text`.

**Impact:** Confusing if you're trying to highlight matched spans in the
snippet. The field name implies it contains the actual matched text.

**Fix:** Either rename to `matched_keywords` to reflect what it actually is, or
return actual match spans with offsets.

---

## 5. No rate-limit headers

**Problem:** Responses don't include `X-RateLimit-Remaining`,
`X-RateLimit-Reset`, or any standard rate-limit signalling.

**Impact:** Clients have to discover rate limits by hitting them. A 429 or
timeout is the only feedback. This discourages efficient use — you either
hammer it carefully or waste time between requests.

**Fix:** Add standard `X-RateLimit-*` headers. Even a simple
`X-RateLimit-Remaining: N` would help clients self-regulate.

---

## 6. `context=0` silently falls back to 300

**Problem:** Passing `context=0` (reasonable intuition: "no context, give me
the raw hit") resets to the default 300 instead of returning the entire matched
passage or minimal context.

**Impact:** Forces an extra `/api/read` call if you actually want the full
document around a match. Inconsistent with the "0 means unlimited" convention
many APIs use.

**Fix:** Either document that 0 falls back to default, or make 0 return no
truncation (full document).

---

## 7. `/api/files` returns flat names with no metadata

**Problem:** The files endpoint returns a flat JSON array of filenames. No file
size, word count, author, category (book vs. lecture vs. translation), or date.

**Impact:** You can't filter or organise the library without fetching and
parsing every file. Want to list only Hawkins lectures? You'll need to read
every filename and guess based on naming conventions.

**Fix:** Return an object with metadata per file:

```json
{
  "files": [
    {
      "name": "letting_go",
      "type": "book",
      "author": "David R. Hawkins",
      "size_bytes": 450000,
      "word_count": 72000
    }
  ]
}
```

---

## 8. No way to jump to a specific result by offset

**Problem:** Search results include `path` + `offset`, but there's no endpoint
to fetch a specific passage at that offset. To get the full context around a
match, you have to either:
- Re-run the search with `context=9999` (hacky, wastes server resources)
- Fetch the entire document via `/api/read/:filename` and seek manually

**Impact:** Inefficient. The server already computed the offset — it could
return the passage window without the client having to re-fetch anything.

**Fix:** Add an endpoint like `/api/passage?path=letting_go&offset=12345&context=300`
that returns text around a given offset. The offset data is already in search
results — just expose a way to use it.

---

## Summary

| # | Gripe | Severity | Fix Difficulty |
|---|-------|----------|----------------|
| 1 | `total_pages` = `total_matches` | Medium | Trivial (rename or compute) |
| 2 | Silent filter failures | Medium | Trivial (validate + warn) |
| 3 | `context` vs `contextChars` mismatch | Low | Trivial (alias param) |
| 4 | `match_text` name misleading | Low | Trivial (rename field) |
| 5 | No rate-limit headers | Low | Easy (add headers) |
| 6 | `context=0` falls back silently | Low | Easy (document or fix) |
| 7 | Flat file list, no metadata | Medium | Medium (return enriched objects) |
| 8 | No offset/passage endpoint | Medium | Medium (new endpoint) |

Most fixes are cheap. #1 and #2 are the ones that actually waste time.
