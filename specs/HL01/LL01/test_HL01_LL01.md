# Test Specification: HL01_LL01 — Core shortening and resolution logic

## 1. Overview

Test plan for the `URLShortener` class defined in `plan_HL01_LL01.md`.
All tests target `modules/HL01/LL01/src/shortener.py`.

**Strategy:** Unit tests cover each AC individually. Integration tests cover
multi-step workflows (shorten → resolve → stats). Fixtures provide reusable URL data sets.

---

## 2. Unit tests

File: `modules/HL01/LL01/tests/unit/test_shortener.py`

### 2.1 Code generation — Covers: AC-01

| Test | Input | Expected | AC |
|------|-------|----------|-----|
| `test_shorten_returns_6_char_code` | `shorten("https://example.com")` | Returns `str` of length 6 | AC-01 |
| `test_shorten_code_is_alphanumeric` | `shorten("https://example.com")` | All chars in `[a-zA-Z0-9]` | AC-01 |
| `test_shorten_different_urls_different_codes` | Two different URLs | Different codes returned | AC-01 |

### 2.2 Resolution — Covers: AC-02

| Test | Input | Expected | AC |
|------|-------|----------|-----|
| `test_resolve_returns_original_url` | `shorten(url)` then `resolve(code)` | Returns the original URL | AC-02 |
| `test_resolve_multiple_urls` | Shorten 3 URLs, resolve each | Each returns its original URL | AC-02 |

### 2.3 Click tracking — Covers: AC-03

| Test | Input | Expected | AC |
|------|-------|----------|-----|
| `test_resolve_increments_click_count` | `resolve(code)` called 3 times | `stats(code)["clicks"] == 3` | AC-03 |
| `test_click_count_starts_at_zero` | `shorten(url)` then `stats(code)` | `clicks == 0` | AC-03 |

### 2.4 Stats — Covers: AC-04

| Test | Input | Expected | AC |
|------|-------|----------|-----|
| `test_stats_returns_required_keys` | `stats(code)` | Dict contains `"url"`, `"clicks"`, `"created_at"` | AC-04 |
| `test_stats_url_matches_original` | `shorten(url)` then `stats(code)` | `stats["url"] == url` | AC-04 |
| `test_stats_created_at_is_datetime` | `stats(code)` | `created_at` is a `datetime` instance | AC-04 |

### 2.5 Invalid URL rejection — Covers: AC-05, AC-06

| Test | Input | Expected | AC |
|------|-------|----------|-----|
| `test_shorten_empty_string_raises_valueerror` | `shorten("")` | Raises `ValueError` | AC-05 |
| `test_shorten_no_scheme_raises_valueerror` | `shorten("not-a-url")` | Raises `ValueError` | AC-06 |
| `test_shorten_missing_netloc_raises_valueerror` | `shorten("http://")` | Raises `ValueError` | AC-06 |

### 2.6 Non-existent code rejection — Covers: AC-07

| Test | Input | Expected | AC |
|------|-------|----------|-----|
| `test_resolve_nonexistent_raises_keyerror` | `resolve("nonexistent")` | Raises `KeyError` | AC-07 |
| `test_stats_nonexistent_raises_keyerror` | `stats("nonexistent")` | Raises `KeyError` | AC-07 |

### 2.7 Custom aliases — Covers: AC-08

| Test | Input | Expected | AC |
|------|-------|----------|-----|
| `test_shorten_with_alias` | `shorten(url, alias="myalias")` | Returns `"myalias"` | AC-08 |
| `test_resolve_custom_alias` | Shorten with alias, then resolve | Returns original URL | AC-08 |

### 2.8 Alias collision — Covers: AC-09

| Test | Input | Expected | AC |
|------|-------|----------|-----|
| `test_shorten_alias_collision_raises_valueerror` | Same alias for two URLs | Raises `ValueError` on second call | AC-09 |

---

## 3. Integration tests

File: `modules/HL01/LL01/tests/integration/test_shortener_integration.py`

### 3.1 Full lifecycle — Covers: AC-01, AC-02, AC-03, AC-04

| Test | Scenario | AC |
|------|----------|-----|
| `test_full_lifecycle_shorten_resolve_stats` | Shorten URL → resolve 5 times → verify stats shows 5 clicks, correct URL, valid created_at | AC-01, AC-02, AC-03, AC-04 |

### 3.2 Mixed aliases and generated codes — Covers: AC-01, AC-08

| Test | Scenario | AC |
|------|----------|-----|
| `test_mixed_alias_and_generated` | Shorten one URL with alias, another without → resolve both → verify both return correct URLs | AC-01, AC-02, AC-08 |

### 3.3 Error paths interleaved — Covers: AC-05, AC-06, AC-07, AC-09

| Test | Scenario | AC |
|------|----------|-----|
| `test_error_paths_do_not_corrupt_state` | Shorten valid URL → attempt invalid shorten (verify ValueError) → resolve original (still works) → attempt resolve of nonexistent code (verify KeyError, AC-07) → attempt alias collision (verify ValueError) → resolve original (still works) | AC-05, AC-06, AC-07, AC-09 |

### 3.4 Bulk operations — Covers: AC-01, AC-02

| Test | Scenario | AC |
|------|----------|-----|
| `test_bulk_shorten_and_resolve` | Shorten 100 URLs from fixture data → resolve all → verify all match | AC-01, AC-02 |

---

## 4. Test fixtures

File: `modules/HL01/LL01/tests/fixtures/urls.json`

```json
{
  "valid_urls": [
    "https://example.com",
    "https://example.com/path/to/page",
    "https://subdomain.example.com",
    "http://example.com",
    "https://example.com/path?query=value&other=123",
    "https://example.com/path#fragment"
  ],
  "invalid_urls": [
    "",
    "not-a-url",
    "ftp-missing-slashes",
    "://no-scheme.com",
    "http://"
  ],
  "bulk_urls": [
    "https://example.com/page/1",
    "https://example.com/page/2",
    "https://example.com/page/3"
  ]
}
```

Note: `bulk_urls` will be expanded to 100 entries in the actual fixture file for the
bulk integration test.

---

## 5. Shared fixtures (conftest.py)

File: `modules/HL01/LL01/tests/conftest.py`

| Fixture | Scope | Provides |
|---------|-------|----------|
| `shortener` | `function` | Fresh `URLShortener()` instance per test |
| `url_data` | `session` | Parsed `urls.json` fixture data |

---

## 6. Test data needs

| Data | Source | Notes |
|------|--------|-------|
| Valid URLs (6+) | `urls.json` | Various schemes, paths, queries |
| Invalid URLs (5+) | `urls.json` | Empty, schemeless, netloc-less |
| Bulk URLs (100) | `urls.json` | For stress/uniqueness testing |
| Custom aliases | Inline in tests | `"myalias"`, `"custom"`, etc. |

---

## 7. Traceability matrix

| AC | Unit test(s) | Integration test(s) |
|----|-------------|-------------------|
| AC-01 | `test_shorten_returns_6_char_code`, `test_shorten_code_is_alphanumeric`, `test_shorten_different_urls_different_codes` | `test_full_lifecycle_shorten_resolve_stats`, `test_mixed_alias_and_generated`, `test_bulk_shorten_and_resolve` |
| AC-02 | `test_resolve_returns_original_url`, `test_resolve_multiple_urls` | `test_full_lifecycle_shorten_resolve_stats`, `test_mixed_alias_and_generated`, `test_bulk_shorten_and_resolve` |
| AC-03 | `test_resolve_increments_click_count`, `test_click_count_starts_at_zero` | `test_full_lifecycle_shorten_resolve_stats` |
| AC-04 | `test_stats_returns_required_keys`, `test_stats_url_matches_original`, `test_stats_created_at_is_datetime` | `test_full_lifecycle_shorten_resolve_stats` |
| AC-05 | `test_shorten_empty_string_raises_valueerror` | `test_error_paths_do_not_corrupt_state` |
| AC-06 | `test_shorten_no_scheme_raises_valueerror`, `test_shorten_missing_netloc_raises_valueerror` | `test_error_paths_do_not_corrupt_state` |
| AC-07 | `test_resolve_nonexistent_raises_keyerror`, `test_stats_nonexistent_raises_keyerror` | `test_error_paths_do_not_corrupt_state` |
| AC-08 | `test_shorten_with_alias`, `test_resolve_custom_alias` | `test_mixed_alias_and_generated` |
| AC-09 | `test_shorten_alias_collision_raises_valueerror` | `test_error_paths_do_not_corrupt_state` |

**Coverage: 9/9 AC — complete.**
