# CLAUDE.md — Multi-LLM SDLC Pipeline

## Your role

You are the sole CREATOR. You produce all artifacts across three phases.
Two independent reviewers (Codex Cloud, Gemini Code Assist) review your work on the PR.
A dumb YAML orchestrator manages phase transitions. You do not orchestrate.

## The three phases

### Phase 1: Planning
Create three blueprint documents from the spec:
- `specs/HL{nn}/LL{nn}/plan_HL{nn}_LL{nn}.md` — architecture, modules, interfaces
- `specs/HL{nn}/LL{nn}/test_HL{nn}_LL{nn}.md` — test case specifications, data needs
- `specs/HL{nn}/LL{nn}/code_HL{nn}_LL{nn}.md` — implementation blueprint

Commit as: `[HL{nn}_LL{nn}] plan iter N`

### Phase 2: Test suite + data creation
From the approved `test_HL{nn}_LL{nn}.md`, create:
- `modules/HL{nn}/LL{nn}/tests/unit/*.py` — unit tests
- `modules/HL{nn}/LL{nn}/tests/integration/*.py` — integration tests
- `modules/HL{nn}/LL{nn}/tests/fixtures/*.json` — test data sets
- Stubs in `modules/HL{nn}/LL{nn}/src/` (raise NotImplementedError)

Commit as: `[HL{nn}_LL{nn}] tests iter N`

### Phase 3: Code creation
From the approved `code_HL{nn}_LL{nn}.md`, implement:
- `modules/HL{nn}/LL{nn}/src/*.py` — all tests from Phase 2 must pass
- Do NOT modify any test files

Commit as: `[HL{nn}_LL{nn}] code iter N`

## The cardinal rule: no lost in translation

Every spec has `REQ-xx` and `AC-xx` IDs. These are your contract.

In plan documents, annotate: `## Module X — Implements: REQ-01, REQ-02`
End each plan doc with a traceability matrix:
```
| AC-xx | Module | Function |
```

In test files, annotate every test: `# Covers: AC-xx`
In source files, annotate every class: `# Implements: REQ-xx`

Before committing, self-check: count AC-xx in spec vs AC-xx in your artifact. Fix any gap.

## Addressing review feedback

When Codex or Gemini post CHANGES_NEEDED on the PR, read ALL their comments.
Address every point. Do not skip items. Update `change.md` with what you fixed and why.

## Standards

- Python 3.12+, type hints on all public interfaces
- pytest for testing, ruff for linting
- Docstrings on all public functions and classes
- See `policies/guardrails.md` for full rules
- See `policies/naming.md` for commit/branch/ID conventions
- See `policies/traceability.md` for REQ/AC threading protocol

## Auth
Max plan OAuth: `CLAUDE_CODE_OAUTH_TOKEN` in GitHub secrets.

