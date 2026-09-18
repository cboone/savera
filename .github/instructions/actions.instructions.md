---
applyTo: ".github/workflows/*.yml,.github/dependabot.yml"
---

# Reviewing this project's workflows

For repo-wide conventions, see [`copilot-instructions.md`](copilot-instructions.md) and `AGENTS.md` at the repository root.

Most of what looks like a defect in these files is a deliberate convention, and several of the facts below were measured rather than assumed. The depth is in `docs/notes/ci-workflows.md`.

- **Every `uses:` is pinned by commit SHA with a trailing `# vX.Y.Z` comment**, org-controlled `cboone/gh-actions` refs included. Do not suggest replacing the SHA with the tag; the comment is what makes the pin readable, not a substitute for it.
- **`text-lint.yml`, `gitleaks.yml` and `trufflehog.yml` carry no `paths-ignore`, and that is the point.** A check must not be able to skip the change that governs it: the lint configs and the workflows themselves live inside the set these jobs read, and nearly every change before Phase 1 is a Markdown change. Do not suggest adding `paths-ignore` to them. The build workflow arriving in Phase 1 _will_ carry one, correctly, because it is a set of macOS builds.
- **`pull_request:` is bare on purpose.** A `branches:` filter matches the base ref, so a pull request stacked on another branch would run none of the workflow. Do not suggest adding one.
- **Caller jobs are named for their tool, not a generic `scan` or `check`.** A reusable workflow's rows are prefixed by the caller job name, and two callers sharing a name produce indistinguishable rows. Do not suggest renaming them to match a template.
- **The `text` job calls `lint-text.yml` with `use-consumer-versions: true` on purpose.** It installs Prettier, markdownlint-cli2 and the relative-links rule from this repository's lockfile, which is what lets the custom markdownlint rule resolve and makes local and CI versions agree.
- **Flag a pull request that changes a gate's own configuration, but do not suggest sourcing one config from the base branch as the fix.** On `pull_request`, GitHub runs the workflows and reads `.gitleaks.toml`, `typos.toml` and the lint configs from the pull request's merge commit, so the same pull request that could loosen `.gitleaks.toml` could delete the gitleaks job. Pinning one config to the base branch does not close that, and `pull_request_target` runs untrusted code with base permissions. What helps is naming the loosened gate in the review, so a changed allowlist, ignore list or workflow is read as a change to a check. See `docs/notes/ci-workflows.md`.
- **`gitleaks.yml` does not pass `allowlist-config`, and `.gitleaks.toml` is still used.** gitleaks loads `.gitleaks.toml` from the scanned source directory when no `--config` is given, so the repository's allowlist applies without the input. Measured on 2026-09-14 with gitleaks 8.30.1: a scan of this repository with no `--config` suppressed a planted key under `fixtures/` while still flagging the same key elsewhere. Do not suggest adding `allowlist-config` as a fix for an unused config.
- **The typos job pins a version and a SHA-256 together, deliberately.** A release asset can be replaced in place under the same tag, and typos ships its dictionary inside the binary. Do not suggest dropping the checksum as redundant, and do not suggest `latest`.
- **`archive-member: ./typos` is exact, and the leading `./` is correct.** It is the member exactly as `tar -tf` lists it, and GNU tar treats `./typos` and `typos` as different members. The asset is verified before extraction, so naming one member is stricter than searching the archive, not riskier.
- **The shell job discovers tracked scripts by shebang**, including extensionless scripts under `cmake/`. Its pinned shfmt and ShellCheck checks must use that discovered list.
- **Timeouts are carried from fosforo and marked unmeasured.** Do not suggest lowering or raising them without a measured run.
- **`package.json` exists for the text lint tools only.** This is a Zig project, not a Node one. Do not suggest removing the manifests, adding application dependencies, or treating it as JavaScript.
- **`ci.yml` reads its Zig toolchain from `build.zig.zon`.** The macOS bundle gate validates both CLAP bundles and checks the emitted AU type, plist rewrites, signatures and provenance. Linux checks the non-Darwin test and host-harness path.
- **Jobs run on `ubuntu-latest` unless they need macOS.** This is platform-independent static analysis, and the macOS runner bills at ten times the rate. Do not suggest matrixing these jobs across operating systems.
