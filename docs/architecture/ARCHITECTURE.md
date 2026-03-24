# Multi-LLM SDLC — Architecture and Decision Record

> Three frontier models from three companies, negotiating software through pull requests, coordinated by a dumb YAML state machine. Zero API keys. Zero trust.

> **Diagrams:** See [docs/architecture/diagrams.md](diagrams.md) for all 6 Mermaid diagrams (render natively on GitHub).


---

## 1. Executive summary

This document captures the complete architectural design and decision history for a multi-LLM software development lifecycle (SDLC) pipeline. The system uses three frontier AI models — Claude (Anthropic), Codex (OpenAI), and Gemini (Google) — to autonomously plan, test, and implement software from markdown specifications.

The human writes a spec. Three AIs do the rest. The human merges.

Key properties:
- One creator (Claude Code), two independent reviewers (Codex Cloud, Gemini Code Assist)
- Zero API keys — all three run on personal subscription plans
- Zero trust — no LLM orchestrates; a dumb GitHub Actions YAML counts votes
- One PR per feature — the PR comment trail IS the audit log
- REQ/AC IDs thread through every artifact to prevent "lost in translation"
- Three phases per feature: Planning, Test Creation, Code Creation

---

## 2. The thesis

We are in the age of program synthesis. The feedback loop from ideation to execution has collapsed. The SDLC is no longer human-types-code then machine-runs-code. It is:

**Human writes spec -> machines negotiate plan -> machines write tests -> machines write code -> machines review each other -> human merges**

Markdown is the source code. PRs are the communication protocol. Specs are the new `.hpp` files. The orchestrator is a shell script that cannot think.

---

## 3. System architecture

### 3.1 The four actors

| Actor | Tool | Role | Trust level |
|-------|------|------|-------------|
| Claude Code Action | `anthropics/claude-code-action@v1` | Creator — produces all artifacts | Untrusted (reviewed by two others) |
| Codex Cloud | `@codex review` auto-review | Reviewer 1 — independent review | Untrusted (cannot modify code) |
| Gemini Code Assist | `gemini-code-assist[bot]` auto-review | Reviewer 2 — independent review | Untrusted (cannot modify code) |
| GitHub Actions | Dumb YAML workflow | Orchestrator — counts approvals | Not an AI. Just `if/else`. |

### 3.2 Zero-trust principles

1. **No LLM is privileged.** Claude creates. Codex reviews. Gemini reviews. None decide what happens next.
2. **No LLM reads another LLM's output directly.** They all read the same specs, the same code, the same PR diff — independently.
3. **Each model has its OWN context file.** Claude reads `CLAUDE.md`. Codex reads `AGENTS.md`. Gemini reads `.gemini/styleguide.md`. They share `policies/` and `specs/` but their review instructions are independent.
4. **The orchestrator has no opinion.** It counts: "Did both reviewers approve? Yes -> next phase. No -> Claude re-creates. 3 loops -> escalate to human."
5. **Disagreement escalates to human.** If Codex says APPROVED and Gemini says CHANGES_NEEDED, the human resolves it. No LLM overrules another.

### 3.3 The pipeline: three phases, one PR

```
Human pushes specs/HL01/LL01/spec.md
    |
    v
PR opened: [HL01_LL01] core shortening logic
    |
    |--- Phase 1: PLANNING
    |    Claude creates: plan_HL01_LL01.md, test_HL01_LL01.md, code_HL01_LL01.md
    |    Commit: [HL01_LL01] plan iter 1
    |    Codex auto-reviews (PR comment)
    |    Gemini auto-reviews (PR comment)
    |    YAML: both approved? -> Phase 2. Else Claude revises. Max 3 loops.
    |
    |--- Phase 2: TEST SUITE + DATA CREATION
    |    Claude creates: tests/unit/*.py, tests/integration/*.py, tests/fixtures/*.json
    |    Commit: [HL01_LL01] tests iter 1
    |    Codex auto-reviews (PR comment)
    |    Gemini auto-reviews (PR comment)
    |    YAML: both approved? -> Phase 3. Else Claude revises. Max 3 loops.
    |
    |--- Phase 3: CODE CREATION
    |    Claude creates: src/*.py — all tests must pass
    |    Commit: [HL01_LL01] code iter 1
    |    Codex auto-reviews (PR comment)
    |    Gemini auto-reviews (PR comment)
    |    YAML: both approved? -> Done. Else Claude revises. Max 3 loops.
    |
    v
Human reviews full comment trail -> Merge
```

---

## 4. Authentication — zero API keys

### 4.1 Decision: subscriptions only, no per-token billing

Every tool runs on a personal subscription plan. No API keys are generated, no per-token charges accrue, no separate bills appear.

| Tool | Auth mechanism | Lifetime | Extra cost |
|------|---------------|----------|-----------|
| Claude Code | `claude setup-token` -> `CLAUDE_CODE_OAUTH_TOKEN` in GH secrets | ~1 year | $0 beyond Anthropic Max |
| Codex Cloud | GitHub app linked to ChatGPT account, auto-review enabled | Permanent (account-linked) | $0 beyond ChatGPT Max |
| Gemini Code Assist | GitHub app installed from marketplace, free consumer plan | Permanent (app-linked) | $0 (free, Pro elevates limits) |
| Orchestrator | `GITHUB_TOKEN` (built-in to Actions) | Per-workflow | $0 (free tier minutes) |

### 4.2 Why not API keys

**Gemini API key catch:** A `GEMINI_API_KEY` from AI Studio is a completely separate product from the Google AI Pro subscription. Using it creates a separate per-token bill. The Pro subscription gives you Gemini CLI and Code Assist limits — the API key gives you a different quota on a different billing account. We avoid this entirely by using Gemini Code Assist (the GitHub app), which is free and elevated by Pro.

**Codex API key catch:** `OPENAI_API_KEY` for the `openai/codex-action` GitHub Action is billed separately from your ChatGPT Max subscription. Codex Cloud (`@codex` on PRs) uses your Max plan directly. We use Cloud, not the Action.

### 4.3 One-time setup (lasts months)

```bash
# Claude — ~1 year token
claude setup-token
gh secret set CLAUDE_CODE_OAUTH_TOKEN   # paste token

# Codex — permanent
# chatgpt.com/codex/settings/code-review -> enable auto-review

# Gemini — permanent
# github.com/apps/gemini-code-assist -> install on repo

# Done. Never touch again for months.
```

---

## 5. Naming convention

Everything is addressed by a hierarchical ID that connects specs to PRs to code.

### 5.1 ID format

```
HL{nn}_LL{nn}
```

- `HL{nn}` — High-level product spec (01-99)
- `LL{nn}` — Low-level subtask within that HL (01-99)

### 5.2 Where the ID appears

| Context | Format | Example |
|---------|--------|---------|
| Branch | `sdlc/HL{nn}_LL{nn}` | `sdlc/HL01_LL01` |
| PR title | `[HL{nn}_LL{nn}] description` | `[HL01_LL01] core shortening logic` |
| Commit prefix | `[HL{nn}_LL{nn}] phase iter N` | `[HL01_LL01] plan iter 2` |
| Spec folder | `specs/HL{nn}/LL{nn}/` | `specs/HL01/LL01/spec.md` |
| Module folder | `modules/HL{nn}/LL{nn}/` | `modules/HL01/LL01/src/` |

### 5.3 Phase names in commits

| Phase | Commit prefix |
|-------|--------------|
| Planning | `[HL01_LL01] plan iter N` |
| Test creation | `[HL01_LL01] tests iter N` |
| Code creation | `[HL01_LL01] code iter N` |

---

## 6. Traceability — no lost in translation

### 6.1 The problem

When Claude creates a plan and Codex reviews it, information gets dropped at every handoff boundary. A spec with 9 acceptance criteria becomes a plan covering 8. That plan becomes tests covering 7. The code implements 6. By the end, 3 requirements are silently missing.

### 6.2 The solution: REQ/AC IDs as threads

Every spec requirement gets a stable ID. That ID must appear in every downstream artifact. If it's missing at any level, it's a P0 blocking issue.

```
spec.md:       REQ-01 defined, AC-01 defined
    |
plan.md:       "AC-01 -> URLShortener.shorten()"
    |
test.md:       "test_shorten_valid_url covers AC-01"
    |
tests/*.py:    def test_shorten_valid_url():  # Covers: AC-01
    |
src/*.py:      class URLShortener:  # Implements: REQ-01
```

### 6.3 The reviewer's primary job

Both Codex and Gemini build a traceability matrix for every review:

```
AC-01: COVERED — plan section 2.1 -> shorten()
AC-02: COVERED — plan section 2.2 -> resolve()
AC-03: MISSING — no mention of click tracking
...
Coverage: 8/9 AC covered
VERDICT: CHANGES_NEEDED
```

This matrix is the review's primary output. Style, architecture opinions, naming preferences — all secondary to "is every AC-xx present?"

### 6.4 The self-check

Before committing, Claude counts AC-xx IDs in the spec and AC-xx references in the artifact. If counts differ, it fixes the gap before pushing.

---

## 7. Folder structure

```
specs/                           <- The "include/" folder — source of truth
  _templates/
    hl_spec.md                   <- Template for high-level specs
    ll_spec.md                   <- Template for low-level subtask specs
  HL01/
    spec.md                      <- High-level product spec
    LL01/
      spec.md                    <- Subtask spec with REQ/AC tables
      plan_HL01_LL01.md          <- Architecture plan (generated, reviewed)
      test_HL01_LL01.md          <- Test case specification (generated, reviewed)
      code_HL01_LL01.md          <- Code blueprint (generated, reviewed)
      change.md                  <- Evolution log

modules/                         <- Generated code, mirrors specs/
  HL01/
    LL01/
      src/                       <- Implementation
      tests/
        unit/                    <- Unit tests
        integration/             <- Integration tests
        fixtures/                <- Test data sets
      AGENTS.md                  <- Per-module Codex review context

policies/                        <- Shared rules (all models read these)
  naming.md                      <- ID format, commit prefixes
  guardrails.md                  <- What LLMs must/must not do
  traceability.md                <- REQ/AC threading rules
  observability.md               <- Terminal capture, logging
  review_standards.md            <- P0/P1 severity definitions

.github/workflows/
  orchestrator.yml               <- Dumb YAML state machine

.gemini/
  styleguide.md                  <- Gemini Code Assist review config

CLAUDE.md                        <- Claude Code context (creator role)
AGENTS.md                        <- Codex Cloud context (reviewer role)
```

---

## 8. Context files — independent instructions per model

### 8.1 Claude reads: `CLAUDE.md`

Role: creator. Instructions for producing plan, test, and code artifacts. Emphasis on REQ/AC threading, self-check before commit, correct file paths.

### 8.2 Codex reads: `AGENTS.md` (root + nested per module)

Role: reviewer. Instructions for building traceability matrices, P0/P1 severity, structured verdicts. Codex Cloud auto-discovers AGENTS.md files and applies the closest one to each changed file.

Quota: 33 PR reviews/day on the free consumer plan. Pro subscription elevates limits.

### 8.3 Gemini reads: `.gemini/styleguide.md`

Role: reviewer. Same traceability-first approach but independently configured. Gemini Code Assist reads `.gemini/` for custom review configuration.

Quota: 33 PR reviews/day on free plan. Pro subscription elevates limits.

### 8.4 All three read: `policies/`

The shared rules. Naming conventions, guardrails, traceability protocol, severity definitions. These are referenced by all three context files but none of the models get to modify them.

---

## 9. The review protocol

### 9.1 What makes an APPROVED verdict

Both reviewers must independently conclude:
- Every AC-xx from the spec appears in the artifact
- No P0 issues (logic errors, security, type mismatches)
- The artifact is consistent with prior approved artifacts

### 9.2 What makes a CHANGES_NEEDED verdict

Any of:
- One or more AC-xx missing (instant P0)
- Logic error, security issue, interface mismatch
- TDD violation (tests modified during code phase)

### 9.3 Consensus (dumb YAML)

```yaml
# The orchestrator checks review statuses
# This is literally just counting
CODEX_STATUS=$(gh pr reviews $PR --json state --jq '...')
GEMINI_STATUS=$(gh pr reviews $PR --json state --jq '...')
if both == "APPROVED"; then next_phase
elif loops < 3; then claude_revise
else escalate_to_human
```

No AI involved in the consensus decision.

---

## 10. Decision log

### Decision 1: Claude as sole creator

**Context:** Could alternate creators (Codex creates plan, Claude creates tests).
**Decision:** Claude creates everything. Codex and Gemini only review.
**Rationale:** Simpler orchestration. One creator means one context file for creation instructions. Review diversity comes from having two reviewers from different model families, not from alternating creators.

### Decision 2: Codex Cloud over Codex Action

**Context:** `openai/codex-action` runs on GH runners with `OPENAI_API_KEY`. Codex Cloud runs on OpenAI's servers with ChatGPT Max subscription.
**Decision:** Codex Cloud (`@codex review` / auto-review).
**Rationale:** Zero API key, zero extra cost, runs on OpenAI's compute not our GH minutes. The trade-off is less prompt control, but AGENTS.md provides sufficient review customization.

### Decision 3: Gemini Code Assist as third model

**Context:** Initially considered Gemini CLI in Docker as orchestrator. Discovered Gemini Code Assist — a GitHub app that auto-reviews PRs, same pattern as Codex Cloud.
**Decision:** Gemini Code Assist as independent second reviewer.
**Rationale:** Free consumer plan (33 reviews/day), Pro elevates limits, GitHub app install (permanent, no token expiry), reviews through `.gemini/` config. Same model as the reviewer, not as orchestrator — zero trust means no LLM gets control.

### Decision 4: Dumb YAML orchestrator

**Context:** Initially considered Gemini as intelligent orchestrator that reads state, makes decisions, dispatches Claude.
**Decision:** GitHub Actions YAML with no AI.
**Rationale:** Zero trust. If the orchestrator is an LLM, it becomes a privileged actor that can manipulate the pipeline. A YAML file that counts PR approvals cannot be prompt-injected, cannot collude with a reviewer, and cannot make subjective decisions. It is verifiably dumb.

### Decision 5: One PR per feature

**Context:** Initially designed as multiple PRs (one per phase).
**Decision:** Single PR with phases as commits, comments as audit trail.
**Rationale:** The PR IS the complete story. One PR title `[HL01_LL01] description` maps to one spec. The comment trail contains every review, every iteration. To audit a feature, you search one PR, not three. The commit history within the PR shows the three phases clearly.

### Decision 6: REQ/AC IDs for traceability

**Context:** Natural language requirements are lossy across LLM handoff boundaries.
**Decision:** Every requirement gets `REQ-xx`, every acceptance criterion gets `AC-xx`. These IDs must appear in every downstream artifact.
**Rationale:** IDs are machine-verifiable. Codex can grep for `AC-03` and see if it appears. No interpretation needed. The reviewer's primary job is building a traceability matrix, not giving opinions about code style.

### Decision 7: No API keys anywhere

**Context:** All three services offer API keys for programmatic access (Anthropic API, OpenAI API, Gemini API). All three also offer subscription-based access.
**Decision:** Subscriptions only.
**Rationale:**
- Claude: `setup-token` gives ~1 year OAuth token using Max plan
- Codex: GitHub app linked to ChatGPT Max, permanent
- Gemini: GitHub app install, free + Pro elevates
- API keys create separate billing accounts. Gemini API key is a completely different product from the Google AI Pro subscription. OpenAI API key is separate from ChatGPT Max. We avoid all of this.

### Decision 8: Three planning documents, not one

**Context:** Could create a single monolithic plan.
**Decision:** Three separate documents in Phase 1: `plan_*.md` (architecture), `test_*.md` (test specifications), `code_*.md` (implementation blueprint).
**Rationale:** Each document feeds a specific phase. The test spec feeds Phase 2 (test creation). The code blueprint feeds Phase 3 (code creation). Reviewing three focused documents is more effective than reviewing one large document. Each carries its own REQ/AC traceability matrix.

---

## 11. Cost analysis

| Service | Plan | Monthly cost (CAD) | What it gives the pipeline |
|---------|------|-------------------|--------------------------|
| Anthropic | Max | ~$270 | Claude Code Action via OAuth (creator) |
| OpenAI | ChatGPT Max | ~$270 | Codex Cloud auto-review (reviewer 1) |
| Google | AI Pro | $26.99 | Gemini Code Assist elevated limits (reviewer 2) |
| GitHub | Free | $0 | Actions minutes (2000/mo), PR infrastructure |
| **Total** | | **~$567** | **3 frontier models, zero API keys** |

Per-feature cost: $0 marginal (all subscription-based).

---

## 12. Risks and mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Claude hallucinates requirements | Missing AC in plan | Both reviewers check traceability matrix independently |
| Codex and Gemini both miss the same bug | Bug ships | Different model families have different blind spots; human final review |
| Review loop never converges | Infinite iterations | Hard cap at 3 loops, then escalate to human |
| OAuth token expires | Pipeline stops | Claude token lasts ~1 year; Codex/Gemini are permanent app installs |
| Rate limits hit | Pipeline slows | Pro subscriptions elevate all limits; pipeline runs max ~5/day |
| Prompt injection via spec | Malicious code generation | Reviewers from different vendors cross-check; policies/guardrails.md |

---

## 13. Future evolution

- **More HL/LL specs running in parallel** — each gets its own branch and PR
- **Human-in-the-loop during phases** — comment on PR mid-phase to steer Claude
- **Fourth reviewer** — Grok, DeepSeek, or another frontier model as additional reviewer
- **Cross-feature integration testing** — after multiple HL_LL features merge, run integration
- **Lattice integration** — connect to the Lattice edtech platform for collaborative spec writing

---

## 14. Appendix: PR anatomy

A completed PR for `[HL01_LL01]` looks like this:

**Title:** `[HL01_LL01] core shortening logic`
**Branch:** `sdlc/HL01_LL01`

**Commits (chronological):**
```
[HL01_LL01] plan iter 1
[HL01_LL01] plan iter 2
[HL01_LL01] tests iter 1
[HL01_LL01] code iter 1
[HL01_LL01] code iter 2
```

**Comments (chronological):**
```
#1  codex-cloud[bot]     Phase 1 review: AC-03 missing. CHANGES_NEEDED
#2  gemini-code-assist   Phase 1 review: AC-09 not addressed. CHANGES_NEEDED
#3  codex-cloud[bot]     Phase 1 re-review: 9/9 AC covered. APPROVED
#4  gemini-code-assist   Phase 1 re-review: APPROVED
#5  codex-cloud[bot]     Phase 2 review: APPROVED
#6  gemini-code-assist   Phase 2 review: APPROVED
#7  codex-cloud[bot]     Phase 3 review: tests green, 9/9 AC. APPROVED
#8  gemini-code-assist   Phase 3 review: APPROVED
#9  human                LGTM. Merging.
```

**Files changed:**
```
specs/HL01/LL01/plan_HL01_LL01.md
specs/HL01/LL01/test_HL01_LL01.md
specs/HL01/LL01/code_HL01_LL01.md
specs/HL01/LL01/change.md
modules/HL01/LL01/src/shortener.py
modules/HL01/LL01/src/__init__.py
modules/HL01/LL01/tests/unit/test_shortener.py
modules/HL01/LL01/tests/integration/test_shortener_integration.py
modules/HL01/LL01/tests/fixtures/urls.json
modules/HL01/LL01/tests/conftest.py
```

---

## 15. Appendix: Quick-start checklist

```bash
# 1. Clone template
gh repo create my-project --template sb-iam/multi-llm-sdlc

# 2. Auth (one-time, lasts months)
claude setup-token
gh secret set CLAUDE_CODE_OAUTH_TOKEN

# 3. Install GitHub apps
# github.com/apps/claude -> install
# chatgpt.com/codex/settings/code-review -> enable auto-review
# github.com/apps/gemini-code-assist -> install

# 4. Write a spec
cp specs/_templates/ll_spec.md specs/HL01/LL01/spec.md
vim specs/HL01/LL01/spec.md

# 5. Push and walk away
git add specs/HL01/LL01/spec.md
git commit -m "[HL01_LL01] spec: core shortening logic"
git push

# 6. Watch
gh run watch
# Come back to a PR with full plan, tests, code, reviewed by two AIs.
```

