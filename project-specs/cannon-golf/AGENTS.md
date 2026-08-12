# Cannon Golf Project Specification Workspace Rules

This folder stores the persistent product specification package for the
provisional Cannon Golf project.

## Purpose

Keep one evolving, agent-ready PRD and its supporting files so future sessions can continue the same project without rebuilding context from scratch.

## Source Of Truth

- `PRD.md` is canonical for product behavior and the observable player
  experience.
- `DESIGN_RULES.md` is canonical for visual composition and UI direction.
- `DECISIONS.md` records accepted choices and rejected alternatives.
- `RESEARCH.md` is consult-only evidence; it does not define the product.
- `OPEN_QUESTIONS.md` owns unresolved issues that still affect implementation.
- `TASKS.md` is a draft planning aid derived from the specifications. It is not
  an active execution contract.

## Rules

1. Update existing files before creating new ones.
2. Do not create implementation code in this folder unless the user explicitly
   changes scope.
3. Do not leave core product ambiguity only in chat; write it into the owning
   project file.
4. Label guesses as `[assumption]`.
5. Move blocking ambiguity into `OPEN_QUESTIONS.md` instead of selecting a
   product behavior during implementation.
6. Keep `PRD.md` concise and implementation-oriented.
7. Treat `Cannon Golf` as a working slug until a public title is accepted and
   recorded.
8. Use `Paint Mountain` only for truthful source history or inherited runtime
   behavior. Use `impact mark`, `impact history`, or `first-contact mark` for the
   new product concept.

## Completion Standard

This folder is in good shape when another agent can read it and start implementation planning without re-deriving the basic product intent.
