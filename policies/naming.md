# Naming convention

## ID format: `HL{nn}_LL{nn}`

- `HL{nn}` — High-level product spec (01-99)
- `LL{nn}` — Low-level subtask (01-99)

## Where the ID appears

| Context | Format | Example |
|---------|--------|---------|
| Branch | `sdlc/HL{nn}_LL{nn}` | `sdlc/HL01_LL01` |
| PR title | `[HL{nn}_LL{nn}] description` | `[HL01_LL01] core shortening logic` |
| Commit | `[HL{nn}_LL{nn}] phase iter N` | `[HL01_LL01] plan iter 2` |
| Spec folder | `specs/HL{nn}/LL{nn}/` | `specs/HL01/LL01/spec.md` |
| Module folder | `modules/HL{nn}/LL{nn}/` | `modules/HL01/LL01/src/` |
| Plan docs | `plan_HL{nn}_LL{nn}.md` | `plan_HL01_LL01.md` |
| Test spec | `test_HL{nn}_LL{nn}.md` | `test_HL01_LL01.md` |
| Code spec | `code_HL{nn}_LL{nn}.md` | `code_HL01_LL01.md` |

## Phase names in commits

| Phase | Prefix |
|-------|--------|
| Planning | `[HL01_LL01] plan iter N` |
| Test creation | `[HL01_LL01] tests iter N` |
| Code creation | `[HL01_LL01] code iter N` |

## To find everything about a feature

Search PRs by `[HL01_LL01]`. One result. Full story.

