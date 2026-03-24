# AGENTS.md — HL01_LL01: Core shortening logic

## Traceability reference

Spec: `specs/HL01/LL01/spec.md`
Requirements: REQ-01 through REQ-07
Acceptance criteria: AC-01 through AC-09

## Review checklist

| AC | Expected test | Expected implementation |
|----|--------------|----------------------|
| AC-01 | `# Covers: AC-01` | URLShortener.shorten() returns 6-char |
| AC-02 | `# Covers: AC-02` | URLShortener.resolve() returns URL |
| AC-03 | `# Covers: AC-03` | resolve() increments clicks |
| AC-04 | `# Covers: AC-04` | stats() returns dict |
| AC-05 | `# Covers: AC-05` | shorten("") raises ValueError |
| AC-06 | `# Covers: AC-06` | shorten("bad") raises ValueError |
| AC-07 | `# Covers: AC-07` | resolve("x") raises KeyError |
| AC-08 | `# Covers: AC-08` | shorten(url, alias="x") works |
| AC-09 | `# Covers: AC-09` | shorten(url2, alias="x") raises |

Any row without both test AND implementation = P0.

