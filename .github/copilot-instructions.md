# GitHub Copilot Instructions for savera

For full project conventions, see AGENTS.md in the repository root. It carries the rules and a pointer table; the depth behind each pointer is in `docs/notes/`, indexed by `docs/notes/README.md`. When a review turns on how some part of this project actually behaves, the note is where the measurement is.

## Scoped Instructions

Path-scoped review instructions live alongside this file:

- [`docs.instructions.md`](docs.instructions.md), for `docs/**/*.md`: how plans, ADRs and notes record decisions, why point-in-time statements are deliberate, why done plans are never corrected, and why the preserved brainstorm in `docs/design/` is not maintained prose.
- [`actions.instructions.md`](actions.instructions.md), for `.github/workflows/*.yml` and `.github/dependabot.yml`: the pinning conventions, why no text or secret-scanning workflow carries `paths-ignore`, and why the typos job pins a checksum.
- [`zig.instructions.md`](zig.instructions.md), for `**/*.zig` and `**/*.zig.zon`: conventions the ADRs already settled, applied to the Phase 1 instrument shell.

## PR Review

- **The build plan at the `docs/plans/` root is permanent, not misfiled**: `docs/plans/2026-09-13-savera-build-plan.md` is the master plan for the whole project and never moves to `todo/` or `done/`. Per-phase plans live in `docs/plans/todo/` and move to `docs/plans/done/` when their pull request merges. Do not suggest moving the build plan.
- **`CLAUDE.md` is a symlink to `AGENTS.md`, and it is present**: it is tracked with git mode `120000` and points at `AGENTS.md`. Tools that follow the link, including GitHub's contents API, report a regular file with `AGENTS.md`'s contents, and a checkout that does not materialise symlinks may show it as absent. Do not report `CLAUDE.md` as missing, and do not suggest replacing the symlink with a copy, which would let the two drift.
- **Prettier `printWidth: 10000` is intentional**: This project uses a high `printWidth` in `.prettierrc.json` to prevent Prettier from wrapping lines. Combined with `proseWrap: preserve` for Markdown, this preserves author line breaks. Do not suggest reducing printWidth to 80 or 120.
- **Omitted relative pronouns are intentional**: This project's prose drops `that` and `which` in restrictive relative clauses where the pronoun is the object of the clause, as in "the decision ADR 0003 records" or "the controls it names". This is standard English, not a grammar error. Do not flag it as a missing word. Flag it only when the omission creates a genuine garden path, and say which reading is the wrong one.
