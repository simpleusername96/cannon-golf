---
type: policy
status: active
canonical_for: Repository planning artifact policy
scope: .agents/execplans
---

# Planning Artifact Policy

## Purpose

Create durable planning artifacts only when they reduce material uncertainty or
execution risk, and give future executors one decision-complete contract and one
progress source.

## When a Durable Artifact Is Required

Use one for:

- cross-cutting or multi-phase work;
- API, schema, persistence, or public-contract changes;
- operationally risky or hard-to-reverse work;
- work spanning more than five files;
- research or owner decisions that need a bounded, persistent checklist;
- work for which the user explicitly requests a durable plan.

Do not use one for:

- simple Q&A or classification opinions;
- single-note placement or linking judgments;
- small one-file edits;
- routine append-only note capture;
- work where repository instructions and a concise chat update are sufficient.

## Canonical Location and Naming

- Treat this file as policy, not as an active task plan.
- Store every durable research checklist or execution contract under
  `.agents/execplans/`.
- Name each artifact `YYYY-MM-DD-<outcome-slug>.md` with a short lowercase ASCII
  kebab-case outcome.
- Do not add `plan`, `execplan`, `final`, `v2`, model names, or session IDs to
  the slug.
- Update the existing file for the same outcome instead of creating
  revision-named copies.
- Use repository-relative project paths inside the artifact; do not embed a
  session-specific absolute repository root.
- Write headings and prose in English unless the user explicitly requests
  another language.
- Use `$goal-checklist-builder` to author or materially revise the artifact.

`.agents/Plan.md` is a compatibility pointer only. It is never an active plan or
template.

## Planning Modes

- A research or decision checklist may contain bounded investigation and open
  questions because resolving them is its work. It must not imply implementation
  readiness.
- An execution contract may be written only after material discovery and owner
  decisions are closed. Its implementation tasks must not contain research,
  comparison, technology selection, `TBD`, or another material decision for the
  executor.

An execution contract contains only the sections that prevent a real failure:

- Purpose
- Scope and Boundaries
- Discovery Closure
- Tasks
- Validation and Rework Controls
- Predetermined Contingencies and Change Control
- Progress and Next Steps
- Completion and Stop Conditions

## Checkpoint and Rework Rules

- Use task checkboxes in the relevant active artifact as the only task-progress
  ledger.
- Resume at the first unchecked task whose prerequisites are satisfied.
- Check a task only after its acceptance check passes; add a separate guard only
  for a distinct regression or leftover risk.
- Name only validation commands whose invocation and prerequisites are verified;
  otherwise define the exact authorized deterministic bootstrap precondition or
  keep the execution contract blocked.
- Do not rerun a passing check unless its relevant inputs changed or the contract
  schedules a broader final gate.
- If a material fact invalidates an execution contract, stop the affected branch
  and revise the contract. Do not let the executor redesign the work.
- Do not mirror active task state into `Documentation.md`, policy files, or a
  second plan.

## Lifecycle

- Use `type: plan` and `status: active` while a planning artifact is current.
- Change an execution contract to `done` only after its implementation acceptance
  and every final gate named by the contract passes; change a research checklist
  to `done` after its decision or exact blocker and owner are recorded under its
  evidence contract.
- Promote durable conclusions to the owning policy, specification, record,
  documentation, or repo-local skill.
- Do not treat `done`, `superseded`, or `archived` plans as current work.
- Archive, move, or delete stale plans only with explicit user approval.
