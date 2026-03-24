# Review standards

## P0 — blocking
- ANY AC-xx missing from the artifact
- Logic errors causing incorrect behavior
- Security vulnerabilities
- Type mismatches between interfaces
- Tests that don't test what they claim
- TDD violation: tests modified during code phase

## P1 — important
- Missing type hints on public functions
- Missing or misleading docstrings
- Dead code or unreachable branches
- DRY violations (3+ duplications)
- Performance: O(n^2) where O(n) is obvious
- Naming convention violations

## Not flagged
- Style preferences (quotes, spacing)
- Import ordering (ruff handles this)
- Alternative approaches that aren't clearly better

## Verdict format

Every review ends with exactly one of:
```
VERDICT: APPROVED
VERDICT: CHANGES_NEEDED
```

## Issue format

```
**P0** | `file:line` | Brief title
Description. Spec requires: "...". Fix: ...
```

