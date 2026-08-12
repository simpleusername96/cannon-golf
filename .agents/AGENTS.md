# .agents/AGENTS.md

## How We Work Here

- This folder is the unified repo-local agent environment for durable project
  memory, evolving plans, reusable workflow notes, helper scripts, and skills.
- For broad, risky, or multi-file governance work, read the relevant
  `.agents/*` files before implementation.
- Create a durable planning artifact only when the work matches
  `.agents/PLANS.md`; store the actual artifact under `.agents/execplans/`,
  never in `.agents/Plan.md` or an ad hoc docs folder.
- Keep diffs scoped and validation explicit.
- Keep active task progress in that plan's checkboxes rather than mirroring it
  into another document.
- Treat root `AGENTS.md` as the stable repo-wide operating contract.
- Treat the nearest local `AGENTS.md` as the source of truth for subtree-specific
  placement or operating rules.

## Customization

- Install repo-local skills under `.agents/skills/` only when they map to a real
  workflow boundary.
- Prefer one clear local skill per workflow over many generic checklists.
- Move repeated user instructions or repeated agent mistakes into the right
  durable layer.
- Keep transient discoveries in `.agents/*` instead of turning root `AGENTS.md`
  into a structure map.
