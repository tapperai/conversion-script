# conversion-script

Single-file GTM Community Template (`template.tpl`) that records Tapper conversions client-side via `tapper.push`. No server, no build: the sandboxed JS lives inside `template.tpl`.

**PUBLIC repo** (the GTM Gallery publishes from it): everything is world-readable and PR edit history is kept. Technical change only: no customer names or domains, no workspace or protection-script ids, no rates, counts or internal table names, no quotes from people. Evidence and the why go in a private tapperai repo. Never put an internal hostname, project id or instance name in a file, commit message, PR or issue. `scripts/leak-guard/` (a byte-identical copy of the design-system canon) runs over the checkout in the required validation job with `--redact`.

## Release
A new first `versions[]` entry in `metadata.yaml` on `master` IS the release: the Gallery serves the commit named by it, not HEAD. Commit the `template.tpl` change, read `git rev-parse HEAD`, then commit the new entry pointing at it (steps: `docs/ENVIRONMENT_SPINUP.md`, README "Releasing (maintainers)"). Both commits ride in one PR, merged with a MERGE commit (`gh pr merge <n> --merge`) so the sha survives. Never name a sha that does not exist. Nothing deploys otherwise.

## Tests
Local command: `npm run test:changed` (`-- --list`, `-- --base <ref>`): validates the template and runs every `___TESTS___` scenario, prints the `Tests: local (...)` trailer. CI runs the same validation on every ready PR; do not merge on a red pre-deploy check. Detail: `docs/ENVIRONMENT_SPINUP.md`.

## Fleet rules (full text: umbrella `CLAUDE.md`)
PRs target `master`; no dev branch, nothing promotes. Identity, review gate, approval gate and the config standard come from the umbrella file. Testing: record `Tests: local (<cmd>)` or `Tests: skip (<reason>)` as the last paragraph of the commit AND the PR description.

## Customer copy
Copy SELLS: confident and plain; no "not available / planned / next / yet" disclaimers, no internals. One sales-wide platform list: Google, Meta, TikTok, Microsoft/Bing, LinkedIn, Snapchat, Apple.

## Docs
`docs/SPEC.md` (how the template works now), `docs/TESTING.md`, `docs/ENVIRONMENT_SPINUP.md`, decisions in `docs/decisions/` (short, frozen); skill `docs-rule`. `docs/BACKLOG.md` is the single living list of open asks: capture a new ask there BEFORE starting; delete the entry in the PR that ships it; a deliberate no goes under `## Dropped` with its reason; unverified code goes under `## P0 - needs verification`.
