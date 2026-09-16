# CI workflow instructions

Read [CI workflows](../../docs/notes/ci-workflows.md) before modifying checks, dependency pins, timeouts or triggers, and [linters](../../docs/notes/linters.md) before changing tool invocations. The CI note also governs Dependabot changes in the parent directory.

- No text- or secret-check workflow gets `paths-ignore`.
- Use the committed npm lockfile and install before text checks. Prettier checks formatting in CI; its write mode is the local fixer. Never use markdownlint-cli2 `--fix` here.
- Keep shellcheck on `PATH` before actionlint; an absent shellcheck leaves shell blocks unchecked.
- A pre-Phase-1 shell job finding no scripts proves wiring, not coverage. The recorded reusable TruffleHog workflow lacks `--fail`; gitleaks is the secret check that can reject findings. Verify controls before describing coverage.
- Plant secret-shaped controls only in untracked files and never commit them. Preserve `verification/` and purchased-material exclusions.
- The build workflow reads its Zig toolchain from `build.zig.zon`. Public CI never receives Developer ID signing keys or builds signed releases.
