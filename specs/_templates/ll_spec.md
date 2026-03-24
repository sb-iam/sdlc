# HL{nn}_LL{nn}: [Subtask name]

## Parent
HL{nn}: [link to parent spec]

## Problem
<!-- What specific problem does this subtask solve? -->

## Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| REQ-01 | | Must |
| REQ-02 | | Must |

## Acceptance criteria

| ID | Criterion | Traces to |
|----|-----------|-----------|
| AC-01 | `function(input)` returns `expected` | REQ-01 |
| AC-02 | `function(bad)` raises `Error` | REQ-01 |

## Interfaces

```python
class ClassName:
    def method(self, param: type) -> return_type: ...
```

## Non-goals
-

---

## Traceability contract (for reviewers)

Every downstream artifact MUST satisfy ALL. Missing = P0.

- [ ] plan_*.md: Every REQ-xx has a section
- [ ] plan_*.md: Every AC-xx mapped to function
- [ ] test_*.md: Every AC-xx has a test case
- [ ] tests/: Every test has `# Covers: AC-xx`
- [ ] src/: Every REQ-xx implemented
- [ ] change.md: Updated

