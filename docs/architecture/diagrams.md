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

