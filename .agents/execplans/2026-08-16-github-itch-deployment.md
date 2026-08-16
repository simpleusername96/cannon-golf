---
type: plan
status: active
scope: repository publication, reproducible Web export, and automatic itch.io delivery
---

# Cannon Golf GitHub and itch.io deployment

## Purpose

Publish the current Cannon Golf prototype to a new private GitHub repository and
make every accepted push to `main` build, validate, and deploy the browser game
to `https://itchioprofile1351321.itch.io/cannon-golf`. The existing public itch.io
project remains the delivery page. GitHub is private because Cannon Golf is still
a provisional product title; repository visibility can be changed separately.

## Scope and Boundaries

In scope:

- A reproducible single-threaded Godot 4.7.1 Web export containing runtime files
  only.
- A pinned GitHub Actions workflow that validates the project, runs the existing
  suite, builds Web, verifies the itch.io payload, and pushes one traceable
  `alpha.<run>+<sha>` build to `itchioprofile1351321/cannon-golf:html5`.
- One private `simpleusername96/cannon-golf` GitHub repository, its
  `BUTLER_API_KEY` Actions secret, the initial `main` push, and the first live
  itch.io deployment.
- One-time itch.io upload classification as playable in browser and a public
  foreground smoke check.

Out of scope:

- Gameplay, terrain, camera, HUD, product naming, pricing, store art, analytics,
  or Windows-download distribution changes.
- Publishing local failed/preview/rollback terrain artifacts, temporary tests,
  build output, logs, or credentials.
- Making the GitHub repository public.

External mutations authorized by the user's request are limited to creating the
named GitHub repository, saving the itch API key as its Actions secret, pushing
the scoped commits, uploading to the named itch.io project, and setting that
upload as browser-playable. The API key must never appear in command output,
files, commits, artifacts, or chat.

## Discovery Closure

- The local branch is `main`, has no remote, and GitHub CLI is authenticated as
  `simpleusername96`. `simpleusername96/cannon-golf` does not exist.
- The itch.io project already exists as project 4903095. It is `HTML`,
  `In development`, `No payments`, and `Public`, but has no uploaded file.
- Godot 4.7.1 export templates are installed. `export_presets.cfg` provides a
  single-threaded adaptive Web preset and `scripts/verify-web-release.ps1`
  validates exact runtime references, thread absence, itch limits, and gzip
  budget.
- Local import, script parsing, startup, and `cannon_golf_ui_contract_test.gd`
  pass on the current tree. Web export succeeds, but the release validator fails
  because `index.pck` is 286,463,808 bytes. The preset currently includes
  documentation imagery and local untracked prepared-course experiments; the
  runtime export boundary must exclude both categories.
- After those exclusions, the runtime package is 17,098,240 bytes and the full
  gzip payload is 23,110,569 bytes. The inherited Paint Mountain 20 MB initial
  cap and 17,269,724-byte baseline do not describe Cannon Golf's ten prepared
  courses, so the explicit Cannon Golf baseline is 23,110,569 bytes with the
  already-proven Cardborne initial cap of 30 MB. The validator retains its 10%
  regression ceiling and every actual itch.io file/count/path limit.
- Paint Mountain established the pinned Godot 4.7.1 and Butler 15.30.0 workflow,
  checksum verification, complete pre-publish tests, concurrency cancellation,
  build metadata, and browser-channel setup. Cardborne improved it by resolving
  the Butler target from one exact itch project URL and proving that the API key
  owner matches the project owner. This plan uses the stricter combined pattern.
- Official itch.io guidance requires an existing project and a channel push of a
  directory with `butler push user/game:channel`; the first HTML channel must be
  marked playable in the project editor. GitHub recommends encrypted Actions
  secrets and least-privilege workflow permissions. Godot Web export requires
  the matching export templates; this project intentionally uses the
  single-threaded template.
- Rejected alternatives: a floating setup action (weaker supply-chain control),
  committing Web binaries (duplicates generated output), local Butler login
  (does not solve CI authentication), title/slug project lookup (ambiguous), and
  deploying Windows first (repeats Paint Mountain's browser-delivery mistake).

## Tasks

- [x] **1. Make the Web release boundary reproducible.**
  - Exclude `.agents`, docs/spec evidence, tests, transient prepared-course
    variants, and validation output from both export presets while retaining all
    runtime assets.
  - Add narrow ignore rules for known local prepared-course and temporary-test
    artifacts without deleting them.
  - Export Web to `builds/web/index.html` and pass
    `scripts/verify-web-release.ps1`.

- [x] **2. Add the deployment contract.**
  - Add `.github/workflows/deploy-itch.yml` for `main` pushes and manual runs.
  - Pin checkout/cache actions by commit, pin and checksum Godot 4.7.1 and Butler
    15.30.0, set `contents: read`, cancel superseded runs, and expose
    `BUTLER_API_KEY` only to credential checks and publication steps.
  - Resolve and verify the exact itch URL before building. Run `scripts/verify.ps1`,
    `scripts/test.ps1`, Web export, static release validation, `butler validate`,
    and then `butler push` with commit-derived version metadata.
  - Add a concise Korean deployment runbook with the target, secret name,
    triggers, and recovery procedure; do not copy a credential value.

- [ ] **3. Publish the repository and credential.**
  - Commit the already-passing tracked UI changes separately from deployment
    infrastructure so history retains their ownership.
  - Commit the release-boundary, workflow, runbook, and this execution record.
  - Create private `simpleusername96/cannon-golf` without auto-initializing it,
    add `origin`, create or reuse an itch API key without displaying it, save it
    as the repository secret `BUTLER_API_KEY`, and push `main`.

- [ ] **4. Prove the live delivery loop.**
  - Wait for the push-triggered Actions run. It must finish successfully and its
    summary must name `itchioprofile1351321/cannon-golf:html5`, the full commit,
    version, payload bytes, and `index.pck` SHA-256.
  - In itch.io, mark the `html5` channel as playable in browser, use click-to-
    launch fullscreen, enable the fullscreen button, and save without changing
    the existing Public/In development/No payments settings.
  - Load the public page, launch the embedded build, confirm the Godot canvas
    reaches the main menu without an itch loading error, and retain the live page
    as the final browser tab.

## Validation and Rework Controls

- Targeted local gate: `scripts/verify.ps1`, the current UI contract test, one Web
  export, and `scripts/verify-web-release.ps1`. Run it again only if export inputs
  change.
- The complete test suite is intentionally deferred to one GitHub Actions run;
  it is the authoritative clean-checkout pre-publication gate. A failed test or
  release check prevents Butler from running.
- Do not retry an unchanged failing workflow more than once. Read the failing
  step, correct the owned input, and push a new commit. Do not weaken a checksum,
  test, payload limit, or secret guard to make deployment pass.
- A live browser failure after a successful upload is not accepted as complete;
  inspect the itch channel classification and the browser console/network state
  before changing game code.

## Predetermined Contingencies and Change Control

- If the current itch account already has a suitable reusable API key, use it;
  otherwise create `github-actions-cannon-golf`. Never revoke or rename another
  project's key during this task.
- If CAPTCHA or a fresh credential prompt prevents browser automation, stop at
  that exact page and ask the user to complete only that interaction.
- If the GitHub repository name becomes unavailable after the preflight check,
  stop and ask for a new durable name; do not invent a suffix.
- If the clean CI checkout exposes a missing tracked runtime artifact, add only
  the proven dependency. Do not commit the entire local prepared/UID/temp set.
- Any request to publish the GitHub source, add Windows distribution, alter itch
  visibility/pricing, or change gameplay revises this contract before action.

## Progress and Next Steps

- Task 1 passed: runtime-only Web export is 56,948,812 raw bytes and 23,110,569
  gzip bytes; all static checks pass.
- Task 2 passed: workflow YAML parses, all third-party actions use full commit
  pins, the credential is scoped to the three authorized steps, and the
  responsibility/failure-path audit found no competing runtime owner.
- Task 3 is partially complete: the private repository now exists at
  `https://github.com/simpleusername96/cannon-golf`, `origin` points to it, and
  the UI and deployment work are stored in separate local commits. The remote
  remains unpushed so the first workflow run cannot fail from a missing secret.
- Current stop condition: itch.io requires a fresh password confirmation before
  its API Keys page can be opened. The signed-in Chrome tab is retained at that
  prompt. After the user confirms it, create or reuse the key, store it as the
  GitHub `BUTLER_API_KEY` secret, and push `main`.

## Completion and Stop Conditions

Complete only when all four tasks are checked, the scoped commits are present on
`origin/main`, the push-triggered workflow succeeds for the same final commit,
and the public itch.io page launches the browser build. Stop earlier only for a
credential/CAPTCHA prompt, unavailable repository name, or a failure that would
require weakening a recorded release gate.
