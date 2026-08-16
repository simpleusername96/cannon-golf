---
type: plan
status: active
created: 2026-08-16
scope: Separate Cannon Golf product specifications from reusable agent research while preserving the canonical owner decision queue
---

# Document Placement Migration - Execution Contract

## Purpose

- Objective: retain accepted Cannon Golf knowledge in `project-specs/` and move advisory research into `.agents/research/cannon-golf/`.
- Deliverable: two history-preserving moves, corrected authority links, and explicit placement guidance.
- Completion state: specifications and the decision queue remain canonical, research is clearly advisory, and no stale path remains.

## Scope and Boundaries

In scope: the exact paths in Discovery Closure, affected links, and root/local agent placement guidance.

Out of scope: gameplay/runtime files, assets, tests, `TASKS.md` lifecycle cleanup, product decisions, and any deletion or archive.

Constraints:

- Preserve unrelated dirty worktree changes and stage only document-migration paths.
- Use `git mv`; do not rewrite research content or lifecycle status merely because its location changes.
- `OPEN_QUESTIONS.md` stays beside the specs because it is the canonical owner-facing decision queue, despite its evidence lifecycle type.

## Discovery Closure

| Disposition | Exact paths | Locked reason |
| --- | --- | --- |
| Keep | `project-specs/cannon-golf/PRD.md`; `DESIGN_RULES.md`; `DECISIONS.md`; `OPEN_QUESTIONS.md`; `docs/asset-licenses.md` | Product, design, decisions, decision queue, and provenance owners |
| Move to `.agents/research/cannon-golf/` | `project-specs/cannon-golf/RESEARCH.md`; `project-specs/cannon-golf/CAMERA_AND_WORLD_READABILITY.ko.md` | Reusable advisory synthesis and explanatory evidence |
| Leave unchanged | `project-specs/cannon-golf/TASKS.md` | Draft-plan lifecycle is separate from placement migration |

Known link owners are root `AGENTS.md`, `project-specs/cannon-golf/AGENTS.md`, the retained spec set, and existing execution contracts found by the final stale-path scan. Classification is closed.

## Tasks

### Phase 1: Lock guidance and manifest

- [ ] **1.1 Update root and local placement rules.** State the authority/audience/function test and retain `OPEN_QUESTIONS.md` as the explicit decision-queue exception.
  - Accept: no guidance describes `RESEARCH.md` as product authority.
- [ ] **1.2 Record source path and SHA-256 for both files.** Map them to identically named targets under `.agents/research/cannon-golf/`.
  - Accept: both sources exist and targets do not conflict.

### Phase 2: Move and relink

- [ ] **2.1 Move both research files with `git mv`.** Do not move or edit `TASKS.md` except if a necessary link correction is found.
  - Accept: both target hashes equal the manifest and old paths are absent.
- [ ] **2.2 Update all inbound and internal links.** Search root guidance, `project-specs/`, and `.agents/`; correct related frontmatter and Markdown paths.
  - Accept: `rg -n 'RESEARCH\.md|CAMERA_AND_WORLD_READABILITY' AGENTS.md project-specs .agents` returns only new valid paths.

### Phase 3: Validate and close

- [ ] **3.1 Run `git diff --check`, path existence checks, and `git diff --name-status -- AGENTS.md project-specs docs .agents`.**
  - Accept: only migration-owned documentation paths changed; no runtime, asset, resource, or test path is staged.
- [ ] **3.2 Record evidence, set `status: done`, and commit the scoped migration.**

## Validation and Rework Controls

- Do not run game tests; no runtime contract changes.
- Rerun link and hash checks only after a mapped file or consumer changes.
- Inspect the staged diff before commit because the repository may contain unrelated active implementation work.

## Predetermined Contingencies and Change Control

- If an old-path reference is historical prose rather than a live link, update the path while preserving the historical statement.
- If a target exists with different content, stop; do not overwrite or invent a versioned filename.
- Any move of `OPEN_QUESTIONS.md` or `TASKS.md`, or any product-decision edit, requires a revised contract and owner approval.

## Progress and Next Steps

- Canonical progress: this contract's checkboxes.
- Current phase: Awaiting owner approval to execute.
- Next task after approval: 1.1 Update root and local placement rules.
- Last completed gate: full specification and guidance audit; dispositions are locked.

## Completion and Stop Conditions

Complete only after every task passes and frontmatter is `done`. Replan only if the authority of a mapped file changes or an overlapping user edit makes the move unsafe.
