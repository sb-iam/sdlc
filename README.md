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

