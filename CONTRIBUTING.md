# Contributing to savera

This is a single-developer project, and the conventions below exist mostly so its author does the same thing the same way twice. Contributions are welcome anyway.

Please note that this project has a [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold it.

Read [AGENTS.md](AGENTS.md) first. It is the hub document: what the project is, what is settled, what is permanent, and the rules whose omission causes silent damage.

## Reporting Issues

- **Bug reports and feature requests:** use the [issue tracker](https://github.com/cboone/savera/issues). Include the host application and its version, the macOS version, what happened, and what you expected.
- **Security vulnerabilities:** follow [the security policy](.github/SECURITY.md) instead of opening a public issue.

## Settled Decisions

Twenty-three decisions are recorded in [`docs/adr/`](docs/adr/README.md) and are not reopened in review. If one of them is wrong, the way to change it is an amendment or a new ADR that supersedes it, not an edit to the original and not an exception in a pull request.

Several are **refusals**: things the project considered and declined. Savera models a pressure-blown Indian hand harmonium and nothing else, so sample playback, waveguides, the European harmonium and the American reed organ are out of scope by decision ([ADR 0019](docs/adr/0019-a-pressure-blown-indian-harmonium-and-nothing-else.md)). The project is deliberately macOS on Apple Silicon only ([ADR 0001](docs/adr/0001-macos-on-apple-silicon-only.md)). Those are decisions, not gaps.

[The build plan](docs/plans/2026-09-13-savera-build-plan.md) holds the sequencing, the findings behind every decision, and the gate each phase must pass.

## Development Setup

### Requirements

The buildable shell requires Zig 0.16.0, CMake, and clap-validator in addition to the text tools.

- **Node.js 22 or later**, for the text lint tools. `markdownlint-cli2` and `markdownlint-rule-relative-links` both require it, and `.npmrc` sets `engine-strict=true`, so `npm ci` fails at once with `EBADENGINE` on an older runtime. CI runs Node 24.
- **typos**, **actionlint**, **shellcheck**, **shfmt** and **gitleaks**: `brew install typos-cli actionlint shellcheck shfmt gitleaks`. actionlint needs shellcheck on `PATH`, or it skips every `run:` block and still exits 0. CI pins shfmt 3.13.1 and ShellCheck 0.11.0; use those versions when verifying the shell controls.

```bash
npm ci   # Prettier, markdownlint-cli2 and the relative-links rule, at the pinned versions
```

Prettier and markdownlint come from `package.json` and the committed `package-lock.json`, never from Homebrew, so local runs and CI agree on versions and `npm ci` enforces per-package integrity. **Do not run the Homebrew copies**: they are different versions, and a rule difference then shows up only in CI. `package.json` exists for those tools and nothing else; Savera is Zig.

From Phase 1 onward, development also needs Zig 0.16.0 exactly (pinned in `build.zig.zon` as `minimum_zig_version`), CMake for the Audio Unit, and `clap-validator`. Phase 2 adds [`uv`](https://docs.astral.sh/uv/) for the Python harness.

### Checks

Every check below also runs in CI. `npm run format` is the exception: it is the local fixer, which writes files, and CI runs its check form, `npm run format:check`, instead.

```bash
npm run format                     # Prettier writes
npm run format:check               # Prettier checks
npm run lint:md                    # markdownlint, including every relative link and anchor
typos                              # spell check
shellcheck --version && actionlint # the workflows
gitleaks detect --no-banner        # secrets
zig fmt --check build.zig src/     # Zig formatting
zig build test && zig build smoke  # CLAP boundary and host harness
zig build test-safe               # ReleaseSafe unit tests
zig build test-release            # ReleaseFast unit tests
zig build validate                # clap-validator against the direct CLAP
zig build audio-unit               # wrapper-built CLAP and AUv2 component
```

Only `zig build --release=fast install-plugins` copies bundles into the user plugin folders. Before host verification, compare installed hashes and run `scripts/read-provenance --check` on the installed bundles. Release signing reads only `SAVERA_SIGNING_IDENTITY`; unset it for the ad-hoc gate. Packaging and notarization remain Phase 7 work.

### Files that must not be changed

`docs/design/peti-physical-model-brainstorm.md` is the brainstorm the build plan grew from. It is preserved **verbatim**. Prettier and markdownlint both exclude it, and several of its physics claims are corrected in the build plan rather than in the file. Do not format, fix or reword it.

`docs/plans/done/` holds completed plans as historical records. They describe what was intended at the time and may not match what shipped, and they are not updated to match.

`docs/plans/2026-09-13-savera-build-plan.md` is permanent and never moves out of `docs/plans/`.

## Code Style

Prose is one long line per paragraph; the editor handles visual wrapping. `MD013` is off, and Prettier's `proseWrap: preserve` means nothing reflows a paragraph out from under a diff.

Prettier owns layout: tables, YAML and JSON. Run `npm run format` rather than hand-padding table pipes. **Never run `markdownlint-cli2 --fix`**: it rewrites every file its globs match rather than the ones you name, and it cannot fix table alignment anyway.

A word typos flags that is correct goes into `typos.toml` with a comment saying why; see [the linters note](docs/notes/linters.md) for which table it belongs in.

From Phase 1, `zig fmt` is the authority for Zig, and there is no line-length limit.

## Commit Messages and Pull Request Titles

**Commit subjects** use [Conventional Commits](https://www.conventionalcommits.org/):

```text
<type>: <short description>
```

Types in use: `feat`, `fix`, `docs`, `refactor`, `test`, `build`, `ci`, `chore`, `style`.

**Pull request titles** use sentence case with no type prefix:

```text
Establish the repository foundation for Phase 0
```

All commits are GPG signed.

## Pull Request Process

Work the checklist in the pull request template. It lists the checks that exist today and grows a line per phase, so a stale template is itself a review finding.

A phase pull request also moves its phase plan from `docs/plans/todo/` to `docs/plans/done/` and appends that phase's outcomes subsection to the build plan, in the same pull request.

Pull requests are merged with a merge commit, not squashed, so the commits that record a planted defect and its revert survive.

### Branch Naming

`feature/*`, `fix/*`, `docs/*`, `refactor/*`, `test/*`, `chore/*`.
