---
type: plan
status: done
created: 2026-08-12
scope: Complete the Cannon Golf documentation and repository-guidance migration
related:
  - ../../README.md
  - ../../project-specs/cannon-golf/PRD.md
  - ../../project-specs/cannon-golf/DESIGN_RULES.md
  - ../../project-specs/cannon-golf/DECISIONS.md
---

# Finish Document Migration - Execution Contract

Complete the repo-wide guidance and provenance migration while preserving the
unchanged Paint Mountain runtime as an explicitly labeled technical baseline.

## Purpose

- Objective: make future repository work route through Cannon Golf's current
  product and design authority without falsifying inherited asset history.
- Deliverable: a root agent policy, a minimal `.agents` environment, corrected
  local authority mapping, and self-contained inherited asset records.
- Completion state: all named files agree on authority and terminology, all
  local references resolve, and document validation passes.

## Scope and Boundaries

In scope:

- Repository and specification `AGENTS.md` guidance.
- Minimal planning policy under `.agents/`.
- Imported asset record scope, provenance, lifecycle metadata, and local links.
- The ambiguous unchanged-baseline progress entry in `TASKS.md`.

Out of scope:

- Gameplay, scene, resource, test, export, localization, or runtime identifier
  changes.
- Selection of a public product title or resolution of PRD open questions.
- A duplicate `.agents/design/` design authority.

Constraints and invariants:

- `Cannon Golf` remains a provisional working slug.
- `Paint Mountain` remains the truthful name for the source runtime and
  historical asset-generation context.
- `PRD.md` owns product behavior, `DESIGN_RULES.md` owns visual and UI direction,
  and `OPEN_QUESTIONS.md` owns unresolved product decisions.
- The root `AGENTS.md` Preflight block must match the agent-governor template.

Destructive or irreversible actions:

- None.

Exact actions requiring owner or user approval:

- Protected `AGENTS.md` changes are authorized by the user's request to finish
  the migration.

## Discovery Closure

| Requirement or concern | Verified current owner and behavior | Evidence | Locked decision | Task IDs |
| --- | --- | --- | --- | --- |
| Repo-wide guidance | No root `AGENTS.md`; spec policy applies only inside its folder | Markdown inventory and `project-specs/cannon-golf/AGENTS.md` | Add one concise root policy and retain local spec policy | 1.1, 2.1 |
| Planning artifacts | No `.agents/` environment exists | Repository inventory | Add only planning policy, compatibility pointer, local folder policy, and this contract | 1.2 |
| Imported records | Two records are byte-identical to Paint Mountain and reference omitted files | Git hash comparison against `32c0b33` and local path checks | Preserve historical wording, replace broken authority links, and label Cannon Golf applicability | 2.2, 2.3 |
| Runtime names | Runtime remains unchanged Paint Mountain baseline by accepted decision | `README.md`, `PRD.md`, and `DECISIONS.md` | Do not rename runtime or select a public title in this migration | 2.4 |

Readiness statement:

- Every material product, architecture, dependency, data, UX, ownership, safety,
  and validation decision is closed.
- PowerShell, Git, and ripgrep are available; validation commands were exercised
  during the preceding audit.
- Remaining unknowns are implementation-local and cannot change this contract.

## Tasks

### Phase 1: Establish repository-wide agent guidance

Goal: future work discovers the Cannon Golf authority graph from the repository
root and uses one planning location.

Preconditions:

- The repository is clean and its only existing protected instruction file is
  `project-specs/cannon-golf/AGENTS.md`.

Source owners: `AGENTS.md`, `.agents/AGENTS.md`, `.agents/PLANS.md`,
`.agents/Plan.md`

- [x] **1.1** Add the root operating contract.
  - Change: create `AGENTS.md` with project authority, legacy-runtime boundary,
    the fixed Preflight block, and concise placement rules.
  - Accept: the file routes product, visual, decision, question, and plan work to
    distinct owners and contains the exact fixed Preflight heading and marker.
  - Evidence: the root authority map names distinct owners and its normalized
    Preflight block exactly matches the agent-governor template.
- [x] **1.2** Establish the minimal `.agents` environment.
  - Change: add planning policy, the legacy plan pointer, local folder guidance,
    and this contract; omit unused memory and duplicate design templates.
  - Accept: `.agents/PLANS.md` is the sole planning policy and this file is the
    sole active execution contract.
  - Evidence: `.agents/` contains only the scoped policy, compatibility pointer,
    local guidance, and this one active contract.

### Phase 2: Repair authority and imported records

Goal: project-specific guidance and inherited asset records state their real
scope without broken local references.

Preconditions:

- Phase 1 files exist.

Source owners: `project-specs/cannon-golf/AGENTS.md`,
`docs/asset-licenses.md`, `assets/ui/icons/GENERATED_ASSETS.md`,
`project-specs/cannon-golf/TASKS.md`

- [x] **2.1** Clarify specification authority.
  - Change: give PRD, design rules, decisions, research, open questions, and
    draft tasks distinct roles in the local `AGENTS.md`.
  - Accept: no document is described as canonical outside its declared scope.
  - Evidence: the local policy now assigns product and visual authority to
    separate specs and labels evidence, questions, decisions, and draft tasks.
- [x] **2.2** Repair the third-party asset ledger.
  - Change: record Paint Mountain provenance, current inherited-baseline scope,
    Cannon Golf applicability, and valid related paths.
  - Accept: the record no longer implies that bundled assets are accepted Cannon
    Golf features and contains the required record sections.
  - Evidence: the ledger names source commit `32c0b33`, separates bundling from
    product approval, and contains Context, Decision, Rationale, and Consequences.
- [x] **2.3** Repair the generated asset record.
  - Change: replace omitted source paths with source-commit provenance and state
    that approval and feature roles belonged to the inherited baseline.
  - Accept: historical Paint Mountain wording remains truthful while no missing
    local path or Cannon Golf feature approval is implied.
  - Evidence: all three related paths resolve; source approval and inherited
    timeout or trajectory roles are explicitly non-authoritative for Cannon Golf.
- [x] **2.4** Correct the baseline progress statement.
  - Change: make the verified unchanged-runtime state a completed historical
    checkpoint rather than an unchecked future task.
  - Accept: `TASKS.md` remains a draft plan and accurately separates completed
    repository setup from future product implementation.
  - Evidence: the unchanged-runtime checkpoint is checked and scoped to creation
    of the specification; all product implementation tasks remain unchecked.

### Phase 3: Validate and close

Goal: prove the document graph is internally consistent and record completion.

Preconditions:

- Phase 2 acceptance checks pass.

Source owners: all files changed by this contract

- [x] **3.1** Validate lifecycle, paths, terminology, and patch hygiene.
  - Change: run the exact final checks below and correct only task-owned defects.
  - Accept: every final check exits successfully and no broken local reference
    remains in the changed document set.
  - Evidence: patch hygiene, exact Preflight, local document paths, lifecycle
    values, record sections, stale-reference removal, and placeholder checks pass;
    every retained Paint Mountain mention is source history or an explicit
    inherited-runtime boundary.
- [x] **3.2** Close this execution contract.
  - Change: record concise evidence beside completed tasks, set the current phase
    to complete, and change frontmatter status to `done`.
  - Accept: all task checkboxes are checked and no unresolved material decision
    remains in this contract.
  - Evidence: every task is checked, durable conclusions live in their owning
    policy or record, and the contract status is `done`.

## Validation and Rework Controls

| Cadence | Exact check | Run when | Do not rerun until |
| --- | --- | --- | --- |
| Inner loop | `git diff --check` | After each document patch | A changed document changes again |
| Final gate | `git diff --check` plus a PowerShell local Markdown/frontmatter path check over changed documents | All content tasks pass | A final-gate input changes |
| Final gate | `rg -n -i "Paint Mountain|PaintMountain|paint_mountain" AGENTS.md .agents project-specs/cannon-golf docs assets/ui/icons/GENERATED_ASSETS.md` | All content tasks pass | A terminology-owner document changes |

Validation rules:

- Run the narrowest check that proves the current task.
- Run each final gate once after its owned tasks pass.
- Rerun a failed check only after a relevant implementation change or a new
  hypothesis can produce new evidence.
- Record known non-blocking historical Paint Mountain references once instead of
  treating them as accidental remnants.

## Predetermined Contingencies and Change Control

| Trigger | Required response | Boundary or escalation point |
| --- | --- | --- |
| A verified material fact contradicts this contract | Stop the affected branch, update the contract, and obtain any required approval before resuming | Do not let the executor choose a new product, architecture, dependency, data, UX, safety, or validation contract |
| A Paint Mountain term describes historical provenance | Preserve it and clarify scope | Do not replace history with the provisional Cannon Golf slug |
| A Paint Mountain term claims current Cannon Golf product authority | Route it to the owning spec or open question | Do not infer behavior from the inherited runtime |

Implementation-local discoveries may be handled inside the locked contract when
they cannot change scope, visible behavior, ownership, architecture, safety, or
acceptance.

## Progress and Next Steps

- Canonical progress: the task checkboxes in this contract.
- Current phase: Complete.
- Next task: None.
- Last completed gate: Final document, lifecycle, terminology, Preflight, and
  patch hygiene checks.
- Update rule: after a checkpoint passes, record its concise evidence, check the
  task, and advance this pointer in the same edit.

## Completion and Stop Conditions

Complete when:

- Every task acceptance check passes.
- Every final gate named by this contract passes.
- No placeholder or unresolved material decision remains.
- Durable authority and terminology decisions are recorded in their owning
  policy, specification, or record.
- Frontmatter status is changed to `done` only after implementation completes.

Replan when:

- A material discovery invalidates the locked contract.

Do not replan or stop for:

- Implementation-local mechanics already contained by this contract.
- A passing check whose relevant inputs have not changed.
