# Linters

How the text tools are pinned, what each one judges, what each one cannot see, and the traps already found. The workflows that run them are in [CI workflows](./ci-workflows.md).

## The pinned tools, and why Homebrew's are the wrong ones

Prettier, markdownlint-cli2 and markdownlint-rule-relative-links are pinned exactly in `package.json` and installed from the committed `package-lock.json`. CI's text lint job installs from that same lockfile (`use-consumer-versions: true`), so a local run after `npm ci` and a CI run resolve identical versions with per-package integrity.

**Run them through npm, never from Homebrew.** Measured on 2026-09-14: Homebrew had Prettier 3.8.1 and markdownlint-cli2 0.21.0, against the pinned Prettier 3.9.6 and markdownlint-cli2 0.23.2. A rule or formatting difference between the two shows up only in CI.

`.npmrc` sets `engine-strict=true`. markdownlint-cli2 0.23.2, markdownlint 0.41.1 and markdownlint-rule-relative-links 5.1.2 all declare Node `>=22`, so an older runtime fails at `npm ci` with `EBADENGINE` rather than later inside markdownlint.

typos, actionlint, shellcheck and gitleaks are single binaries. CI pins typos by version and SHA-256, and gets actionlint, shellcheck and gitleaks from the pinned `cboone/gh-actions` release; locally they come from Homebrew, whose versions matched the CI pins on 2026-09-14 (typos 1.50.1, actionlint 1.7.12, ShellCheck 0.11.0, gitleaks 8.30.1).

```bash
npm ci                   # once per checkout, and after any package.json change
npm run format           # Prettier writes
npm run format:check     # Prettier checks, exactly as CI runs it
npm run lint:md          # markdownlint, exactly as CI runs it
typos
shellcheck --version && actionlint
gitleaks detect --no-banner
```

## Prettier formats, markdownlint verifies

Prettier owns the layout of every file type it supports: Markdown, YAML, JSON and JSONC. markdownlint verifies the Markdown for what no formatter has an opinion about, including relative links. CI runs both as checks, through `cboone/gh-actions` `lint-text.yml`: `markdownlint-cli2 "**/*.md"` first, then `prettier --check .`, which are the same strings as `npm run lint:md` and `npm run format:check`.

**The CI order hides findings.** `lint-text.yml` runs its Prettier step only when markdownlint passed, so a change that trips both shows only markdownlint's findings until those are fixed. Measured on 2026-09-14 in PR #1: a plant with both kinds of defect reported `Run Prettier check: skipped`, and a Prettier-only plant then failed that step. Filed as [cboone/gh-actions#112](https://github.com/cboone/gh-actions/issues/112). Running both locally before pushing avoids the second round trip.

**Locally, run Prettier before markdownlint, and never pass `--fix` to `markdownlint-cli2`.** Formatting first means markdownlint judges the layout Prettier settled. Its `--fix` ignores the file arguments it is given and rewrites every file matching the `globs` in `.markdownlint-cli2.jsonc`, and it has no fixer for `MD060` at any version, so it cannot fix the table alignment it reports. `npm run format` is the fixer.

**This replaces two catalog skills' fix steps.** `lint-and-fix` passes each detected linter its fix flag, and `write-markdown`'s validation step asks for markdownlint in fix mode. In this repository both are satisfied by `npm run format` followed by `npm run lint:md`. See [skill deviations](./skill-deviations.md).

Prettier's settings in `.prettierrc.json`, each load-bearing:

- **`printWidth: 10000` with `proseWrap: "preserve"`.** Prose is one long line per paragraph, and nothing reflows it. A side effect in JSON: Prettier fits an array onto one line whenever it fits within the width, so `npm run format` collapsed `.claude/settings.json`'s permissions list onto one line on 2026-09-14. That is Prettier's output, not a defect.
- **`embeddedLanguageFormatting: "off"`.** fosforo found Prettier dedenting YAML inside Markdown code fences before this was set.

markdownlint's rules in `.markdownlint-cli2.jsonc`: `MD013` off, because prose is one line per paragraph; `MD024` siblings only, because ADRs repeat their section headings; `MD033` off; `MD049` off, because Prettier decides emphasis style and correctly leaves intraword asterisks alone, which the default `consistent` then misreports; `MD060` aligned, which Prettier's table output satisfies exactly.

## The relative-links rule

`markdownlint-rule-relative-links` is loaded as a `customRules` entry and is the repository's relative-link check. For every relative link it asserts that the linked file exists and, when the link carries a `#fragment`, that the fragment names a heading in that file. Built-in `MD051` checks fragments only within the same file, so a broken anchor from an ADR into the build plan is seen by this rule alone.

Measured on 2026-09-14 with 5.1.2, against a planted file: a missing file and a bad fragment are reported as separate findings, and a valid fragment and a link to a directory both pass.

It resolves from `node_modules`, so it needs `npm ci`. An unresolvable rule fails loudly rather than being skipped: measured on 2026-09-14, markdownlint-cli2 0.23.2 with the rule installed nowhere exits 2 with `ERR_MODULE_NOT_FOUND`. On a machine whose global Node modules include the rule, which a global markdownlint config can require, even a Homebrew markdownlint-cli2 run outside the repository loads it, at whatever version is installed there, so a local pass without `npm ci` does not prove the pinned rule ran.

**Every finding in `AGENTS.md` is reported twice**, once for `AGENTS.md` and once for `CLAUDE.md`, because markdownlint-cli2's `**/*.md` glob follows the symlink and lints the same file under both names. Measured on 2026-09-14 with a planted broken link, which produced `AGENTS.md:131` and `CLAUDE.md:131`. The duplicate is expected; fix the finding in `AGENTS.md` and both disappear.

**No built-in rule sees a broken cross-file link.** Measured on 2026-09-14: with `customRules` removed from the config, a link to a missing file and a link to a real ADR with a bad fragment both passed with 0 issues.

**The pull request template links `CONTRIBUTING.md` by absolute URL.** GitHub resolves a relative link in a template against the pull request page, not the template file, so a relative link there is broken where it is read even though this rule would accept it.

## What is excluded, and the negative controls that prove the exclusions work

`docs/design/` is excluded from both Prettier (`.prettierignore`) and markdownlint (`ignores`). The brainstorm there is preserved verbatim. The two lists are kept in step by hand, because neither tool reads the other's configuration.

The exclusions are verified, not assumed. Measured on 2026-09-14 with the pinned versions:

| Control                                                                                      | Result                                     |
| -------------------------------------------------------------------------------------------- | ------------------------------------------ |
| `npx prettier --check --ignore-path /dev/null docs/design/peti-physical-model-brainstorm.md` | Flagged, exit 1: the ignore is doing work  |
| markdownlint over the brainstorm with `docs/design/**` removed from `ignores`                | 13 issues: `MD034` 8, `MD036` 4, `MD040` 1 |

**Nothing in CI catches a hand edit to the brainstorm.** The exclusions protect it only from the tools. Each phase pull request checks by hand that `git diff --exit-code origin/main -- docs/design/` is empty and that its SHA-256 is still `ee012eff0fa93b1ae73dc311e516e1c709ab30b15319bfbfcd0f1bb91ce13529`.

`package-lock.json` is excluded from Prettier because npm writes it. Prettier 3.9.6 does not flag it (measured 2026-09-14); the entry stops a future release of either tool from turning a lockfile update into a formatting failure.

`node_modules/**` is load-bearing in markdownlint's `ignores`: markdownlint-cli2 walks into it and lints dependency READMEs, which CI's `npm ci` in the workspace has just installed. Prettier skips it without configuration.

## typos

A word is added to `typos.toml` only when typos flags it, with the reason as a comment beside it. There is no pre-seeded vocabulary, so no entry exists that suppresses nothing. On 2026-09-14 typos reported no findings across the tree, including the brainstorm, the build plan, the twenty-three ADRs and `package-lock.json`.

When a word does need adding, the table matters:

- **`[default.extend-words]`** allows a word wherever it appears.
- **`[default.extend-identifiers]`** allows a whole identifier. typos splits an identifier into words before judging it, so a pluralised acronym or a mixed-case name keyed into `extend-words` suppresses nothing, silently. fosforo hit this with a pluralised acronym.

Two `extend-ignore-re` entries are already present, each with its reason in the file: a backtick-anchored pattern for short commit SHAs in prose, and a `<!-- spellchecker:off -->` to `<!-- spellchecker:on -->` span, which is the only way a document can quote a misspelling in order to explain it.

**typos scans `docs/design/`; nothing excludes it.** The brainstorm passes today. If a later typos release flags a word in it, the typos job fails, and the repair is to add that word to `typos.toml` with the finding as the reason, never to edit the brainstorm.

## actionlint needs shellcheck

actionlint shells out to shellcheck for every `run:` block. With no shellcheck on `PATH` it skips all of them and still exits 0, so a silent local run means nothing unless `shellcheck --version` printed first. CI's actions job installs a pinned shellcheck and reports both versions; see [CI workflows](./ci-workflows.md).

## gitleaks

`.gitleaks.toml` extends the default rules and allowlists the build directories, and `fixtures/*.wav` and `fixtures/*.npz`. It does not allowlist `build.zig.zon`: three real Zig manifests, with no allowlist at all, produced no finding, so an entry would hide the whole manifest to suppress nothing. The comments in the file record that measurement and the rule for adding a value if a manifest is ever flagged. Measured on 2026-09-14 with gitleaks 8.30.1 in a scratch directory outside the repository:

- The `aws-access-token` rule matches `AKIA` followed by 16 characters from the base32 alphabet `[A-Z2-7]`. A candidate containing `0`, `1`, `8` or `9` is not flagged at all, so a planted key must use that alphabet or its silence means nothing.
- Nothing in the default rules excludes `.wav`: a key in a root-level `.wav` is flagged.
- gitleaks reports paths without a leading `./` in both the working-tree (`--no-git`) and the git-history scans, so the anchored `^fixtures/` entry matches, and it suppresses `fixtures/plant.wav` while the root-level `.wav` is still flagged.

Never commit a secret-shaped string to test this, even a fake one: this repository is public, and history is permanent.

## Shell

Phase 1 has extensionless shell scripts under `scripts/` and `cmake/`. `.editorconfig` names both sets and shfmt reads that profile all-or-nothing: `shfmt -d` honours it and `shfmt -i 2 -d` silently ignores it. The CI shell job installs and reports shfmt 3.13.1 and ShellCheck 0.11.0, discovers tracked files by shebang, and checks exactly that list. The Phase 1 SC2086 plant was discovered at `cmake/set-au-display-name:17` and rejected by [run 35121659836](https://github.com/cboone/savera/actions/runs/35121659836), while its shfmt check passed.
