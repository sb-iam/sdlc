# Guardrails

Hard rules for ALL LLM operations. Referenced by CLAUDE.md, AGENTS.md, .gemini/.

## Must do

- Read the spec before any work
- Run tests after code changes: `python -m pytest`
- Run linting: `ruff check`
- Include `# Covers: AC-xx` on every test function
- Include `# Implements: REQ-xx` on every class/module
- Commit with `[HL{nn}_LL{nn}] phase iter N` prefix
- Address ALL points from review feedback
- End reviews with `VERDICT: APPROVED` or `VERDICT: CHANGES_NEEDED`

## Must not do

- Modify test files during code creation phase
- Skip phases or jump ahead
- Approve work with missing AC-xx coverage
- Use bare `except:` without specific exception
- Use `eval()`, `exec()`, or `pickle.loads()` on untrusted data
- Push directly to main — all work through PRs
- Delete prior feedback files

## Security

- No secrets, credentials, or API keys in code
- Validate all external inputs
- Use context managers for file I/O
- No hardcoded URLs to external services

