# Code Blueprint: HL01_LL01 — Core shortening and resolution logic

## 1. Overview

Implementation blueprint for `modules/HL01/LL01/src/shortener.py`.
This document specifies the exact code structure, algorithms, and
error handling that Phase 3 must produce.

**Constraint:** All tests from Phase 2 must pass. No test files may be modified.

---

## 2. Files to create

| File | Purpose | Implements |
|------|---------|------------|
| `modules/HL01/LL01/src/__init__.py` | Package init, exports `URLShortener` | — |
| `modules/HL01/LL01/src/shortener.py` | Core implementation | REQ-01 through REQ-07 |

---

## 3. `shortener.py` — Full blueprint

### 3.1 Imports

```python
from __future__ import annotations

import secrets
import string
from dataclasses import dataclass, field
from datetime import datetime, timezone
from urllib.parse import urlparse
```

### 3.2 Constants

```python
CODE_LENGTH: int = 6
CODE_ALPHABET: str = string.ascii_letters + string.digits  # 62 chars
MAX_RETRIES: int = 10  # collision retry limit (theoretical safety net)
```

### 3.3 `URLEntry` dataclass

```python
@dataclass
class URLEntry:
    """Internal storage record for a shortened URL."""

    url: str
    clicks: int = 0
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
```

### 3.4 `URLShortener` class — Implements: REQ-01, REQ-02, REQ-03, REQ-04, REQ-05, REQ-06, REQ-07

```python
class URLShortener:
    """In-memory URL shortener engine.

    Implements: REQ-01, REQ-02, REQ-03, REQ-04, REQ-05, REQ-06, REQ-07
    """

    def __init__(self) -> None:
        self._store: dict[str, URLEntry] = {}
```

### 3.5 `shorten()` — Implements: REQ-01, REQ-04, REQ-06, REQ-07

```
Algorithm:
1. _validate_url(url)                     → ValueError if invalid (REQ-04)
2. if alias provided:
   a. if alias in _store → ValueError     (REQ-07, AC-09)
   b. code = alias                        (REQ-06, AC-08)
3. else:
   a. code = _generate_code()             (REQ-01, AC-01)
4. _store[code] = URLEntry(url=url)
5. return code

Return type: str
Raises: ValueError
```

### 3.6 `resolve()` — Implements: REQ-02, REQ-03, REQ-05

```
Algorithm:
1. if code not in _store → KeyError       (REQ-05, AC-07)
2. _store[code].clicks += 1               (REQ-03, AC-03)
3. return _store[code].url                (REQ-02, AC-02)

Return type: str
Raises: KeyError
```

### 3.7 `stats()` — Implements: REQ-03

```
Algorithm:
1. if code not in _store → KeyError
2. entry = _store[code]
3. return {
       "url": entry.url,                  (AC-04)
       "clicks": entry.clicks,            (AC-04)
       "created_at": entry.created_at     (AC-04)
   }

Return type: dict
Raises: KeyError
```

### 3.8 `_validate_url()` — Implements: REQ-04

```
Algorithm:
1. if not url (empty string) → ValueError              (AC-05)
2. parsed = urlparse(url)
3. if not parsed.scheme or not parsed.netloc → ValueError  (AC-06)

Raises: ValueError
```

### 3.9 `_generate_code()` — Implements: REQ-01

```
Algorithm:
1. for _ in range(MAX_RETRIES):
   a. code = ''.join(secrets.choice(CODE_ALPHABET) for _ in range(CODE_LENGTH))
   b. if code not in _store → return code
2. raise ValueError("code generation exhausted — no unique code found")

Return type: str
Raises: ValueError (propagates through shorten(); should never happen in practice with 62^6 space)
```

---

## 4. `__init__.py`

```python
"""HL01_LL01: Core shortening and resolution logic."""

from .shortener import URLShortener

__all__ = ["URLShortener"]
```

---

## 5. Error handling summary

| Condition | Exception | AC |
|-----------|-----------|-----|
| Empty URL | `ValueError` | AC-05 |
| URL without scheme/netloc | `ValueError` | AC-06 |
| Non-existent code (resolve) | `KeyError` | AC-07 |
| Non-existent code (stats) | `KeyError` | AC-07 |
| Alias collision | `ValueError` | AC-09 |
| Code generation exhaustion | `ValueError` | — (safety net, propagates through shorten()) |

---

## 6. Type hints contract

All public methods have full type hints as specified in `plan_HL01_LL01.md`:

```python
def shorten(self, url: str, alias: str | None = None) -> str: ...
def resolve(self, code: str) -> str: ...
def stats(self, code: str) -> dict: ...
```

Private methods:

```python
def _validate_url(self, url: str) -> None: ...
def _generate_code(self) -> str: ...
```

---

## 7. Implementation notes

- **No third-party deps:** stdlib only (`secrets`, `string`, `urllib.parse`, `dataclasses`, `datetime`).
- **`secrets` over `random`:** Cryptographically secure, non-predictable codes.
- **UTC timestamps:** `datetime.now(timezone.utc)` for deterministic, timezone-aware `created_at`.
- **No persistence:** `_store` lives in memory. Instance goes away, data goes away. Per non-goals.
- **Code length:** Hardcoded at 6. No configurability needed per spec.

---

## 8. Traceability matrix

| AC | Function | Behavior |
|----|----------|----------|
| AC-01 | `shorten()` + `_generate_code()` | Returns 6-char alphanumeric code |
| AC-02 | `resolve()` | Returns original URL |
| AC-03 | `resolve()` | Increments `clicks` on each call |
| AC-04 | `stats()` | Returns dict with `url`, `clicks`, `created_at` |
| AC-05 | `shorten()` → `_validate_url()` | Raises `ValueError` on empty string |
| AC-06 | `shorten()` → `_validate_url()` | Raises `ValueError` on missing scheme/netloc |
| AC-07 | `resolve()` | Raises `KeyError` on nonexistent code |
| AC-08 | `shorten(alias=...)` | Stores and returns the custom alias |
| AC-09 | `shorten(alias=...)` | Raises `ValueError` on alias collision |

**Coverage: 9/9 AC, 7/7 REQ — complete.**
