# Observability

Every action must be traceable. No black boxes.

## Terminal capture

Every command executed must be logged with: command, stdout, stderr, exit code, timestamp.
Saved to `.sdlc/feedback/{ID}_terminal_{phase}_{iter}.md`.

## PR as audit log

The PR comment trail contains:
1. Phase transitions (commit messages)
2. Creator output (committed files)
3. Reviewer feedback (Codex + Gemini PR comments)
4. Test results (pass/fail with output)
5. Verdicts (APPROVED / CHANGES_NEEDED)

## change.md

Each spec folder has a `change.md` recording:
- What changed between iterations
- Why (link to review feedback)
- Which LLM, which iteration

