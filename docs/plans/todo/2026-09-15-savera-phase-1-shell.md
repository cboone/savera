# Savera Phase 1: the shell in both formats

## Context

[The permanent build plan](../2026-09-13-savera-build-plan.md#phases) defines Phase 1 as the first buildable shell: a CLAP instrument with a placeholder sine voice, projected by clap-wrapper into an AUv2 `aumu`. It must prove that Logic sees Savera as a software instrument and can play a key before the Phase 2 reed model makes host integration failures harder to isolate.

The Phase 0 merge left `feature/phase-1` equal to `main` at `eae9cf2`. The repository is an active first-party repository: `origin` is `cboone/savera`, and GitHub reports it is neither archived nor a fork. It has no Phase 1 milestone or issue. The preserved brainstorm hash is `ee012eff0fa93b1ae73dc311e516e1c709ab30b15319bfbfcd0f1bb91ce13529`; `CLAUDE.md` remains a symlink to `AGENTS.md`.

The Phase 1 implementation adapts the established build, CMake, provenance, signing, installation, and validation patterns from `cboone/fosforo`. The changes specific to Savera are its permanent identifiers, an explicit `aumu` wrapper type, and a fixed-capacity sine voice that proves the note and audio paths without pre-implementing the Phase 4 engine.

## Decisions

- Create the Phase 1 milestone and one tracking issue titled “Phase 1: shell in both formats”; the issue’s acceptance criteria are this plan’s gate and plant table.
- Keep the version at `0.0.0`, use Zig 0.16.0, CLAP 1.2.10, and clap-wrapper commit `1cca996e96f29ab2be7ae9f8cfe532bbc92e1dd6` (v0.16.0).
- Build the wrapper input with `b.addObject`, not a static archive. Zig 0.16’s archive alignment behavior is the reason; reconsider this only when the Zig pin changes.
- The direct CLAP and CMake object share one module factory. The direct CLAP exports `clap_entry`; the object exports the three prefixed functions an `entry.cpp` shim needs, so the symbols do not collide.
- Read a release signing identity only from `SAVERA_SIGNING_IDENTITY`. An absent identity produces a fully ad-hoc signature. A supplied identity adds `--timestamp --options runtime`; no signing material enters the repository or CI.
- The sine is a Phase 1 integration fixture. It accepts notes at the plugin boundary, has no parameter or physical-model behavior, stops immediately on note-off, and reports zero tail and latency. Phases 2 through 4 replace it rather than extending it into the final engine.
- Keep the existing text and secret workflows without `paths-ignore`. Replace their reusable shell job with a shebang-discovery job so it covers the new extensionless scripts under `cmake/` as well as `scripts/`.

## Work

### 1. Tracking and phase record

1. Create this plan at `docs/plans/todo/2026-09-15-savera-phase-1-shell.md`, commit it, and create the Phase 1 milestone and issue against the actual post-Phase-0 tree.
2. Keep the permanent build plan at `docs/plans/2026-09-13-savera-build-plan.md`. The final Phase 1 pull request moves only this per-phase plan to `docs/plans/done/` and appends a measured `### Phase 1 outcomes (complete)` subsection to the permanent plan.
3. Use small GPG-signed Conventional Commits for the build foundation, CLAP shell, AU projection and scripts, CI, planted controls, and final outcomes. The plant commits and their direct reverts remain in the merge history.

### 2. Build graph and provenance

1. Add `build.zig.zon` with package name `savera`, version `0.0.0`, `minimum_zig_version = "0.16.0"`, and the exact CLAP 1.2.10 archive plus Zig-generated content hash. Retain the generated manifest fingerprint and package path allowlist; do not add a gitleaks allowlist unless a real manifest finding requires a narrow value.
2. Add `build.zig` as the sole build and task runner. Its module factory builds:
   - `savera_impl`, an object installed for CMake through `addInstallFileWithDir`.
   - A dynamic library, packaged as `zig-out/Savera.clap`, exporting `clap_entry`.
   - The Phase 1 host-harness executable behind `zig build smoke`.
   - Three unit-test artifacts behind `zig build test`, `zig build test-safe`, and `zig build test-release`.
3. Make `zig build` assemble only the direct CLAP in `zig-out`; it must not configure CMake or install plugins. Add macOS-only `audio-unit` and `install-plugins` steps below the non-Darwin guard. The test suite and host-harness stub must build on Linux.
4. Add `src/build_info.zig`. At configure time, run separate `git rev-parse` commands for the branch and short commit and derive dirty state. Supply those values as build options, produce one semver-safe descriptor version and one human-readable `savera-build:` marker, and log the marker from `plugin.init` so optimization cannot discard it.
5. Add `scripts/read-provenance` to extract the longest valid marker from a bundle directory or Mach-O. `--check` must reject absent or malformed markers; `--short` supplies the branch and commit to installation reporting. A unit test embeds the script and verifies its marker prefix still agrees with `src/build_info.zig`.

### 3. CLAP boundary and placeholder host path

1. Add `src/clap/clap_all.h` as the complete Phase 1 header surface: CLAP core, entry and factory, events, audio ports, note ports, state, tail, latency, and host logging. Preprocess it with `zig cc -E -P`, translate the result with `b.addTranslateC`, and expose it only through `src/clap/c.zig`.
2. In `c.zig`, restate object-like macros removed by preprocessing: the CLAP 1.2.10 version, the `instrument` and `synthesizer` feature strings, note-dialect bits, and port-type constants. Add comptime `@sizeOf` and `@offsetOf` checks for every structure crossing the ABI: entry, factory, descriptor, plugin, process, audio buffer, event header and note/MIDI events, input/output event lists, audio and note port info, state, tail, latency, log, and host structures used by a callback.
3. Add `src/main.zig` and `src/clap/plugin.zig` with the permanent descriptor and factory values:
   - CLAP id `com.catamountaudio.savera`; product and display name `Savera`; features `{ instrument, synthesizer }`.
   - One note input port, id `0`, supporting CLAP, MIDI, and MIDI-MPE with CLAP preferred.
   - One main stereo output port, id `0`, producing the same signal on both channels.
   - Extensions for state, tail, latency, and host logging. Phase 3 owns `clap.params`; Phase 4 owns final process statuses, resampling, tail, and latency.
4. Implement a small fixed-capacity sine-voice array in the CLAP layer. It accepts CLAP note events and converted raw MIDI note events, maps MIDI note 69 to 440 Hz, generates finite `f32` dual-mono samples, and clears voices on note-off, reset, and deactivate. It receives no allocator and must not lock or issue syscalls from `process()`.
5. Implement temporary zero latency and zero tail. Retain a clear boundary around this behavior so Phase 4 can replace it with the fixed-internal-rate resampler and physical ring-down policy without changing descriptor or port identity.
6. Add `src/clap/midi.zig` as a pure MIDI 1 parser. Decode note on/off, note-on velocity zero, controller changes, channel pressure, pitch bend, and RPN select/data-entry sequences into normalized engine-facing events. Phase 1 uses only notes for the sine; Phase 3 consumes controller, pressure, bend, and RPN values.
7. Add `src/clap/state.zig` with `SVRA` and a `u32` format version. It writes and validates the empty Phase 1 payload, rejects malformed and truncated headers, and accepts trailing bytes. The Phase 3 payload appends parameter values and CC mappings to this framing.
8. Add the offline host-harness stub as its own executable. It drives a synthetic process block through the plugin boundary, checks finite non-silent dual-mono output while a note is held and silence after release, writes diagnostics to stderr, and reserves exit codes 0 for pass, 1 for an executed failing check, and 2 for invalid invocation.

### 4. CMake projection, bundles, and signing

1. Add `cmake/CMakeLists.txt`, `cmake/entry.cpp`, and `cmake/entry.h`. Fetch clap-wrapper at the pinned commit, set macOS 11.0 and C++17 before it configures, enable wrapper dependency downloads, and configure only CLAP and AUv2 output.
2. Run `zig build --release=fast --prefix build/zig impl` from CMake, link the generated `savera_impl` object, and keep all CMake products below `build/`. Make the combined wrapper target the only audio-unit build target so the component and the wrapper-built CLAP are both current.
3. Pass the permanent Audio Unit metadata explicitly: bundle identifier `com.cboone.savera`, manufacturer `Catamount` / `Ctmn`, subtype `Svra`, and `AUV2_INSTRUMENT_TYPE "aumu"`. At CMake configuration time, compare the wrapper-resolved header version with the CLAP 1.2.10 version in `build.zig.zon`.
4. Add `macos/Info.plist` for the Zig-built CLAP: `Savera`, `com.cboone.savera`, version `0.0.0`, and `LSMinimumSystemVersion` 11.0. Keep the deployment target consistent in `build.zig`, CMake, and this plist; packaging enters in Phase 7.
5. Add `cmake/narrow-au-resource-usage` and `cmake/set-au-display-name`, adapting the Fosforo scripts for Savera. The first removes clap-wrapper’s incompatible `resourceUsage` claims while asserting `sandboxSafe`; the second sets `Catamount: Savera` and “A physically modelled Indian hand harmonium.” Both support `--check`.
6. Register the two plist rewrites after clap-wrapper’s own post-build work and before signing. Sign bundles last with `/usr/bin/codesign`; ad-hoc is the default, and a real environment-supplied identity adds only the required timestamp and hardened-runtime options.
7. Add `scripts/build-audio-unit`, `scripts/assert-adhoc-signature`, and `scripts/install-plugins`. Build scripts use Bash 3.2-compatible strict mode and distinguish invalid arguments, missing artifacts, and validation failures with documented exit codes. The installer alone writes to `~/Library/Audio/Plug-Ins/CLAP` and `~/Library/Audio/Plug-Ins/Components`, installs the Zig-built CLAP plus the wrapper-built component, and prints a hash and provenance for each destination.
8. Add `zig build validate` for the direct CLAP, `zig build audio-unit` for CMake projection, and `zig build install-plugins` for the exact artifacts it copies. The latter builds both formats before calling the one installer implementation.

### 5. CI and shell coverage

1. Add `.github/workflows/ci.yml` with bare `pull_request`, pushes to `main`, `workflow_dispatch`, concurrency cancellation, and read-only permissions. Its `paths-ignore` excludes only documentation, licensing, and agent-configuration changes because all of its jobs are build or bundle checks.
2. Call `cboone/gh-actions` v3.2.0 at `0d53592f40b487f01b26b374e539c517fa9c570f` for the macOS Zig workflow. Pass `build.zig.zon` as the toolchain source, use `macos-latest`, disable cross-compilation, and carry an eight-minute timeout until Phase 1 run measurements replace it.
3. Add an Ubuntu job using the Zig version from `build.zig.zon`; run `zig build test`, `zig build test-safe`, `zig build test-release`, and `zig build smoke` there to enforce the non-Darwin build path and execute the host-harness stub.
4. Add macOS jobs for `test-safe` and `test-release`, the host-harness stub, and the bundle gate. The bundle gate installs clap-validator 0.4.1 at commit `152b9823e992d782c5c1fd33bca0295478b919aa` with Rust 1.97.1 through the released `set-up-clap-validator` composite action, validates both CLAP bundles, extracts the component’s `AudioComponents.0.type`, runs both plist scripts in check mode, verifies every bundle’s ad-hoc signature, and reads every provenance marker.
5. Replace `text-lint.yml`’s reusable `shell` caller with an inline Ubuntu job. It installs and reports pinned shfmt 3.13.1 and ShellCheck 0.11.0, discovers tracked shell files by shebang with `git ls-files -z | xargs -0 shfmt -f`, then runs `shfmt -d` and `shellcheck` over exactly that list. This job retains no `paths-ignore`, so an `.editorconfig` profile change is checked.
6. Preserve the current workflow guarantees: full-SHA pins with version comments, no `paths-ignore` in text or secret workflows, a bare `pull_request:`, and actionlint run with ShellCheck on `PATH`.

### 6. Documentation and review surface

1. Update `AGENTS.md`, `README.md`, `CONTRIBUTING.md`, the PR template, `.github/zig.instructions.md`, and `.github/actions.instructions.md` to replace pre-Phase-1 future tense with the buildable-shell commands and controls.
2. Update `docs/notes/ci-workflows.md`, `docs/notes/linters.md`, and `docs/notes/skill-deviations.md` with the actual validator setup, CMake and shell discovery behavior, current skill deviations, and measured CI results. Update `.claude/settings.json` only with narrow read-only checks newly introduced by the phase.
3. Before the final documentation commit, recheck the preserved brainstorm hash, the `CLAUDE.md` symlink, and the `AGENTS.md` size limit. Do not format, reword, or otherwise change `docs/design/`.

## Public interface created in Phase 1

- A CLAP descriptor with the permanent Savera identity, two permanent features, one permanent note input port, and one permanent stereo output port.
- A CLAP state envelope beginning with `SVRA` and a `u32` format version, with no payload fields yet.
- Build commands: `zig build`, `zig build test`, `zig build test-safe`, `zig build test-release`, `zig build smoke`, `zig build validate`, `zig build audio-unit`, and `zig build install-plugins`.
- Script interfaces: `build-audio-unit [--reconfigure]`, `read-provenance [--check] [--short] <path>...`, `assert-adhoc-signature <bundle>...`, and the two plist scripts’ `[--check] <Info.plist>` form.
- The smoke executable returns 0 for success, 1 for an executed failing check, and 2 for invalid arguments. Shell usage errors return 64, malformed metadata or build/signature validation failures return 65, and missing input artifacts return 66. External tool failures may propagate their own status through the installer.

## Plant table

| Planted defect                                          | Instrument expected to catch it  | What actually happened                                                                                                                                                                                 | Test that covers it now                                      |
| ------------------------------------------------------- | -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------ |
| Change an asserted CLAP ABI field offset                | The ABI layout unit test         | `0867f63`: expected MIDI `data` offset changed from 18 to 19; named `data ABI offset mismatch` assertion rejected compilation, exit 1; direct revert `21ef619`                                         | `assertAbi` size and offset assertions in `src/clap/c.zig`   |
| Change `features[0]` from `instrument`                  | The descriptor-feature unit test | `400f66a`: the named descriptor test reported `instrument` versus `synthesizer`, 8/9 tests passed, exit 1; direct revert `3a2df7a`                                                                     | `the permanent descriptor begins with instrument`            |
| Change `AUV2_INSTRUMENT_TYPE` from `aumu`               | The CI plist-type extraction     | `eb3b8a7`: wrapper build passed; [CI 35121186925](https://github.com/cboone/savera/actions/runs/35121186925) extracted `aufx` and the named type assertion failed with exit 1; direct revert `d3b6bbe` | Bundle-gate extraction of the emitted component type         |
| Add an SC2086 defect to an extensionless tracked script | The `text-lint.yml` shell job    | `e8866e1`: [CI 35121659836](https://github.com/cboone/savera/actions/runs/35121659836) reported SC2086 at `cmake/set-au-display-name:17`, exit 123 from `xargs`; shfmt passed; direct revert `75a617a` | Tracked-tree shebang discovery followed by pinned ShellCheck |

Before planting, commit the corresponding control and verify the clean head. Plant one defect at a time from a clean worktree, identify the named assertion or CI step rather than a neighboring failure, record the observed result in this table, and immediately commit a direct revert. No secret-shaped plant is ever committed.

## Verification

1. Run `npm ci`, then `npm run format:check` and `npm run lint:md`; run `typos`, `shellcheck --version && actionlint`, and `gitleaks detect --no-banner`.
2. On macOS, run `zig fmt --check build.zig src/`, `zig build`, `zig build test`, `zig build test-safe`, `zig build test-release`, `zig build smoke`, and `zig build validate`. On Linux, run `zig build test`, `zig build test-safe`, `zig build test-release`, and `zig build smoke`, matching the CI coverage of the supported non-Darwin path.
3. Run `scripts/build-audio-unit`, then validate `build/assets/Savera.clap`; extract `AudioComponents.0.type` from `build/assets/Savera.component/Contents/Info.plist`; run both plist scripts with `--check`; run `scripts/assert-adhoc-signature` and `scripts/read-provenance --check` over every produced bundle.
4. Complete all four plant rows, rerun the full clean-tree gate, and record run URLs, tool versions, job durations, and plant results in the phase outcomes.
5. Perform the Logic gate after `zig build --release=fast install-plugins` and a matching installed-bundle provenance check:
   - **Setup:** Open a new Logic software-instrument track after the installed CLAP and component hashes and provenance match the build under test.
   - **Action:** Locate `Catamount: Savera` in the software-instrument list, insert it, then play and release a MIDI key.
   - **Expected:** Logic lists Savera as an instrument; plugin initialization logs the installed provenance; a sine is audible on both channels while held and stops on release.
   - **Null versus broken:** An absent instrument or an effect-only listing points to AU type or registration; an inserted plug-in with no audible note points to the wrapper note/audio path or `process()`.
6. Treat `auval` invisibility as expected clap-wrapper behavior, not a failed gate. If the Logic gate fails after the bundle controls are green, do not mark Phase 1 complete: record the result, file the Savera issue, and report any likely third-party wrapper defect without writing upstream.

## Automated verification results

The clean implementation at `1de6a7f` passed [build and bundle CI 35122242123](https://github.com/cboone/savera/actions/runs/35122242123), [text/shell/workflow CI 35122242236](https://github.com/cboone/savera/actions/runs/35122242236), and [gitleaks CI 35122242128](https://github.com/cboone/savera/actions/runs/35122242128). Linux ran all three unit modes and smoke. macOS ran all three modes, smoke, both CLAP validators and the full AU metadata/signature/provenance gate. The measured final job durations were Linux 113 seconds, macOS release tests/smoke 47 seconds, and bundles 75 seconds. TruffleHog completed but its known non-failing configuration is not coverage.

The local clean gate at the same commit passed ten tests per mode, thirty across Debug, ReleaseSafe and ReleaseFast, plus the functional CLAP/MIDI smoke harness. clap-validator 0.4.1 reported 88 tests across both bundles: 46 passed, none failed or warned, and 42 skipped because Phase 1 has no GUI, parameters or presets. Local text formatting, Markdown links/lint, typos, ShellCheck, shfmt, actionlint and gitleaks passed. Zig was 0.16.0, CMake 4.4.3, ShellCheck 0.11.0, and the checksum-verified shfmt executable was 3.13.1; text tools came from `npm ci` and the committed lockfile.

Ad-hoc bundles from `1de6a7f` were installed on 2026-09-16. Both source/installed binary pairs have matching SHA-256 hashes:

| Format      | Source and installed binary SHA-256                                |
| ----------- | ------------------------------------------------------------------ |
| Direct CLAP | `254d9275076322997a892cb16119237c0ee933ededfb698f2b98bef28bad962f` |
| Audio Unit  | `85eb2456473dd4ff0aee955bed315437a9c9627e764c7fc4aeb2c65d2c945dd8` |

All three built bundles and both installed bundles passed ad-hoc signature and provenance checks, reporting `branch=feature/phase-1 commit=1de6a7f dirty=false version=0.0.0`. The four plants and direct reverts are recorded above. `AGENTS.md` measured 6,028 bytes; the global instructions measured 8,154 bytes, and the largest complete global/root/nested chain measured 15,609 bytes, within 32 KiB. All three `CLAUDE.md` aliases remained symlinks to their paired files, and the preserved brainstorm hash remained unchanged.

Logic playback is pending. The phase plan remains in `todo/`, Phase 1 remains active, and [PR #4](https://github.com/cboone/savera/pull/4) remains draft until manual steps 0 through 2 pass. A subsequent documentation-only commit records these readings; the installed build under test remains `1de6a7f`.

## Manual verification

### Exclusive resources

`~/Library/Audio/Plug-Ins/Components/Savera.component`, `~/Library/Audio/Plug-Ins/CLAP/Savera.clap`, and `Logic Pro` are needed for steps 0 through 2. Do not install Savera from another worktree during this session. The automated build, test, validator and planted controls need no host application.

### 0. Confirm the installed build

- **Setup:** The clean automated gate passes for the commit under test. Close any existing Savera instances before installing.
- **Action:** Run `zig build --release=fast install-plugins`. Compare SHA-256 hashes of each source binary and its installed binary. Run `scripts/read-provenance --check` on both installed bundles. Restart Logic after installation and retain the `savera-build:` initialization message from its host log if available.
- **Expected:** Source and installed hashes match for both formats. Both markers name `feature/phase-1`, the commit under test, and `dirty=false`. Logic starts after that installation. A host initialization log, when available, agrees with the installed marker.
- **Null versus broken:** A syntactically valid marker from another commit is not confirmation. Without a host log, restarting Logic after installation and matching installed hashes is the weaker confirmation; record it explicitly.
- **Why by hand:** Only the running host determines which registered Audio Unit instance it loads.
- **Result:** partial. 2026-09-16, installed build `1de6a7f`: both source/installed binary hashes match the table above, signatures pass, and both markers report the same clean build. Logic restart and running-host confirmation await the playback report.

### 1. Insert Savera as a software instrument

- **Setup:** Step 0 passed in this session. Open a new Logic project and add a software-instrument track.
- **Action:** Find `Catamount: Savera` in the track's instrument menu and insert it.
- **Expected:** Savera appears in the software-instrument menu and inserts into the instrument slot without a load error.
- **Null versus broken:** An absent entry or an entry available only as an effect fails this gate, even if the generated plist says `aumu`. Do not infer success from `auval`, whose invisibility is expected for this wrapper.
- **Why by hand:** The bundle gate reads metadata; Logic's registration and instrument-slot loading are separate observations.
- **Result:** pending. Record Logic version, macOS version, confirmed commit, and the observed menu/slot behavior.

### 2. Play and release a MIDI key

- **Setup:** Step 1 passed. The Savera track is selected, its output is audible, and its stereo meters are visible. Use a MIDI keyboard or Logic's Musical Typing.
- **Action:** Hold a key, release it, and repeat with a second key.
- **Expected:** A sine sounds while each key is held, with signal on both stereo channels. Each release stops the note immediately; the repeated key also produces sound.
- **Null versus broken:** Silence after release passes only when sound and stereo meter activity were observed immediately before release. An inserted but silent instrument, one inactive channel, or a continuing released note fails.
- **Why by hand:** The standalone smoke harness does not exercise Logic's MIDI routing, clap-wrapper's Audio Unit bridge, or Logic's audio output.
- **Result:** pending. Record the held-note sound, both-channel meter activity, release silence and repeated-note observation against the same build.

## Out of scope

- The Phase 2 Python oracle, renderer, physical reed, source seam canary, and calibration corpus.
- Phase 3 parameters, CC learning, state payload fields, and `clap.params`.
- Phase 4 voices, event splitting, resampling, final process status, physical tail, and latency.
- GUI, presets, packaging, notarization, and release distribution.
