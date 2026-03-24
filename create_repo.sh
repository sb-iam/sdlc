#!/usr/bin/env bash
# ============================================================================
# Multi-LLM SDLC — Template Generator for github.com/sb-iam/sdlc
# ============================================================================
# This script populates the existing sb-iam/sdlc repo with all template files.
# Run from inside the cloned repo, or provide the path.
#
# Usage:
#   cd ~/repos/sdlc && bash create_repo.sh
#   bash create_repo.sh ~/repos/sdlc
# ============================================================================

set -euo pipefail

TARGET="${1:-.}"
cd "$TARGET"

# Safety check
if [ ! -d ".git" ]; then
  echo "ERROR: Not a git repo. Clone first:"
  echo "  git clone https://github.com/sb-iam/sdlc.git"
  exit 1
fi

echo "Populating sb-iam/sdlc in $(pwd)..."
echo ""

# ── Directory structure ──────────────────────────────────────────────────────
mkdir -p \
  .github/workflows \
  .sdlc/state .sdlc/feedback .sdlc/prompts \
  .gemini \
  docs/architecture docs/decisions \
  policies \
  specs/HL01/LL01 specs/_templates \
  modules/HL01/LL01/src \
  modules/HL01/LL01/tests/unit \
  modules/HL01/LL01/tests/integration \
  modules/HL01/LL01/tests/fixtures

touch .sdlc/state/.gitkeep .sdlc/feedback/.gitkeep \
  modules/HL01/LL01/src/.gitkeep \
  modules/HL01/LL01/tests/unit/.gitkeep \
  modules/HL01/LL01/tests/integration/.gitkeep \
  modules/HL01/LL01/tests/fixtures/.gitkeep


# ── .gemini/styleguide.md
cat > ".gemini/styleguide.md" << 'FILEEOF'
# Gemini Code Assist — Review configuration

## Your role

You are REVIEWER 2 (Gemini Code Assist). You review artifacts that Claude creates.
Codex Cloud is the independent REVIEWER 1. You do not coordinate with Codex.
You bring a different model family's perspective — that is your value.

## The cardinal rule: traceability matrix first

Before anything else, build the traceability matrix.

1. Read `specs/HL{nn}/LL{nn}/spec.md` — list every `AC-xx`
2. For each `AC-xx`, verify it appears in the artifact under review
3. ANY missing `AC-xx` = Critical severity. Report it.

## Severity levels

Critical: Missing AC-xx, logic errors, security issues, TDD violations
High: Missing type hints, interface mismatches, dead code
Medium: DRY violations, performance issues, naming inconsistencies
Low: Minor style suggestions (usually skip these — ruff handles them)

## Phase-specific focus

### Phase 1: Planning documents
- Cross-reference plan_*.md, test_*.md, code_*.md for consistency
- Every AC-xx must appear in all three documents
- Interface signatures must match across documents

### Phase 2: Test suite
- Every test must have `# Covers: AC-xx` annotation
- Tests must compile
- Fixtures must be realistic
- Unit vs integration separation must be correct

### Phase 3: Implementation
- All tests must pass
- Implementation must match code_*.md blueprint
- No test files modified
- ruff check clean

## Your unique value

You are from a different model family than Codex. Look for:
- Edge cases that GPT models commonly miss
- Logical consistency across the full artifact chain
- Whether the traceability matrix actually matches reality (not just grep)

## Code standards

Python 3.12+, type hints, pytest, ruff.
See `policies/guardrails.md` and `policies/traceability.md`.

FILEEOF

# ── .github/workflows/orchestrator.yml
cat > ".github/workflows/orchestrator.yml" << 'FILEEOF'
# ============================================================================
# Multi-LLM SDLC — Dumb YAML Orchestrator
# ============================================================================
# NOT an AI. Just if/else and gh cli.
# Reads state files, triggers Claude, counts reviewer approvals.
# Zero intelligence. By design.
# ============================================================================

name: "SDLC Pipeline"

on:
  push:
    paths: ["specs/**/spec.md"]
    branches: [main]
  workflow_dispatch:
    inputs:
      spec_id:
        description: "Spec ID (e.g., HL01_LL01)"
        required: true
        type: string

permissions:
  contents: write
  pull-requests: write
  issues: write

concurrency:
  group: sdlc-${{ github.sha }}
  cancel-in-progress: false

jobs:
  # ── Detect spec ────────────────────────────────────────────────────────────
  detect:
    runs-on: ubuntu-latest
    outputs:
      id: ${{ steps.parse.outputs.id }}
      hl: ${{ steps.parse.outputs.hl }}
      ll: ${{ steps.parse.outputs.ll }}
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 2 }
      - name: Parse spec
        id: parse
        run: |
          if [ -n "${{ inputs.spec_id }}" ]; then
            ID="${{ inputs.spec_id }}"
          else
            CHANGED=$(git diff --name-only HEAD~1 HEAD -- 'specs/**/spec.md' | head -1)
            HL=$(echo "$CHANGED" | grep -oP 'HL\d+')
            LL=$(echo "$CHANGED" | grep -oP 'LL\d+')
            ID="${HL}_${LL}"
          fi
          echo "id=$ID" >> "$GITHUB_OUTPUT"
          echo "hl=$(echo $ID | cut -d_ -f1)" >> "$GITHUB_OUTPUT"
          echo "ll=$(echo $ID | cut -d_ -f2)" >> "$GITHUB_OUTPUT"

  # ── Phase 1: Planning ─────────────────────────────────────────────────────
  phase-plan:
    needs: detect
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }

      - name: Setup branch + PR
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          ID="${{ needs.detect.outputs.id }}"
          BRANCH="sdlc/$ID"
          git config user.name "sdlc-bot"
          git config user.email "sdlc-bot@users.noreply.github.com"
          git checkout -b "$BRANCH" 2>/dev/null || git checkout "$BRANCH"

          # Create PR if not exists (triggers Codex + Gemini auto-review)
          git push origin "$BRANCH" --force-with-lease 2>/dev/null || true
          EXISTING=$(gh pr list --head "$BRANCH" --json number --jq '.[0].number' 2>/dev/null || echo "")
          if [ -z "$EXISTING" ] || [ "$EXISTING" = "null" ]; then
            gh pr create --head "$BRANCH" --base main \
              --title "[$ID] $(head -1 specs/${{ needs.detect.outputs.hl }}/${{ needs.detect.outputs.ll }}/spec.md | sed 's/^# //')" \
              --body "Multi-LLM SDLC pipeline. Three phases. Two independent reviewers."
          fi

      - name: Claude creates plan
        uses: anthropics/claude-code-action@v1
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          prompt: |
            Phase 1: Create planning documents for ${{ needs.detect.outputs.id }}.
            Read CLAUDE.md for your full instructions.
            Read specs/${{ needs.detect.outputs.hl }}/${{ needs.detect.outputs.ll }}/spec.md.
            Create: plan_${{ needs.detect.outputs.id }}.md, test_${{ needs.detect.outputs.id }}.md, code_${{ needs.detect.outputs.id }}.md
            in specs/${{ needs.detect.outputs.hl }}/${{ needs.detect.outputs.ll }}/.
            Update change.md. Commit as [${{ needs.detect.outputs.id }}] plan iter 1.
          claude_args: "--max-turns 15"

      - name: Push (triggers auto-reviews)
        run: |
          git push origin "sdlc/${{ needs.detect.outputs.id }}" --force-with-lease

  # ── Phase 2: Test creation ─────────────────────────────────────────────────
  phase-tests:
    needs: [detect, phase-plan]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          ref: sdlc/${{ needs.detect.outputs.id }}
          fetch-depth: 0
      - uses: actions/setup-python@v5
        with: { python-version: "3.12" }

      - name: Claude creates tests
        uses: anthropics/claude-code-action@v1
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          prompt: |
            Phase 2: Create test suite for ${{ needs.detect.outputs.id }}.
            Read CLAUDE.md, the approved test_${{ needs.detect.outputs.id }}.md.
            Create unit tests, integration tests, fixtures in modules/${{ needs.detect.outputs.hl }}/${{ needs.detect.outputs.ll }}/tests/.
            Create stubs in modules/${{ needs.detect.outputs.hl }}/${{ needs.detect.outputs.ll }}/src/.
            Every test must have # Covers: AC-xx.
            Commit as [${{ needs.detect.outputs.id }}] tests iter 1.
          claude_args: "--max-turns 15"

      - name: Push
        run: git push origin "sdlc/${{ needs.detect.outputs.id }}" --force-with-lease

  # ── Phase 3: Code creation ─────────────────────────────────────────────────
  phase-code:
    needs: [detect, phase-tests]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          ref: sdlc/${{ needs.detect.outputs.id }}
          fetch-depth: 0
      - uses: actions/setup-python@v5
        with: { python-version: "3.12" }

      - name: Claude creates code
        uses: anthropics/claude-code-action@v1
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          prompt: |
            Phase 3: Implement code for ${{ needs.detect.outputs.id }}.
            Read CLAUDE.md, the approved code_${{ needs.detect.outputs.id }}.md.
            Implement in modules/${{ needs.detect.outputs.hl }}/${{ needs.detect.outputs.ll }}/src/.
            ALL tests must pass. Do NOT modify test files.
            Run: python -m pytest and ruff check.
            Commit as [${{ needs.detect.outputs.id }}] code iter 1.
          claude_args: "--max-turns 20"

      - name: Push + notify
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          git push origin "sdlc/${{ needs.detect.outputs.id }}" --force-with-lease
          PR=$(gh pr list --head "sdlc/${{ needs.detect.outputs.id }}" --json number --jq '.[0].number')
          [ -n "$PR" ] && gh pr comment "$PR" --body "Pipeline complete for ${{ needs.detect.outputs.id }}. All three phases executed. Ready for human review."

FILEEOF

# ── .gitignore
cat > ".gitignore" << 'FILEEOF'
__pycache__/
*.pyc
.DS_Store
*.egg-info/
.pytest_cache/
.ruff_cache/
.coverage
dist/
build/
.env
node_modules/

FILEEOF

# ── AGENTS.md
cat > "AGENTS.md" << 'FILEEOF'
# AGENTS.md — Multi-LLM SDLC Pipeline

## Your role

You are REVIEWER 1 (Codex Cloud). You review artifacts that Claude creates.
Gemini Code Assist is the independent REVIEWER 2. You do not coordinate with Gemini.
A dumb YAML orchestrator manages phases. You do not orchestrate.

## The cardinal rule: traceability matrix first

Before evaluating code style, architecture, or naming, build the traceability matrix.

1. Open `specs/HL{nn}/LL{nn}/spec.md` — count every `AC-xx`
2. For each `AC-xx`, check if it appears in the artifact under review
3. ANY missing `AC-xx` = P0 blocking. Full stop.

Output format:
```
TRACEABILITY MATRIX — [HL01_LL01] plan

AC-01: COVERED — plan section 2.1, shorten()
AC-02: COVERED — plan section 2.2, resolve()
AC-03: MISSING — click tracking not addressed

Coverage: 8/9
VERDICT: CHANGES_NEEDED
```

## Review guidelines

### P0 — blocking (must fix)
- ANY AC-xx missing from the artifact
- Logic errors causing incorrect behavior
- Security issues: injection, path traversal, credentials
- Type mismatches between interfaces
- Tests that don't test what they claim
- TDD violation: tests modified during code phase

### P1 — important (should fix)
- Missing type hints on public functions
- Missing or misleading docstrings
- DRY violations (3+ duplications)
- Performance: O(n^2) where O(n) is obvious
- Naming convention violations (see policies/naming.md)

### Not flagged
- Style preferences (quotes, spacing) — ruff handles this
- Alternative approaches that aren't clearly better

## Issue format

```
**P0** | `modules/HL01/LL01/src/shortener.py:42` | Missing validation
AC-05 requires shorten("") raises ValueError. No validation found.
Fix: Add url validation at function entry.
```

## Verdict

End every review with exactly one:
- `VERDICT: APPROVED`
- `VERDICT: CHANGES_NEEDED`

## Phase-specific review focus

### Phase 1 (plan documents)
- Every REQ-xx has a section in plan_*.md
- Every AC-xx mapped to a function in code_*.md
- Every AC-xx has a test case in test_*.md
- Interfaces consistent across all three documents

### Phase 2 (test code)
- Every test has `# Covers: AC-xx`
- Tests compile: `python -m py_compile`
- Fixtures are realistic, not placeholder data
- Unit and integration tests separated correctly

### Phase 3 (implementation code)
- All tests pass: `python -m pytest`
- Lint clean: `ruff check`
- Tests NOT modified by Claude
- Implementation matches code_*.md blueprint

FILEEOF

# ── CLAUDE.md
cat > "CLAUDE.md" << 'FILEEOF'
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

FILEEOF

# ── README.md
cat > "README.md" << 'FILEEOF'
# Automated SDLC

> **Markdown is the source code. PRs are the communication protocol. The README is the true north star.**

Three frontier AI models from three different companies negotiate software through pull requests. One creates, two review independently, a dumb YAML state machine orchestrates. Zero API keys. Zero trust. Zero extra bills.

**Repository:** [github.com/sb-iam/sdlc](https://github.com/sb-iam/sdlc)

---

## The thesis

We are in the age of program synthesis. The feedback loop from ideation to execution has collapsed. The SDLC is no longer human-types-code-then-machine-runs-code. It is:

```
Human writes spec → machines negotiate plan → machines write tests →
machines write code → machines review each other → human merges
```

Specs are the new header files. PRs are the new standup meetings. The orchestrator is a shell script that cannot think.

---

## How it works

```
You push specs/HL01/LL01/spec.md → walk away → come back to a reviewed PR
```

### One PR per feature, three phases inside it

| Phase | Claude creates | Codex + Gemini review |
|-------|---------------|----------------------|
| 1. Planning | `plan.md`, `test.md`, `code.md` blueprints | Every REQ/AC from spec present? |
| 2. Test creation | Unit tests, integration tests, fixtures | Every AC has a `# Covers: AC-xx` test? |
| 3. Code creation | Implementation (TDD — all tests must pass) | Tests green, lint clean, REQs implemented? |

Each phase: Claude pushes a commit → Codex and Gemini auto-review the PR independently → both must approve → dumb YAML advances to next phase. If either rejects, Claude revises. Max 3 loops, then escalate to human.

PR title: `[HL01_LL01] core shortening logic` — always maps back to the spec.

The PR comment trail IS the audit log. Every review, every iteration, every verdict.

---

## The three models

| Role | Tool | Auth | Extra cost |
|------|------|------|-----------|
| **Creator** | Claude Code Action | Anthropic Max OAuth (~1yr token) | $0 |
| **Reviewer 1** | Codex Cloud (`@codex` auto-review) | ChatGPT Max (account-linked, permanent) | $0 |
| **Reviewer 2** | Gemini Code Assist (`gemini-code-assist[bot]`) | GitHub App install (free, Pro elevates) | $0 |
| **Orchestrator** | GitHub Actions YAML | Built-in `GITHUB_TOKEN` | $0 |

Three companies' frontier models. Zero API keys. Zero per-token charges. All subscription-based.

### Why not API keys

| API key | The catch |
|---------|-----------|
| `OPENAI_API_KEY` | Separate bill from ChatGPT Max. Per-token charges. |
| `GEMINI_API_KEY` | Completely separate product from Google AI Pro. Different billing account. |
| `ANTHROPIC_API_KEY` | Separate from Claude Max. Per-token charges. |

We avoid all of them. Every tool runs on its subscription.

---

## Zero-trust principles

1. **No LLM is privileged.** Claude creates. Codex reviews. Gemini reviews. None decide what happens next.
2. **No LLM reads another LLM's output directly.** They all read the same specs, the same code, the same PR diff — independently.
3. **Each model has its own context file.** Claude reads `CLAUDE.md`. Codex reads `AGENTS.md`. Gemini reads `.gemini/styleguide.md`.
4. **The orchestrator has no opinion.** It counts PR approvals. That's it.
5. **Disagreement escalates to human.** No LLM overrules another.

---

## No lost in translation

The #1 risk in multi-LLM program synthesis is context loss at handoff boundaries. The fix: every requirement and acceptance criterion gets a stable ID that must appear in every downstream artifact.

```
spec.md       →  REQ-01, AC-01 defined
plan.md       →  "AC-01 → URLShortener.shorten()"
test.md       →  "test_shorten covers AC-01"
tests/*.py    →  def test_shorten():  # Covers: AC-01
src/*.py      →  class URLShortener:  # Implements: REQ-01
```

Both reviewers build a traceability matrix per review. Any missing AC = instant P0 blocking. The matrix is the primary review output.

---

## Quick start

```bash
# 1. Clone
git clone https://github.com/sb-iam/sdlc.git && cd sdlc

# 2. Auth (one-time, lasts months)
claude setup-token && gh secret set CLAUDE_CODE_OAUTH_TOKEN

# 3. Install review bots (one-time, permanent)
# → chatgpt.com/codex/settings/code-review → enable auto-review
# → github.com/apps/gemini-code-assist → install on this repo

# 4. Write a spec
cp specs/_templates/ll_spec.md specs/HL01/LL01/spec.md
vim specs/HL01/LL01/spec.md   # Add your REQ/AC tables

# 5. Push and walk away
git add . && git commit -m "[HL01_LL01] spec: core shortening logic" && git push

# 6. Watch
gh run watch
# Come back to a PR with plan, tests, code — reviewed by two independent AIs.
```

---

## Folder structure

```
specs/                           ← Source of truth (the "include/" folder)
  _templates/                    ← HL and LL spec templates
  HL01/spec.md                   ← High-level product spec
  HL01/LL01/spec.md              ← Subtask spec with REQ/AC tables
  HL01/LL01/plan_HL01_LL01.md    ← Generated architecture plan
  HL01/LL01/test_HL01_LL01.md    ← Generated test specifications
  HL01/LL01/code_HL01_LL01.md    ← Generated code blueprint
  HL01/LL01/change.md            ← Evolution log

modules/                         ← Generated code (mirrors specs/)
  HL01/LL01/src/                 ← Implementation — # Implements: REQ-xx
  HL01/LL01/tests/unit/          ← Unit tests — # Covers: AC-xx
  HL01/LL01/tests/integration/   ← Integration tests
  HL01/LL01/tests/fixtures/      ← Test data sets

policies/                        ← Shared rules (all models read)
  naming.md | guardrails.md | traceability.md | observability.md | review_standards.md

CLAUDE.md                        ← Claude instructions (creator)
AGENTS.md                        ← Codex instructions (reviewer 1)
.gemini/styleguide.md            ← Gemini instructions (reviewer 2)
.github/workflows/orchestrator.yml ← Dumb YAML state machine
```

---

## Full documentation

| Document | What it covers |
|----------|---------------|
| [docs/architecture/ARCHITECTURE.md](docs/architecture/ARCHITECTURE.md) | 15-section design document: all decisions, auth, traceability, costs, risks |
| [docs/architecture/diagrams.md](docs/architecture/diagrams.md) | 6 Mermaid diagrams: architecture, pipeline, traceability, auth, folders, PR anatomy |
| [policies/traceability.md](policies/traceability.md) | REQ/AC threading protocol |
| [policies/guardrails.md](policies/guardrails.md) | Must/must-not rules for all LLMs |
| [policies/review_standards.md](policies/review_standards.md) | P0/P1 severity definitions |

---

## Roadmap

### Phase 1: Three-model tribunal (current)

Three frontier models on GitHub PRs. Claude creates, Codex + Gemini review. Dumb YAML orchestrates. One PR per feature, three phases, REQ/AC traceability at every level.

- [x] Architecture design
- [x] Auth model: zero API keys, all subscriptions
- [x] Template repo with all context files
- [ ] First real spec → plan → tests → code pipeline run
- [ ] Validate Codex + Gemini auto-review triggers
- [ ] End-to-end pipeline with human merge

### Phase 2: Multi-cloud, multi-LLM expansion

Extend beyond three models and beyond GitHub-native tools. Docker containers on local machines or cheap VPSes run additional LLMs via their CLI tools. The same zero-trust principles apply — the PR is still the only communication channel.

- [ ] Docker-based LLM runners (Gemini CLI, Claude Code CLI, Codex CLI)
- [ ] Fourth+ reviewer: Grok, DeepSeek, or other frontier models
- [ ] Multi-cloud deployment: local Docker, GH Actions, GCP Cloud Run
- [ ] Parallel pipelines: multiple HL/LL features running simultaneously
- [ ] Cross-feature integration testing after merge
- [ ] README-driven spec generation: README as the ultimate source of truth

### Phase 3: Lattice integration

Connect the SDLC pipeline to the Lattice edtech platform for collaborative spec writing, knowledge management, and enterprise deployment.

---

## Cost

| Service | Plan | Monthly (CAD) |
|---------|------|--------------|
| Anthropic | Max | ~$270 |
| OpenAI | ChatGPT Max | ~$270 |
| Google | AI Pro | $26.99 |
| GitHub | Free | $0 |
| **Total** | **3 frontier models** | **~$567** |

Per-feature marginal cost: $0 (all subscription-based).

---

## License

TBD

---

*The README is the true north star. Everything in this repo serves the vision described here.*

FILEEOF

# ── docs/architecture/ARCHITECTURE.md
cat > "docs/architecture/ARCHITECTURE.md" << 'FILEEOF'
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

FILEEOF

# ── docs/architecture/diagrams.md
cat > "docs/architecture/diagrams.md" << 'FILEEOF'
# Architecture diagrams

All diagrams render natively on GitHub via Mermaid.

---

## Diagram 1: Zero-trust three-model architecture

```mermaid
flowchart TD
    Human["Human pushes spec"] --> YAML["GitHub Actions<br/><i>Dumb YAML orchestrator</i><br/>No AI. Just if/else."]
    
    YAML --> Claude["Claude Code Action<br/><i>Creator — produces all artifacts</i><br/>Auth: Max OAuth ~1yr"]
    
    Claude --> PR["PR opened on branch<br/><i>Triggers both auto-reviewers</i>"]
    
    PR --> Codex["Codex Cloud<br/><i>Reviewer 1 — independent</i><br/>Reads: AGENTS.md<br/>Auth: ChatGPT Max"]
    PR --> Gemini["Gemini Code Assist<br/><i>Reviewer 2 — independent</i><br/>Reads: .gemini/<br/>Auth: GitHub App free"]
    
    Codex --> Verdicts["PR collects both verdicts<br/><i>Independent traceability matrices</i>"]
    Gemini --> Verdicts
    
    Verdicts --> Consensus["Dumb YAML consensus<br/><i>gh pr reviews → count approvals</i><br/>Both approved? Next phase.<br/>Either rejected? Claude revises.<br/>3 loops? Escalate to human."]
    
    Consensus -->|"Both approved"| Next["Next phase or human merge"]
    Consensus -->|"Changes needed"| Claude

    style YAML fill:#f1efe8,stroke:#5f5e5a,color:#2c2c2a
    style Claude fill:#e1f5ee,stroke:#0f6e56,color:#04342c
    style Codex fill:#faece7,stroke:#993c1d,color:#4a1b0c
    style Gemini fill:#faeeda,stroke:#854f0b,color:#412402
    style PR fill:#eeedfe,stroke:#534ab7,color:#26215c
    style Verdicts fill:#eeedfe,stroke:#534ab7,color:#26215c
    style Consensus fill:#f1efe8,stroke:#5f5e5a,color:#2c2c2a
    style Human fill:#f1efe8,stroke:#5f5e5a,color:#2c2c2a
    style Next fill:#e1f5ee,stroke:#0f6e56,color:#04342c
```

### Zero-trust principles

1. No LLM is privileged — Claude creates, Codex reviews, Gemini reviews, none decide what happens next
2. No LLM reads another LLM's output directly — they all read the same specs, code, PR diff
3. Each model has its OWN context file — CLAUDE.md, AGENTS.md, .gemini/styleguide.md
4. The orchestrator has no opinion — it counts approvals, nothing more
5. Disagreement escalates to human — no LLM overrules another

---

## Diagram 2: Single PR, three phases

```mermaid
flowchart TD
    subgraph PR["PR #42: [HL01_LL01] core shortening logic"]
        direction TB
        
        subgraph P1["Phase 1: Planning"]
            C1["Claude creates:<br/>plan_HL01_LL01.md<br/>test_HL01_LL01.md<br/>code_HL01_LL01.md"] --> Push1["Commit: [HL01_LL01] plan iter 1"]
            Push1 --> R1a["Codex reviews<br/><i>PR comment with<br/>traceability matrix</i>"]
            Push1 --> R1b["Gemini reviews<br/><i>PR comment with<br/>traceability matrix</i>"]
            R1a --> V1["Both approved?"]
            R1b --> V1
        end
        
        subgraph P2["Phase 2: Test Suite + Data Creation"]
            C2["Claude creates:<br/>tests/unit/*.py<br/>tests/integration/*.py<br/>tests/fixtures/*.json"] --> Push2["Commit: [HL01_LL01] tests iter 1"]
            Push2 --> R2a["Codex reviews"]
            Push2 --> R2b["Gemini reviews"]
            R2a --> V2["Both approved?"]
            R2b --> V2
        end
        
        subgraph P3["Phase 3: Code Creation"]
            C3["Claude creates:<br/>src/*.py<br/>All tests must pass<br/>Cannot modify tests"] --> Push3["Commit: [HL01_LL01] code iter 1"]
            Push3 --> R3a["Codex reviews"]
            Push3 --> R3b["Gemini reviews"]
            R3a --> V3["Both approved?"]
            R3b --> V3
        end
        
        V1 --> P2
        V2 --> P3
    end
    
    V3 --> Merge["Human reviews<br/>full comment trail<br/>→ Merge"]

    style P1 fill:#e1f5ee,stroke:#0f6e56
    style P2 fill:#e1f5ee,stroke:#0f6e56
    style P3 fill:#e1f5ee,stroke:#0f6e56
    style PR fill:#eeedfe,stroke:#534ab7
    style Merge fill:#f1efe8,stroke:#5f5e5a,color:#2c2c2a
```

### What the PR contains when done

- **Commits**: plan iter 1..N, tests iter 1..N, code iter 1..N
- **Comments**: Codex reviews + Gemini reviews per phase, each with traceability matrix
- **Files**: plan.md, test.md, code.md, tests/, src/, fixtures/
- **Title**: [HL01_LL01] core shortening logic — always maps to spec

---

## Diagram 3: Traceability chain (no lost in translation)

```mermaid
flowchart TD
    Spec["spec.md<br/><b>REQ-01..07, AC-01..09</b><br/><i>Human writes, IDs are the contract</i>"]
    
    Spec --> Plan["plan_HL01_LL01.md<br/><i>## Module X — Implements: REQ-01</i><br/><i>AC-01 → shorten()</i>"]
    Spec --> Test["test_HL01_LL01.md<br/><i>test_shorten covers AC-01</i><br/><i>Every AC has a test row</i>"]
    Spec --> Code["code_HL01_LL01.md<br/><i>URLShortener.shorten()</i><br/><i>implements REQ-01</i>"]
    
    Test --> TestPy["tests/*.py<br/><code># Covers: AC-01</code><br/><i>on every test function</i>"]
    Code --> SrcPy["src/*.py<br/><code># Implements: REQ-01</code><br/><i>on every class</i>"]
    
    Plan --> ReviewP["Reviewer checks:<br/><b>9/9 AC in plan?</b>"]
    TestPy --> ReviewT["Reviewer checks:<br/><b>9/9 AC in tests?</b>"]
    SrcPy --> ReviewC["Reviewer checks:<br/><b>9/9 REQ in code?</b>"]
    
    ReviewP --> Matrix["Traceability matrix<br/>AC-01: COVERED ✓<br/>AC-02: COVERED ✓<br/>AC-03: MISSING ✗<br/><b>= P0 BLOCKING</b>"]

    style Spec fill:#eeedfe,stroke:#534ab7,color:#26215c
    style Plan fill:#e1f5ee,stroke:#0f6e56,color:#04342c
    style Test fill:#e1f5ee,stroke:#0f6e56,color:#04342c
    style Code fill:#e1f5ee,stroke:#0f6e56,color:#04342c
    style TestPy fill:#e1f5ee,stroke:#0f6e56,color:#04342c
    style SrcPy fill:#e1f5ee,stroke:#0f6e56,color:#04342c
    style Matrix fill:#fcebeb,stroke:#a32d2d,color:#501313
    style ReviewP fill:#f1efe8,stroke:#5f5e5a,color:#2c2c2a
    style ReviewT fill:#f1efe8,stroke:#5f5e5a,color:#2c2c2a
    style ReviewC fill:#f1efe8,stroke:#5f5e5a,color:#2c2c2a
```

### How IDs prevent lost in translation

Every `AC-xx` must appear at every level. If a reviewer can `grep -r "AC-03"` and find it in the spec but not in the tests — that is an instant P0 blocking issue. No interpretation needed. Machine-verifiable.

---

## Diagram 4: Auth model — zero API keys, zero extra bills

```mermaid
flowchart LR
    subgraph Anthropic["Anthropic"]
        Claude["Claude Code Action"]
        CAuth["Auth: CLAUDE_CODE_OAUTH_TOKEN<br/><i>claude setup-token → ~1yr</i><br/>Uses: Max plan budget<br/>Extra cost: $0"]
    end
    
    subgraph OpenAI["OpenAI"]
        Codex["Codex Cloud @codex"]
        OAuth["Auth: GitHub app linked<br/><i>chatgpt.com/codex → permanent</i><br/>Uses: ChatGPT Max budget<br/>Extra cost: $0"]
    end
    
    subgraph Google["Google"]
        Gemini["Gemini Code Assist"]
        GAuth["Auth: GitHub app install<br/><i>github.com/apps/gemini-code-assist</i><br/>Uses: Free (Pro elevates)<br/>Extra cost: $0"]
    end
    
    subgraph GitHub["GitHub"]
        Actions["GitHub Actions YAML"]
        GHAuth["Auth: Built-in GITHUB_TOKEN<br/><i>Automatic per workflow</i><br/>Uses: Free tier minutes<br/>Extra cost: $0"]
    end

    Claude --- CAuth
    Codex --- OAuth
    Gemini --- GAuth
    Actions --- GHAuth

    style Anthropic fill:#e1f5ee,stroke:#0f6e56
    style OpenAI fill:#faece7,stroke:#993c1d
    style Google fill:#faeeda,stroke:#854f0b
    style GitHub fill:#f1efe8,stroke:#5f5e5a
```

### Why not API keys

| API key | What it does | The catch |
|---------|-------------|-----------|
| `OPENAI_API_KEY` | Powers `openai/codex-action` on GH runners | Separate bill from ChatGPT Max. Per-token charges. |
| `GEMINI_API_KEY` | Powers Gemini API calls from AI Studio | Completely separate product from Google AI Pro. Different billing account. |
| `ANTHROPIC_API_KEY` | Powers Claude API calls | Separate from Claude Max. Per-token charges. |

We avoid ALL of these. Every tool runs on its subscription. No surprises.

---

## Diagram 5: Folder structure

```mermaid
graph TD
    Root["Repository root"] --> Specs["specs/<br/><i>The include/ folder</i><br/><i>Source of truth</i>"]
    Root --> Modules["modules/<br/><i>Generated code</i><br/><i>Mirrors specs/</i>"]
    Root --> Policies["policies/<br/><i>Shared rules</i><br/><i>All models read</i>"]
    Root --> GH[".github/workflows/<br/><i>Dumb YAML</i>"]
    Root --> Context["CLAUDE.md<br/>AGENTS.md<br/>.gemini/"]
    
    Specs --> HL["HL01/"]
    HL --> HLSpec["spec.md<br/><i>Product vision</i>"]
    HL --> LL["LL01/"]
    LL --> LLSpec["spec.md<br/><i>REQ/AC tables</i>"]
    LL --> Plan["plan_HL01_LL01.md"]
    LL --> TestSpec["test_HL01_LL01.md"]
    LL --> CodeSpec["code_HL01_LL01.md"]
    LL --> Change["change.md"]
    
    Modules --> MHL["HL01/LL01/"]
    MHL --> Src["src/<br/><i># Implements: REQ-xx</i>"]
    MHL --> Tests["tests/"]
    Tests --> Unit["unit/<br/><i># Covers: AC-xx</i>"]
    Tests --> Integ["integration/"]
    Tests --> Fixtures["fixtures/"]

    style Specs fill:#eeedfe,stroke:#534ab7,color:#26215c
    style Modules fill:#e1f5ee,stroke:#0f6e56,color:#04342c
    style Policies fill:#faeeda,stroke:#854f0b,color:#412402
    style GH fill:#f1efe8,stroke:#5f5e5a,color:#2c2c2a
    style Context fill:#f1efe8,stroke:#5f5e5a,color:#2c2c2a
```

### The mirror principle

`specs/HL01/LL01/spec.md` defines the contract.
`modules/HL01/LL01/src/` implements it.
Same path structure. Specs are the `.hpp`, modules are the `.cpp`.

---

## Diagram 6: PR anatomy (what a completed feature looks like)

```mermaid
gitGraph
    commit id: "[HL01_LL01] spec"
    branch sdlc/HL01_LL01
    commit id: "plan iter 1"
    commit id: "plan iter 2" tag: "Codex+Gemini: APPROVED"
    commit id: "tests iter 1" tag: "Codex+Gemini: APPROVED"
    commit id: "code iter 1"
    commit id: "code iter 2" tag: "Codex+Gemini: APPROVED"
    checkout main
    merge sdlc/HL01_LL01 id: "Human merges"
```

### PR comment trail

```
#1  codex-cloud[bot]       Phase 1: AC-03 missing. CHANGES_NEEDED
#2  gemini-code-assist     Phase 1: AC-09 not addressed. CHANGES_NEEDED
#3  codex-cloud[bot]       Phase 1 re-review: 9/9 AC. APPROVED
#4  gemini-code-assist     Phase 1 re-review: APPROVED
#5  codex-cloud[bot]       Phase 2: APPROVED
#6  gemini-code-assist     Phase 2: APPROVED
#7  codex-cloud[bot]       Phase 3: tests green, 9/9 AC. APPROVED
#8  gemini-code-assist     Phase 3: APPROVED
#9  human                  LGTM. Merging.
```

One PR. One feature. Complete audit trail.

FILEEOF

# ── modules/HL01/LL01/AGENTS.md
cat > "modules/HL01/LL01/AGENTS.md" << 'FILEEOF'
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

FILEEOF

# ── policies/guardrails.md
cat > "policies/guardrails.md" << 'FILEEOF'
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

FILEEOF

# ── policies/naming.md
cat > "policies/naming.md" << 'FILEEOF'
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

FILEEOF

# ── policies/observability.md
cat > "policies/observability.md" << 'FILEEOF'
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

FILEEOF

# ── policies/review_standards.md
cat > "policies/review_standards.md" << 'FILEEOF'
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

FILEEOF

# ── policies/traceability.md
cat > "policies/traceability.md" << 'FILEEOF'
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

FILEEOF

# ── specs/HL01/LL01/change.md
cat > "specs/HL01/LL01/change.md" << 'FILEEOF'
# HL01_LL01: Change log

## v0 — Initial spec
- Created from product vision HL01
- 7 requirements (REQ-01 through REQ-07)
- 9 acceptance criteria (AC-01 through AC-09)
- Scoped to core shortening logic only (no CLI, no HTTP)

FILEEOF

# ── specs/HL01/LL01/spec.md
cat > "specs/HL01/LL01/spec.md" << 'FILEEOF'
# HL01_LL01: Core shortening and resolution logic

## Parent
HL01: URL Shortener Service

## Problem
Need a core engine that generates 6-char alphanumeric codes for URLs,
resolves codes back to URLs, and tracks click counts per code.

## Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| REQ-01 | Generate unique 6-char alphanumeric short code for any valid URL | Must |
| REQ-02 | Resolve a short code back to the original URL | Must |
| REQ-03 | Track click count (incremented on each resolve) | Must |
| REQ-04 | Reject invalid URLs (no scheme, empty string) | Must |
| REQ-05 | Reject resolution of non-existent codes | Must |
| REQ-06 | Support custom short codes (user-provided alias) | Must |
| REQ-07 | Reject custom codes that collide with existing ones | Must |

## Acceptance criteria

| ID | Criterion | Traces to |
|----|-----------|-----------|
| AC-01 | `shorten("https://example.com")` returns 6-char alphanumeric | REQ-01 |
| AC-02 | `resolve(code)` returns `"https://example.com"` | REQ-02 |
| AC-03 | `resolve(code)` increments click count each time | REQ-03 |
| AC-04 | `stats(code)` returns `{"url", "clicks", "created_at"}` | REQ-03 |
| AC-05 | `shorten("")` raises `ValueError` | REQ-04 |
| AC-06 | `shorten("not-a-url")` raises `ValueError` | REQ-04 |
| AC-07 | `resolve("nonexistent")` raises `KeyError` | REQ-05 |
| AC-08 | `shorten(url, alias="x")` stores with code `"x"` | REQ-06 |
| AC-09 | `shorten(url2, alias="x")` raises `ValueError` (collision) | REQ-07 |

## Interfaces

```python
class URLShortener:
    def shorten(self, url: str, alias: str | None = None) -> str: ...
    def resolve(self, code: str) -> str: ...
    def stats(self, code: str) -> dict: ...
```

## Non-goals
- No HTTP server
- No persistent storage
- No authentication

---

## Traceability contract (for reviewers)

Every downstream artifact MUST satisfy ALL. Missing = P0.

- [ ] plan_HL01_LL01.md: Every REQ-xx has a section
- [ ] plan_HL01_LL01.md: Every AC-xx mapped to function
- [ ] test_HL01_LL01.md: Every AC-xx has a test case
- [ ] tests/: Every test has `# Covers: AC-xx`
- [ ] src/: Every REQ-xx implemented
- [ ] change.md: Updated

FILEEOF

# ── specs/HL01/spec.md
cat > "specs/HL01/spec.md" << 'FILEEOF'
# HL01: URL Shortener Service

## Vision
A simple, in-memory URL shortener usable as a library and CLI tool.
Generates short codes, resolves them, tracks click analytics.

## Subtasks
- LL01: Core shortening and resolution logic

## Success criteria
- All subtask acceptance criteria pass
- Full test coverage on core logic

FILEEOF

# ── specs/_templates/hl_spec.md
cat > "specs/_templates/hl_spec.md" << 'FILEEOF'
# HL{nn}: [Product feature name]

## Vision
<!-- What is this feature? Why does it matter? -->

## Subtasks
- LL01: [First subtask]
- LL02: [Second subtask]

## Success criteria
<!-- How do we know the whole HL is done? -->

FILEEOF

# ── specs/_templates/ll_spec.md
cat > "specs/_templates/ll_spec.md" << 'FILEEOF'
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

FILEEOF

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "✅ sb-iam/sdlc populated! (19 content files + 6 Mermaid diagrams)"
echo ""
find . -type f -not -name '.gitkeep' -not -path './.git/*' | sort | while read f; do
  echo "  $f"
done
echo ""
echo "Diagrams: docs/architecture/diagrams.md (6 Mermaid diagrams, render on GitHub)"
echo ""
echo "To push:"
echo "  git add -A"
echo "  git commit -m 'feat: multi-llm sdlc template — three models, zero API keys'"
echo "  git push origin main"
echo ""
echo "Then install the three bots:"
echo "  1. claude setup-token && gh secret set CLAUDE_CODE_OAUTH_TOKEN"
echo "  2. chatgpt.com/codex/settings/code-review → enable auto-review"
echo "  3. github.com/apps/gemini-code-assist → install on sb-iam/sdlc"