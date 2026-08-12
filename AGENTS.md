# AGENTS.md

## Project

- `Cannon Golf` is the provisional working slug for a Windows desktop Godot 4
  3D physics puzzle. Do not treat it as an approved public title.
- The current runtime was copied unchanged from Paint Mountain commit `32c0b33`.
  Legacy paint, coverage, mountain, predictor, UI, and product names describe the
  inherited technical baseline, not accepted Cannon Golf behavior.
- Read `project-specs/cannon-golf/PRD.md` for canonical product behavior and
  `project-specs/cannon-golf/DESIGN_RULES.md` for canonical visual and UI
  direction.
- Read `project-specs/cannon-golf/DECISIONS.md` for accepted decisions,
  `project-specs/cannon-golf/OPEN_QUESTIONS.md` for unresolved owner decisions,
  and `project-specs/cannon-golf/RESEARCH.md` as consult-only evidence.
  `project-specs/cannon-golf/TASKS.md` is a draft planning aid, not an active
  execution contract.

## Operating Model

- Before changing gameplay, cameras, UI, stages, persistence, naming, or exports,
  read the relevant current specification and unresolved questions. Do not let
  inherited runtime behavior decide the new product by default.
- Use `Cannon Golf` only as the working repository and specification name until
  the product-title question is resolved and recorded. Preserve `Paint Mountain`
  when it truthfully identifies source history or an inherited implementation.
- In new product language, use `impact mark`, `impact history`, or
  `first-contact mark`. Do not rename retained coverage behavior and present it
  as the new impact-history model.
- Classify each inherited runtime owner as reuse, adaptation, or retirement
  before changing its responsibility. Keep product semantics separate from
  source-provenance records.

## Living Guidance

- This file is project-specific operating guidance.
- Its contents may be added, edited, reorganized, or removed as user requests and project conditions change.
- Keep only durable repo-wide instructions here when they do not need a separate workflow trigger.
- Prefer folder and file names that reveal purpose and function instead of explaining the whole structure in root `AGENTS.md`.
- Do not treat current folder structure, temporary placement decisions, or subtree names as a root-level contract unless the user explicitly wants that contract.

## Preflight
<!-- Fixed section. Keep this block exactly as defined by agent-governor. -->
### General
- Add short, truthful docstrings or inline comments when they materially clarify intent, responsibility, invariants, non-obvious constraints, or future handoff points for humans and agents.
- Prefer append-first updates that preserve prior intent and newly discovered constraints, but rewrite or remove comments when they become stale, redundant, or too long to stay trustworthy.
- If a commented class, function, or code block is deleted or its behavior changes, update or delete the attached comment in the same change.
- If the user's intended outcome is materially ambiguous and the ambiguity could change the implementation, output, or conclusion, ask a concise follow-up question with explicit options before proceeding.
- Do not ask follow-up questions when a reasonable, low-risk default is already clear from the request and local context.
- Prefer responsibility-shaped files and modules over large catch-all scripts; before expanding a large file, identify its owned responsibility, what it should not absorb, and whether local boundaries already cover the change.

### FE
- Prefer a component-driven UI so design and behavior stay consistent.
- Check alignment, typography, spacing, and padding/gap explicitly.
- Check overflow and clipping explicitly; no child element should be visibly cut off or exceed its container at supported desktop/mobile widths.
- Avoid unnecessary explanatory or guideline text.
- Keep non-essential elements visually restrained.

### BE
- Remove obsolete legacy code once the replacement is clearly in place.
- Design for reuse when the boundary is clear.
- Add logging where operational visibility matters, and persist it when the workflow depends on it.

### DB
- Ask before running broad or intensive database reads unless the need is already explicit.

## Project Memory

- Before broad, risky, or multi-file governance work, read the relevant files under `.agents/`.
- Use a durable planning artifact only for work that matches `.agents/PLANS.md`; store it under `.agents/execplans/` and do not create one for simple questions, single-note judgments, or small one-file edits.
- Use `.agents/*` for durable project memory, workflow notes, recurring gotchas, and repo-local skills.
- Keep active task progress in the relevant `.agents/execplans/*` artifact and other transient discoveries under `.agents/` instead of in root `AGENTS.md`.

## Documentation Lifecycle

- For agent-relevant Markdown that may guide future work, use `$doc-lifecycle-steward` to classify lifecycle `type` and `status`.
- Add lifecycle frontmatter only to agent-relevant `policy`, `spec`, `plan`, `handoff`, `evidence`, or `record` documents.
- Do not frontmatter-stamp protected instruction files such as `AGENTS.md`; audit them and propose minimal changes instead.

## Placement Rules

- Put stable repo-wide guidance in this file.
- Put specification-workspace rules in `project-specs/cannon-golf/AGENTS.md`.
- Put durable supporting memory and evolving notes in `.agents/*`.
- Put plan policy in `.agents/PLANS.md` and durable planning artifacts in `.agents/execplans/`.
- Keep product knowledge in `project-specs/cannon-golf/`; do not duplicate it into `.agents/` or infer it from the inherited runtime.
- Prefer purpose-revealing naming over root-level structure prose where naming can carry the meaning.
