# Skill deviations

## Phase 1 shell tooling

`write-bash-scripts` supplies Bash 3.2-compatible structure and ShellCheck validation for the extensionless scripts under `scripts/` and `cmake/`. The project rule against `markdownlint-cli2 --fix` continues to replace the Markdown skill's generic fixer with `npm run format` followed by `npm run lint:md`.

The build plan found that the catalog's Zig and audio skills were unwritten when this project started, so the first phases are done by hand from fosforo and springer. This note records every rule written by hand that a catalog skill would otherwise supply, against the issue that asks for that skill, so the skills can be written from this project. It also records where an installed skill was scoped down, replaced, or found wrong.

**The inclusion rule.** An issue gets an entry when a phase wrote any of its rules into a file by hand, whether as configuration or as a recorded decision. Each entry says what was written, where, and where it diverges from the issue body. Later phases append to the same entries rather than starting new ones.

The issues are in [`cboone/agent-harness-plugins`](https://github.com/cboone/agent-harness-plugins). Their states were read on 2026-09-14.

## Catalog issues

### #339 `scaffold-zig-cli` (open)

**Phase 0.** `.claude/settings.json` seeded with `Bash(zig build *)` and `Bash(zig fmt *)`, the two permissions the issue names. The Zig ignore entries beyond `scaffold-new-repo`'s `zig-cli` template, of which `zig-pkg/` is the one the template lacks. The `.editorconfig` sections for `*.{zig,zon}`, C sources and `CMakeLists.txt`, adapted from fosforo.

**Divergence.** The settings file also allowlists exact read-only lint commands and read-only `gh` commands, never a prefix that would admit a writing flag. Related issues: #364 registers the skill in `bootstrap-project` and `scaffold-new-repo`, and #352 closes other Zig gaps.

### #340 `set-up-macos-signing` (open)

**Phase 0.** [ADR 0021](../adr/0021-distribute-as-a-notarized-pkg.md): one signed, notarized, stapled pkg, built locally and never in CI, with the real identity supplied through `SAVERA_SIGNING_IDENTITY` and ad-hoc signing asserted in CI. `.gitignore` refuses `*.p8`. Implementation arrives in Phase 1 (ad-hoc signing) and Phase 7 (the release path).

### #341 `stamp-build-provenance` (open)

**Phase 0.** [ADR 0022](../adr/0022-stamp-provenance-without-namespacing-identity.md), adopted from fosforo's ADR 0018, including the two-`git rev-parse` rule. Implementation arrives in Phase 1.

### #342 `set-up-clap-validation` (open)

**Phase 0.** [ADR 0003](../adr/0003-author-clap-project-outward.md) requires `clap-validator` on both bundles.

**Divergence.** The installation half the issue describes now exists upstream: `cboone/gh-actions` v3.2.0 (2026-09-14) ships the `set-up-clap-validator` composite action, so Phase 1 consumes it rather than copying fosforo's.

### #343 `write-realtime-audio-code` (open)

**Phase 0.** [ADR 0007](../adr/0007-no-allocation-on-the-audio-thread.md)'s rules: nothing reachable from `process()` allocates, locks or makes a syscall; every capacity derived in one place with its derivation; single-writer relaxed atomics drained on the main thread; buffers sized once at `activate`; FPCR flush-to-zero around `process()`; runtime `if` at trust boundaries. `.github/zig.instructions.md` carries the review rules built on them.

**Divergence.** The issue's verification section centres on Thread Sanitizer, as fosforo's did. Savera starts no thread and every cross-thread datum has one writer, so there is no ordering between writers to verify, and the instrument is a source canary asserting that nothing under `src/` spawns a thread. The issue does not mention that a shipped ReleaseFast build removes `std.debug.assert`, which is why Savera's unit suite runs in three optimize modes and trust boundaries never use `assert`.

### #344 `scaffold-clap-audio-plugin` (open)

**Phase 0.** [ADR 0003](../adr/0003-author-clap-project-outward.md), [ADR 0004](../adr/0004-clap-bindings-via-translate-c.md), [ADR 0005](../adr/0005-a-pure-model-core-behind-a-seam.md) and [ADR 0023](../adr/0023-one-note-port-and-one-stereo-output.md), and the identifiers table in `AGENTS.md`.

**Divergence, twice.**

- The issue says to set `AUV2_INSTRUMENT_TYPE` in CMake "belt-and-braces" beside `features[0]`. For an instrument, clap-wrapper v0.16.0's build helper checks the explicit type first, so passing it makes the `features[0]` mapping unreachable and its warning impossible. The controls are therefore a unit test on `features[0]` and a `plutil` read of the built plist, never a grep for the warning.
- springer's ADR 0005, which the issue's seam guidance follows, enforces the seam with a comptime assertion on imports. A comptime block pins signatures, not import absence, so ADR 0005 here specifies a run-time walk of `src/model/` from the source root instead.

### #345 `plant-defects` (closed)

**Phase 0.** Nothing re-derived. The skill shipped after the build plan was written and is installed at 1.0.0. The Phase 0 plan's plant table uses its four columns and its ordered-assertion rule directly, and [ADR 0016](../adr/0016-harnesses-are-build-steps.md) cites that rule.

### #346 `check-ci-workflows` (open)

**Phase 0.** Applied by hand to every workflow: no `paths-ignore` on `text-lint.yml`, `gitleaks.yml` or `trufflehog.yml`; a bare `pull_request:`; `workflow_dispatch:`; caller jobs named for their tool; the shell job's vacuous pass recorded rather than counted; timeouts carried from fosforo with a table waiting for this repository's own measurements. See [CI workflows](./ci-workflows.md).

**Divergence.** The issue's actionlint-without-shellcheck check is resolved upstream for callers of `lint-github-actions.yml` since `cboone/gh-actions` v3.2.0. The issue does not cover duplicate rollup rows from same-named caller jobs, which is filed separately as #432.

### #347 `write-phased-build-plan` (open)

**Phase 0.** The master plan carries `lifecycle: permanent` front matter, and `AGENTS.md` states that it never leaves `docs/plans/`, because neither `commit` 1.3.0 nor `pr` 1.8.4 implements the exemption, and both move a plan from the `docs/plans/` root to `done/` once they judge its work complete. The per-phase plan's shape: decisions, findings, a work table naming skills and commits, a plant table, verification, out of scope. The roadmap table mirrored into the README with a Status column. Milestones and issues filed when each phase is planned.

**Divergence.** The issue describes the master plan as staying in `docs/plans/todo/`. Here it lives at the `docs/plans/` root, and per-phase plans use `todo/`.

## Installed skills

### `bootstrap-project`

Not used as the orchestrator; its component skills were invoked directly, in its documented order. The installed 1.3.1 copy's execution step pointed at `plugins/*/commands/*.md` files that exist nowhere, and invoked skills under names they no longer have, as springer found. Those references were removed in `c459710` (#389, 2026-09-13), the same commit that bumped the plugin to 1.4.0, and #356 added a validator for such cross-references. 1.4.0 was installed here at 23:16 UTC on 2026-09-14, after Phase 0's scaffolding steps had already run, and it has no `commands/` references. The Phase 0 plan's finding that the fix had shipped without a version bump was a misreading of the marketplace checkout. Nothing to file.

### `scaffold-new-repo`

Scoped down: `README.md` and `LICENSE` were left alone, `docs/plans/done/.gitkeep` was skipped because `done/` already held a plan, and the skill's `git add -A` commit was skipped in favour of committing exactly its files.

### `set-up-linters`

Took Prettier, EditorConfig, markdownlint-cli2 and actionlint. Declined cspell, its CI step and its `lint-and-fix` offer.

- typos is offered only on the Rust path, so `typos.toml` and the typos job were written by hand. Tracked as #353.
- Its lint workflow templates put `paths-ignore` for `*.md` and `docs/**` on workflows that run Prettier and markdownlint. Filed as [#431](https://github.com/cboone/agent-harness-plugins/issues/431).

### `set-up-secret-scanning`

Used for both tools and `.gitleaks.toml`. The starter's lockfile allowlist was replaced, and the stale v3.0.0 pins were refreshed as the skill instructs (the templates themselves are tracked by #399). Both templates name the caller job `scan`, duplicating rollup rows; filed as [#432](https://github.com/cboone/agent-harness-plugins/issues/432).

### `lint-and-fix` and `write-markdown`

Replaced in this repository by `npm run format` followed by `npm run lint:md`. `lint-and-fix` passes each detected linter its fix flag, and `write-markdown`'s validation step asks for markdownlint in fix mode, but `markdownlint-cli2 --fix` rewrites every file its globs match and cannot fix `MD060`. Tracked as #358 (consult project agent config before a destructive auto-fix) and #334 (hand table alignment to Prettier).
