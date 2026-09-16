# savera

## Overview and state

Savera is a modulatable synthesizer modeling a pressure-blown Kolkata-style Indian hand harmonium (peti), authored in Zig as a CLAP instrument and wrapped as an AUv2 for macOS. Physical realism comes from the acoustics literature and recordings; every per-sample physical quantity is exposed for modulation. Product/display spelling is `Savera`; repository and files use ASCII `savera`.

The foundation is complete. Phase 1 adds a buildable CLAP and AUv2 shell with a placeholder sine; its planted controls and Logic instrument gate determine completion. The permanent [build plan](docs/plans/2026-09-13-savera-build-plan.md) owns sequencing, source layout, findings, verification and phase outcomes. It never leaves `docs/plans/`. Per-phase plans use `todo/` and move to `done/` when their PR merges.

## Settled constraints

Read the relevant [ADRs](docs/adr/README.md) before implementation. Supersede decisions with an amendment or a new ADR; do not relitigate them in review.

- macOS on Apple Silicon only; Zig 0.16.0 is pinned in `build.zig.zon`, and CI reads that source. Author CLAP once and wrap outward; pass AU type `aumu` explicitly and verify the built plist.
- Generate CLAP bindings with `translate-c` after `zig cc -E -P`, with comptime layout assertions. `src/model/` names no CLAP types, sample offsets or note IDs. Preserve the CLAP source walk and review the other boundaries.
- No WebView UI. Nothing reachable from the audio thread allocates, locks or makes syscalls. Derive capacities centrally; use single-writer relaxed atomics drained on the main thread for cross-thread state.
- Stable `clap_id` identifies parameters. Declare rescan-gated ranges, flags, note dialects and channel counts before the first release. Heard equals value plus modulation across internal, host, per-note and CC-learn sources.
- Preserve the single-mode reed seam with solver sensitivities; fixed-K bracketed Newton solves near-field pressure, then chamber/reservoir updates are explicit. Run the model at a fixed internal rate and resample to the host rate.
- A spring-loaded reservoir feeds sealed bank chambers with downstream pallets; no in-rank coupling. Keys are continuous valves, with velocity affecting opening rate and key noise only. Output is total reed-flow derivative through an enclosure filter, a monopole source on both stereo channels.
- Continuous pitch follows a cantilever-scaled reed family. Model the pressure-blown Indian harmonium only: no sample playback or waveguide. Python discovers the single reed and freezes as its oracle; downstream modeling is Zig only.
- Harnesses have their own executable build steps, never `zig build test`. GUI work is deferred; parameters are the interface.
- Releases are one signed, notarized, stapled `.pkg`, built locally, never in CI. Stamp build branch, commit and dirty state without changing permanent plugin identity.

## Permanent identifiers

Preserve product/display `Savera`; CLAP ID `com.catamountaudio.savera`; bundle identifier `com.cboone.savera`; AU type `aumu`, subtype `Svra`, manufacturer `Ctmn` / `Catamount`; state magic `SVRA`; preset provider `com.catamountaudio.savera.presets`. CLAP features are `instrument` first, then `synthesizer`. One note input (ID `0`) prefers CLAP and supports MIDI/MIDI-MPE; one audio output (ID `0`) has two channels. Document permanent identity at declaration sites when implementing.

## Rules

- After `commit` or `pr` skills, confirm the permanent build plan remains at `docs/plans/2026-09-13-savera-build-plan.md`. Read [skill deviations](docs/notes/skill-deviations.md) before manually substituting for a catalog skill.
- Preserve `docs/design/` verbatim. Never format, fix or reword the brainstorm. If typos flags a word there, document an allowlist entry in `typos.toml`; do not edit the source.
- Run `npm ci` before text checks, Prettier before markdownlint, and never markdownlint-cli2 `--fix`. Its configured globs can rewrite unrelated files. Do not use `lint-and-fix` here. Read [linters](docs/notes/linters.md).
- Text and secret workflows never get `paths-ignore`. A check that finds no inputs is not coverage; actionlint needs shellcheck, and the recorded TruffleHog workflow lacks a failing secret gate. Read [CI workflows](docs/notes/ci-workflows.md) before editing `.github/`, including Dependabot, or interpreting checks.
- Nothing under `verification/` is committed except `.gitkeep`; purchased libraries forbid redistribution. Committed reference audio is CC0 under `fixtures/`.
- Never commit secret-shaped strings, even planted samples. Plant secret-scanner controls only in untracked files.
- Completed plans are historical; never update their figures, citations or line numbers. Notes are living. When correcting a measured value, search its old value across current docs and code while respecting historical records.

## Development

The npm package pins text tools and is not part of the Zig build. Default signing is ad-hoc; release signing reads only `SAVERA_SIGNING_IDENTITY`. Building stays inside the worktree; only `install-plugins` copies to the user's plugin folders.

```bash
npm ci
npm run format
npm run format:check
npm run lint:md
typos
shellcheck --version
actionlint
gitleaks detect --no-banner
zig fmt --check build.zig src/
zig build
zig build test
zig build test-safe
zig build test-release
zig build smoke
zig build validate
zig build audio-unit
zig build --release=fast install-plugins
```

Read the applicable scoped file before editing its directory, including from a root session:

- [docs/AGENTS.md](docs/AGENTS.md): ADRs, permanent plan, preserved design, living notes and instruction maintenance.
- [.github/workflows/AGENTS.md](.github/workflows/AGENTS.md): pinned tooling and the distinction between configured checks and demonstrated coverage.

Keep root instructions concise, specialized details in their canonical documents, and all global/root/nested chains within 32 KiB. Preserve every `CLAUDE.md -> AGENTS.md` pair.
