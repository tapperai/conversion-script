# conversion-script

Single-file GTM Community Template (`template.tpl`) that records Tapper conversions client-side via `tapper.push`. No server, no build: the sandboxed JS lives inside `template.tpl`.

**PUBLIC repo** (the GTM Gallery publishes from it): everything is world-readable and PR edit history is kept. Technical change only: no customer names or domains, no workspace or protection-script ids, no rates, counts or internal table names, no quotes from people. Evidence and the why go in a private tapperai repo.

## Release
A new first `versions[]` entry in `metadata.yaml` on `master` IS the release: the Gallery serves the commit named by it, not HEAD. Commit the `template.tpl` change, read `git rev-parse HEAD`, then commit the new entry pointing at it (README "Releasing (maintainers)"). Both commits ride in one PR, merged with a MERGE commit (`gh pr merge <n> --merge`) so the sha survives. Never name a sha that does not exist. Nothing deploys otherwise.

## Tests
- Local command: `npm run test:changed` (`scripts/test-changed.mjs`; `-- --list`, `-- --base <ref>`). It runs `npm test` (`scripts/validate-template.js`, then every `___TESTS___` scenario via `scripts/run_template_tests.mjs`) unless the change is prose only, and prints the `Tests: local (...)` trailer.
- CI: `.github/workflows/tests.yml`, job `Validate template.tpl (pre-deploy gate)` (about 10 s) runs on every ready PR next to `CI gate` (mode from `CI_GATE_MODE`); `test-batch.yml` batches and bisects; `ci-label.yml` maps the `ci:` labels. Do not merge on a red pre-deploy check.
- **Time window (T-10194):** a due batch waits until the newest batch on the branch started `CI_BATCH_MIN_INTERVAL_MIN` (repo or org variable, default 60; `0` turns the window off) minutes ago, unless `CI_BATCH_MAX` (default 32, equal to the bisect's `BISECT_MAX_MERGES` in `tests.yml`) merges of any choice are waiting; below 10 merges an hour nothing changes. The AFFECTED `base` is the newest PASSED `(batch)`, `(batch-affected)` or `(nightly)` run on the branch's first-parent line, and a red `batch-affected` run is bisected from its own `base` (`tests.yml` hands it to `batch-bisect.sh` as `GOOD`). A dev -> master promotion of dev's exact tree counts toward no master batch (this repo has no `dev` branch, so the rule never applies here). Local test (no network, a fake `gh`): `bash .github/scripts/ci/batch-trigger.test.sh`. Same script as loop, back-end, front-end, admin.

## Fleet rules (full text: root `CLAUDE.md` of the tapper folder)
- **Branch flow:** PRs target `master`; no dev branch, nothing promotes.
- **Identity:** work from the operator's laptop is his own GitHub login (plain `git`/`gh`); work on Loop's machine is `tapper-loop[bot]`.
- **Review gate:** one reviewer for a RISKY migration, enforcement/blocking, money or a customer-visible number (plus security-reviewer for auth, secrets, cookies, PII); verdict published on the PR as `VERDICT #n @ <sha>: APPROVE`. Everything else merges on the author's own verification.
- **Testing policy:** per change choose local, affected or none and record it: `Tests: local (<cmd>)`, `Tests: affected`, or `Tests: skip (<reason>)`, as the last paragraph of the commit AND the PR description. Local command: `npm run test:changed`.
- **Immediate first, sweep as backstop:** a state change updates every copy in the same code path; a sweep only cleans up what tripped.
- **Config standard:** business limits are a typed code default overridden by a DB settings row (audit, reset); customer/partner secrets are KMS-sealed in the service's own DB, never Secret Manager, never plaintext.

## Customer copy
Copy SELLS: confident and plain; no "not available / planned / next / yet" disclaimers and no internals. One sales-wide platform list: Google, Meta, TikTok, Microsoft/Bing, LinkedIn, Snapchat, Apple.

## Docs
`docs/SPEC.md` (how the template works now), `docs/TESTING.md`, `docs/ENVIRONMENT_SPINUP.md`, decisions in `docs/decisions/` (short, frozen). Rule: skill `docs-rule`.

`docs/BACKLOG.md` is the single living list of open asks: capture a new ask there BEFORE starting; delete the entry in the PR that ships it (history keeps the record); a deliberate no goes under `## Dropped` with its reason; unverified code goes under `## P0 - needs verification`.

- **Leak guard (2026-10-28):** this repo is PUBLIC. `scripts/leak-guard/` is a byte-identical copy of the design-system canon; `tests.yml` runs it over the checkout with `--redact` (the match never reaches this public log) inside the required validation job. Never put an internal hostname, project id or instance name in a file, a commit message, a PR or an issue here.
