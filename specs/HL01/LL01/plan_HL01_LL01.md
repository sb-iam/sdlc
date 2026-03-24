# Plan: HL01_LL01 — Core shortening and resolution logic

## 1. Overview

This document defines the architecture, module decomposition, and interface contracts
for the in-memory URL shortener engine specified in `specs/HL01/LL01/spec.md`.

**Scope:** A single `URLShortener` class that generates 6-char alphanumeric codes,
resolves codes to URLs, and tracks per-code click statistics. No HTTP, no persistence,
no auth.

---

## 2. Module decomposition

### 2.1 Module: `shortener` — Implements: REQ-01, REQ-02, REQ-03, REQ-04, REQ-05, REQ-06, REQ-07

Single module in `modules/HL01/LL01/src/shortener.py` containing:

| Component | Responsibility | Implements |
|-----------|---------------|------------|
| `URLShortener` class | Public API: shorten, resolve, stats | REQ-01 through REQ-07 |
| `_validate_url()` | URL validation (scheme + netloc check) | REQ-04 |
| `_generate_code()` | Random 6-char alphanumeric code generation | REQ-01 |
| `_store` (dict) | In-memory mapping: code → `URLEntry` | REQ-01, REQ-02, REQ-03 |

### 2.2 Internal data model

```python
from dataclasses import dataclass, field
from datetime import datetime, timezone

@dataclass
class URLEntry:
    url: str
    clicks: int = 0
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
```

The store is a plain `dict[str, URLEntry]` — no persistence needed per non-goals.

---

## 3. Interface contract

```python
class URLShortener:
    """In-memory URL shortener engine.

    Implements: REQ-01, REQ-02, REQ-03, REQ-04, REQ-05, REQ-06, REQ-07
    """

    def shorten(self, url: str, alias: str | None = None) -> str:
        """Shorten a URL, optionally with a custom alias.

        Args:
            url: Valid URL with scheme (e.g. "https://example.com").
            alias: Optional custom short code.

        Returns:
            6-char alphanumeric code (or the alias if provided).

        Raises:
            ValueError: If url is empty, invalid, or alias already taken.
        """
        ...

    def resolve(self, code: str) -> str:
        """Resolve a short code to the original URL. Increments click count.

        Args:
            code: The short code to resolve.

        Returns:
            The original URL.

        Raises:
            KeyError: If code does not exist.
        """
        ...

    def stats(self, code: str) -> dict:
        """Get statistics for a short code.

        Args:
            code: The short code to query.

        Returns:
            Dict with keys: "url" (str), "clicks" (int), "created_at" (datetime).

        Raises:
            KeyError: If code does not exist.
        """
        ...
```

---

## 4. Detailed design

### 4.1 `shorten(url, alias=None)` — Implements: REQ-01, REQ-04, REQ-06, REQ-07

1. Call `_validate_url(url)` — raises `ValueError` on empty/invalid URL (REQ-04).
2. If `alias` is provided:
   - Check `alias` not in `_store` — raise `ValueError` if collision (REQ-07).
   - Use `alias` as the code (REQ-06).
3. Else:
   - Call `_generate_code()` to produce a 6-char alphanumeric code (REQ-01).
   - Retry if collision (extremely unlikely with 62^6 space).
4. Store `URLEntry(url=url)` in `_store[code]`.
5. Return `code`.

### 4.2 `resolve(code)` — Implements: REQ-02, REQ-03, REQ-05

1. Look up `code` in `_store` — raise `KeyError` if missing (REQ-05).
2. Increment `_store[code].clicks` (REQ-03).
3. Return `_store[code].url` (REQ-02).

### 4.3 `stats(code)` — Implements: REQ-03

1. Look up `code` in `_store` — raise `KeyError` if missing.
2. Return `{"url": entry.url, "clicks": entry.clicks, "created_at": entry.created_at}`.

### 4.4 `_validate_url(url)` — Implements: REQ-04

1. If `url` is empty string → raise `ValueError` (AC-05).
2. Parse with `urllib.parse.urlparse(url)`.
3. If `scheme` is empty or `netloc` is empty → raise `ValueError` (AC-06).

### 4.5 `_generate_code()` — Implements: REQ-01

1. Use `secrets.choice()` over `string.ascii_letters + string.digits` (62 chars).
2. Generate 6 characters.
3. If code already in `_store`, regenerate (collision probability ~1/56 billion).

---

## 5. File layout

```
modules/HL01/LL01/
  src/
    __init__.py          # exports URLShortener
    shortener.py         # URLShortener class, URLEntry dataclass
  tests/
    unit/
      test_shortener.py  # unit tests — # Covers: AC-xx
    integration/
      test_shortener_integration.py  # integration tests
    fixtures/
      urls.json          # test URL data sets
    conftest.py          # shared fixtures
```

---

## 6. Dependencies

- Python 3.12+ standard library only (`urllib.parse`, `secrets`, `string`, `dataclasses`, `datetime`)
- No third-party packages for the implementation
- Test dependencies: `pytest`, `ruff`

---

## 7. Design decisions

| Decision | Rationale |
|----------|-----------|
| Single module (no service/repository split) | Only 3 public methods, in-memory store. Splitting would be over-engineering for this scope. |
| `secrets` over `random` | Cryptographically secure — avoids predictable codes. |
| `dataclass` for `URLEntry` | Clean, type-hinted data container. No ORM needed (no persistence). |
| `dict` for store | O(1) lookup, simple, no persistence requirement. |
| `ValueError` for input errors | Standard Python convention for invalid arguments. |
| `KeyError` for missing codes | Standard Python convention for missing mapping keys. Matches spec exactly. |
| UTC for `created_at` | Timezone-aware, deterministic. |

---

## 8. Traceability matrix

| AC | Module | Function | Verified by |
|----|--------|----------|-------------|
| AC-01 | shortener | `shorten()` + `_generate_code()` | Returns 6-char alphanumeric |
| AC-02 | shortener | `resolve()` | Returns original URL |
| AC-03 | shortener | `resolve()` | Increments click count |
| AC-04 | shortener | `stats()` | Returns dict with url, clicks, created_at |
| AC-05 | shortener | `shorten()` + `_validate_url()` | Raises ValueError on empty |
| AC-06 | shortener | `shorten()` + `_validate_url()` | Raises ValueError on no scheme |
| AC-07 | shortener | `resolve()` | Raises KeyError on nonexistent |
| AC-08 | shortener | `shorten(alias=...)` | Stores with custom code |
| AC-09 | shortener | `shorten(alias=...)` | Raises ValueError on collision |

**Coverage: 9/9 AC, 7/7 REQ — complete.**
