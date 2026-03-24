# Traceability — no lost in translation

## The mechanism: REQ/AC IDs as threads

Every spec has:
- `REQ-xx` — requirements (what the system must do)
- `AC-xx` — acceptance criteria (how we verify it)

These IDs flow through every artifact:

```
spec.md       ->  REQ-01, AC-01 defined
plan_*.md     ->  "AC-01 -> URLShortener.shorten()"
test_*.md     ->  "test_shorten_valid_url covers AC-01"
tests/*.py    ->  def test_shorten():  # Covers: AC-01
src/*.py      ->  class URLShortener:  # Implements: REQ-01
```

## Reviewer protocol

Both reviewers build a traceability matrix:

```
AC-01: COVERED — location in artifact
AC-02: COVERED — location in artifact
AC-03: MISSING — not addressed

Coverage: 8/9
VERDICT: CHANGES_NEEDED
```

ANY missing AC = P0 blocking. The matrix is the primary review output.

## Creator protocol

Before committing:
1. Count AC-xx in spec
2. Count AC-xx references in artifact
3. If counts differ, fix the gap

