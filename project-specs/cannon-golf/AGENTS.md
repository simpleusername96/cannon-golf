# Project Spec Workspace Rules

This folder stores the persistent product specification package for one project.

## Purpose

Keep one evolving, agent-ready PRD and its supporting files so future sessions can continue the same project without rebuilding context from scratch.

## Source Of Truth

- `PRD.md` is the canonical source of truth.
- `DECISIONS.md` records key decisions and rejected alternatives.
- `RESEARCH.md` records external options and supporting evidence.
- `OPEN_QUESTIONS.md` records unresolved issues that still affect implementation.
- `TASKS.md` contains implementation-oriented work items derived from the PRD.

## Rules

1. Update existing files before creating new ones.
2. Do not create implementation code in this folder unless the user explicitly changes scope.
3. Do not leave core product ambiguity only in chat; write it into the project files.
4. Label guesses as `[assumption]`.
5. Move blocking ambiguity into `OPEN_QUESTIONS.md`.
6. Keep `PRD.md` concise and implementation-oriented.

## Completion Standard

This folder is in good shape when another agent can read it and start implementation planning without re-deriving the basic product intent.
