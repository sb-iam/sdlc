# HL01_LL01: Core shortening and resolution logic

## Parent
HL01: URL Shortener Service

## Problem
Need a core engine that generates 6-char alphanumeric codes for URLs,
resolves codes back to URLs, and tracks click counts per code.

## Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| REQ-01 | Generate unique 6-char alphanumeric short code for any valid URL | Must |
| REQ-02 | Resolve a short code back to the original URL | Must |
| REQ-03 | Track click count (incremented on each resolve) | Must |
| REQ-04 | Reject invalid URLs (no scheme, empty string) | Must |
| REQ-05 | Reject resolution of non-existent codes | Must |
| REQ-06 | Support custom short codes (user-provided alias) | Must |
| REQ-07 | Reject custom codes that collide with existing ones | Must |

## Acceptance criteria

| ID | Criterion | Traces to |
|----|-----------|-----------|
| AC-01 | `shorten("https://example.com")` returns 6-char alphanumeric | REQ-01 |
| AC-02 | `resolve(code)` returns `"https://example.com"` | REQ-02 |
| AC-03 | `resolve(code)` increments click count each time | REQ-03 |
| AC-04 | `stats(code)` returns `{"url", "clicks", "created_at"}` | REQ-03 |
| AC-05 | `shorten("")` raises `ValueError` | REQ-04 |
| AC-06 | `shorten("not-a-url")` raises `ValueError` | REQ-04 |
| AC-07 | `resolve("nonexistent")` raises `KeyError` | REQ-05 |
| AC-08 | `shorten(url, alias="x")` stores with code `"x"` | REQ-06 |
| AC-09 | `shorten(url2, alias="x")` raises `ValueError` (collision) | REQ-07 |

## Interfaces

```python
class URLShortener:
    def shorten(self, url: str, alias: str | None = None) -> str: ...
    def resolve(self, code: str) -> str: ...
    def stats(self, code: str) -> dict: ...
```

## Non-goals
- No HTTP server
- No persistent storage
- No authentication

---

## Traceability contract (for reviewers)

Every downstream artifact MUST satisfy ALL. Missing = P0.

- [ ] plan_HL01_LL01.md: Every REQ-xx has a section
- [ ] plan_HL01_LL01.md: Every AC-xx mapped to function
- [ ] test_HL01_LL01.md: Every AC-xx has a test case
- [ ] tests/: Every test has `# Covers: AC-xx`
- [ ] src/: Every REQ-xx implemented
- [ ] change.md: Updated

