<!-- markdownlint-disable MD041 -->

## Description

<!-- Describe your changes -->

## Related Issue

<!-- Link to the issue this PR addresses -->

Fixes #

## Type of Change

- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to change)
- [ ] Documentation update

## Checklist

The checks below are the ones that exist today. Each phase adds its own lines as it lands, so this list is a running record of the verification program rather than boilerplate.

- [ ] I have read the [CONTRIBUTING](https://github.com/cboone/savera/blob/main/CONTRIBUTING.md) guide
- [ ] I ran `npm ci`, then `npm run format:check` and `npm run lint:md` are both clean (never `markdownlint-cli2 --fix`)
- [ ] The spell check passes (`typos`)
- [ ] `gitleaks detect --no-banner` reports no leaks (the TruffleHog CI job cannot fail, so gitleaks is the secret check that counts)
- [ ] If I touched anything under `.github/workflows/`, `actionlint` is silent, run with `shellcheck` on `PATH`
- [ ] If I touched a shell script, `shfmt -d` and `shellcheck` are both silent
- [ ] If I touched Zig, `zig fmt --check build.zig src/`, `zig build test`, and `zig build smoke` are clean
- [ ] `docs/design/` is byte-identical: `git diff --exit-code origin/main -- docs/design/` prints nothing
- [ ] `AGENTS.md` is under 30,000 characters (`wc -c AGENTS.md`) and `CLAUDE.md` is still a symlink to it
- [ ] The build plan is still at `docs/plans/2026-09-13-savera-build-plan.md`
- [ ] For a phase pull request: the phase plan moved to `docs/plans/done/`, and the build plan gained that phase's outcomes subsection
- [ ] I have updated CHANGELOG.md if this is a user-facing change
- [ ] If this changes a settled architecture decision, I have added an amendment or a superseding ADR in `docs/adr/`
