# CI workflows

What runs on a push or a pull request, what each job actually judges, and the conventions every workflow here follows. The tools themselves are in [Linters](./linters.md).

## The workflows

| Workflow         | Job          | Rollup rows                                               | What it judges                                                                                                                    |
| ---------------- | ------------ | --------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `text-lint.yml`  | `text`       | `text / Text lint`                                        | markdownlint with the relative-links rule, then Prettier over every supported file type, which is skipped when markdownlint fails |
| `text-lint.yml`  | `shell`      | `shell / Shell lint`                                      | shellcheck and shfmt over discovered shell scripts; finds none before Phase 1                                                     |
| `text-lint.yml`  | `actions`    | `actions / actionlint`                                    | actionlint over every workflow, with a pinned shellcheck for `run:` blocks                                                        |
| `text-lint.yml`  | `typos`      | `typos`                                                   | typos over the tracked tree                                                                                                       |
| `gitleaks.yml`   | `gitleaks`   | `gitleaks / Validate inputs`, `gitleaks / gitleaks`       | gitleaks over the full history, with `.gitleaks.toml`, which it discovers in the source directory without `allowlist-config`      |
| `trufflehog.yml` | `trufflehog` | `trufflehog / Validate inputs`, `trufflehog / trufflehog` | TruffleHog over the full history. **Cannot fail**; see below                                                                      |

`ci.yml` reads Zig 0.16.0 from `build.zig.zon`. Its Linux job runs the three test modes and the smoke harness without describing CMake; its macOS reusable job builds the direct CLAP. Bundle validation remains a macOS local gate until its dedicated CI job lands.

## Conventions every workflow follows

**No `paths-ignore` on any workflow that judges text or secrets.** A check must not be able to skip the change that governs it: `typos.toml`, `.markdownlint-cli2.jsonc`, `.prettierrc.json`, `.prettierignore`, `.gitleaks.toml` and the workflow files all live in the set these jobs read, and nearly every change before Phase 1 is a Markdown change. `paths-ignore` is workflow-level, so no job can be exempted from it. `ci.yml` will carry `paths-ignore` for documentation, correctly, because it is a set of macOS builds; that is why a text check never becomes a job in it.

**A bare `pull_request:`.** A `branches:` filter matches the base ref, so a pull request stacked on another feature branch would run none of the workflow and show nothing wrong.

**`workflow_dispatch:` on every workflow**, as an escape hatch for re-running a check without pushing. It can only be dispatched once the workflow exists on `main`.

**Caller jobs are named for what they check.** A reusable workflow's rows are `<caller job> / <inner job>`, so two callers with the same job name produce indistinguishable rows. `set-up-secret-scanning`'s templates name both callers `scan`, which duplicates the `Validate inputs` row; that is filed as [cboone/agent-harness-plugins#432](https://github.com/cboone/agent-harness-plugins/issues/432).

**Every `uses:` is pinned to a full commit SHA with a version comment.** Dependabot moves the SHA and the comment together.

**Ubuntu, unless a job needs macOS.** These are platform-independent static analysis, and the macOS runner bills at ten times the rate.

**No job or run counts in prose about CI.** A declared job is not a rollup entry and reusable workflows expand into several, so any count goes stale on the next workflow edit. Anchor a measurement to a run id, or leave it out.

## The pinned `cboone/gh-actions` release

Every reusable call, and the `install-pinned-tool` action, is pinned to v3.2.0 at `0d53592f40b487f01b26b374e539c517fa9c570f`, released 2026-09-14. What matters about that release here:

- **v3.1.1 fixed `lint-text.yml`** ([cboone/gh-actions#83](https://github.com/cboone/gh-actions/issues/83)). At v3.0.0 it read a context value that is always empty and failed before any linter ran, which is why springer inlined its text job. This repository calls it.
- **v3.2.0 made `lint-github-actions.yml` install a pinned shellcheck** and report both tool versions ([cboone/gh-actions#85](https://github.com/cboone/gh-actions/issues/85)). Before that, a runner without shellcheck made actionlint skip every `run:` block and exit 0. The `Report tool versions` step in the `actions / actionlint` log is the positive control that shellcheck was there.
- **v3.2.0 added `install-pinned-tool`** ([cboone/gh-actions#87](https://github.com/cboone/gh-actions/issues/87)), which the `typos` job uses in place of a hand-written download and checksum step.
- **`lint-shell.yml` still discovers extensionless scripts only under `bin/`, `scripts/` and `script/`** ([cboone/gh-actions#86](https://github.com/cboone/gh-actions/issues/86)).

## The TruffleHog job cannot fail

`scan-for-secrets.yml` at v3.2.0 runs `trufflehog git file://. --results=verified,unknown` with no `--fail`, and TruffleHog exits 0 whenever `--fail` is absent, including when it reports a finding. Measured on 2026-09-14 on a throwaway local repository holding a committed AWS-shaped key pair, with TruffleHog 3.95.2, the version `scan-for-secrets.yml` v3.2.0 installs by default (release asset checksum-verified), and again with 3.97.4, which gave identical results:

| Invocation                                                             | Output                           | Exit |
| ---------------------------------------------------------------------- | -------------------------------- | ---- |
| `trufflehog git file://. --results=verified,unknown`                   | nothing                          | 0    |
| `trufflehog git file://. --results=verified,unverified,unknown`        | `Found unverified result`, `AWS` | 0    |
| `trufflehog git file://. --results=verified,unverified,unknown --fail` | the same                         | 183  |

So `trufflehog / trufflehog` is green on every run whatever it finds, and it also never reports an unverified result. It is not counted as coverage. gitleaks is the secret check that can fail: `gitleaks detect` exits 1 on a finding, and the Phase 0 plants confirmed it flags a planted key. Filed upstream as [cboone/gh-actions#111](https://github.com/cboone/gh-actions/issues/111); fosforo and springer call the same workflow and share the gap. When a release fixes it, bump the pin and plant against the job.

## The shell job passes by finding nothing

Before Phase 1 there are no shell scripts, so `shell / Shell lint` finds none, skips every later step, and succeeds. That is a vacuous pass, recorded as such rather than counted as coverage. Phase 1 adds extensionless scripts under `cmake/`, which `lint-shell.yml`'s discovery would also miss, and switches to discovery by shebang over the tracked tree:

```bash
git ls-files -z | xargs -0 shfmt -f | xargs -r shellcheck
```

## Timeouts

Every timeout was carried from fosforo when the workflows landed. They are ceilings, not predictions. The last column is the longest job duration, from start to completion, over this repository's two clean-tree runs so far: text-lint runs 34915386623 and 34915723980, gitleaks runs 34915386624 and 34915723892, and TruffleHog runs 34915386601 and 34915723956, all on PR #1 on 2026-09-14. Two runs justify keeping the carried ceilings, not lowering them; re-measure over more runs before changing one.

| Job          | Timeout (minutes) | Source                                                              | Measured here, longest of 2 runs |
| ------------ | ----------------- | ------------------------------------------------------------------- | -------------------------------- |
| `text`       | 5                 | fosforo's floor of 3, plus room for `npm ci` of the whole tool tree | 15 seconds                       |
| `shell`      | 3                 | fosforo's Ubuntu static-analysis floor                              | 6 seconds, finding nothing       |
| `actions`    | 3                 | fosforo's Ubuntu static-analysis floor                              | 6 seconds                        |
| `typos`      | 3                 | fosforo's typos job, 14 seconds at most over its first 27 runs      | 6 seconds                        |
| `gitleaks`   | 3                 | fosforo's gitleaks job, 24 seconds at most over 29 runs             | 6 seconds                        |
| `trufflehog` | 3                 | fosforo's TruffleHog job, 53 seconds at most over 28 runs           | 10 seconds                       |

For the reusable calls the timeout is a `timeout-minutes` input, not a job key, because the job belongs to the reusable workflow. Since gh-actions v3.2.0, `scan-for-secrets.yml` applies it to its `Validate inputs` job as well.

## What a pull request can change about its own checks

Every check here runs on `pull_request`, and for that event GitHub runs the workflow definitions and reads the configuration from the pull request's own merge commit. So a pull request can change what judges it: it can add a path to `.gitleaks.toml`'s allowlist, a word to `typos.toml`, an entry to `.prettierignore` or `.markdownlint-cli2.jsonc`, or edit or delete a workflow outright, and the checks it leaves standing will pass.

Sourcing one config from the base branch would not close that, because the same pull request could remove the job that reads it. `pull_request_target` would, but it runs with the base repository's permissions against untrusted code, which is the more dangerous trade. The control is review: a change to any file under `.github/workflows/`, or to `.gitleaks.toml`, `typos.toml`, `.prettierignore`, `.markdownlint-cli2.jsonc` or `.prettierrc.json`, is a change to a gate, and it gets read as one. Raised by Copilot's review of PR #1 on 2026-09-14 for `.gitleaks.toml`. If the project ever takes outside contributions, CODEOWNERS on those paths with required review is the mechanical form of the same control.

## Moving a pin

- **Actions and reusable workflows:** Dependabot opens the pull request weekly. Before accepting a `cboone/gh-actions` bump, read the release notes for inputs that changed default behaviour.
- **The npm tools:** Dependabot bumps the exact pins with `versioning-strategy: increase`. A markdownlint-cli2 bump can change findings with no change on this side, because its rules ship inside that tree, so run `npm ci` and `npm run lint:md` on the branch.
- **typos:** Dependabot cannot see the `version` and `checksum` inputs in `text-lint.yml`. Bump both together, taking the SHA-256 with `shasum -a 256` on the `x86_64-unknown-linux-musl` release asset, and confirm the archive member is still `./typos`. `upgrade-everything` finds this drift.

## Dependabot

`.github/dependabot.yml` covers the `github-actions` and `npm` ecosystems, weekly, with minor and patch updates grouped and majors opened individually. The individual majors come from having no major group at all: a group whose pattern matches every major update collects them into one pull request, which is what fosforo's config, the model for this one, actually does despite its comment saying otherwise. Dependabot reads that file only from the default branch, so it takes effect after the pull request that adds it merges. From Phase 1 it will not see anything pinned in `build.zig.zon`, for which it has no ecosystem.
