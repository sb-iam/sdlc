# HL01_LL01: Change log

## v3 — Phase 1: Planning (iter 3) — Codex feedback
- Fixed _generate_code() algorithm: removed arbitrary MAX_RETRIES cap, now loops until unique code found; only raises ValueError when entire code space (~56.8B) is truly exhausted
- Ensures REQ-01 (must generate unique code for any valid URL) is guaranteed, not probabilistic
- Addressed 1 Codex P1 comment from iter 2 re-review

## v2 — Phase 1: Planning (iter 2) — Codex feedback
- Fixed AC-07 gap: added nonexistent code lookup step to `test_error_paths_do_not_corrupt_state` integration test scenario
- Fixed exception contract inconsistency: changed `_generate_code()` exhaustion from `RuntimeError` to `ValueError` so `shorten()` contract stays internally consistent across plan and code blueprint
- Fixed changelog accuracy: clarified that test spec traces ACs (not REQs directly); REQs are traced in plan and code blueprint
- Addressed all 3 Codex review comments (2x P1, 1x P2)

## v1 — Phase 1: Planning (iter 1)
- Created `plan_HL01_LL01.md`: single-module architecture (URLShortener + URLEntry dataclass), in-memory dict store, secrets-based code generation
- Created `test_HL01_LL01.md`: 18 unit tests across 8 groups + 4 integration tests, all 9 ACs covered
- Created `code_HL01_LL01.md`: full implementation blueprint with algorithms, error handling, type contracts
- Traceability verified: 9/9 AC traced in all three documents; 7/7 REQ traced in plan and code blueprint (test spec traces ACs which map to REQs via spec)
- Round 1 adaptation: Codex-only review (no Gemini), manual orchestration

## v0 — Initial spec
- Created from product vision HL01
- 7 requirements (REQ-01 through REQ-07)
- 9 acceptance criteria (AC-01 through AC-09)
- Scoped to core shortening logic only (no CLI, no HTTP)

