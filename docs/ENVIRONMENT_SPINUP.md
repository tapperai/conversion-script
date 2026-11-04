# Conversion Script — Environment Spinup

> **Status:** ACTIVE
>
> **Created:** 2026-08-26
> **Last updated:** 2026-10-21
>
> **Implemented in:** conversion-script

## Overview

There is no environment to spin up. `conversion-script` is a single-file GTM
Community Template with no server, no database, no queue, and no cloud
service of its own — it ships as static text (`template.tpl` +
`metadata.yaml`) that Google's GTM Community Template Gallery ingests
directly from this repo on push to `master`. The only runtime is the
merchant's own GTM container in their browser, and the external service it
talks to is `https://monitor.tapper.ai/bundle.js` (owned by the `tracker`
repo, not this one).

## Local development

```bash
git clone git@github.com:tapperai/conversion-script.git
cd conversion-script
npm install   # no dependencies today; installs nothing beyond package.json
npm test      # scripts/validate-template.js + scripts/run_template_tests.mjs — see docs/TESTING.md
```

No env vars, no services to start, no ports.

## CI/CD

`.github/workflows/tests.yml` (CI standard 2026-10-17; job and required check
`Validate template.tpl (pre-deploy gate)`, `ubuntu-24.04-arm`, 5-minute timeout)
runs `npm test` on every ready PR targeting `master`, in every gate mode
(`actions/checkout` with `fetch-depth: 0` so the validator can verify
`metadata.yaml`'s sha is reachable, then `actions/setup-node` at Node 20).
Ruleset `required-checks` on `master` requires it and `CI gate` (which follows
the Actions variable `CI_GATE_MODE`, `NONE` today: skipped, which counts as
passing). Draft PRs run nothing. There is no merge queue and no push run;
`test-batch.yml` re-runs the check every `CI_BATCH_SIZE` merges, nightly and on
demand, and bisects a red run to the guilty merge. CI does not deploy anything — publishing to the Community Template
Gallery happens on Google's side, keyed off a new `metadata.yaml`
`versions[]` entry on `master`, not a CI step in this repo. See `docs/SPEC.md` → "Operational Procedures" for the
release (two-commit) procedure.

## Secrets & Configuration

None. No API keys, database URLs, or Secret Manager entries are used by this
repo or its CI workflow.

## Verification

`npm test` exiting 0 is the full health check for this repo — there is no
running service to probe.

## CI detail (moved from CLAUDE.md)
CI: `.github/workflows/tests.yml`, job `Validate template.tpl (pre-deploy gate)` (about 10 s) runs on every ready PR next to `CI gate` (mode from `CI_GATE_MODE`); `test-batch.yml` batches and bisects; `ci-label.yml` maps the `ci:` labels. Do not merge on a red pre-deploy check. `npm run test:changed` (`scripts/test-changed.mjs`; `-- --list`, `-- --base <ref>`) runs `npm test` (`scripts/validate-template.js`, then every `___TESTS___` scenario via `scripts/run_template_tests.mjs`) unless the change is prose only.
Time window (batch): a due batch waits until the newest batch on the branch started `CI_BATCH_MIN_INTERVAL_MIN` (default 60; `0` turns it off) minutes ago, unless `CI_BATCH_MAX` (default 32, equal to the bisect's `BISECT_MAX_MERGES` in `tests.yml`) merges are waiting. The AFFECTED `base` is the newest PASSED `(batch)`, `(batch-affected)` or `(nightly)` run on the branch's first-parent line; a red `batch-affected` run is bisected from its own `base`. Local test (no network, a fake `gh`): `bash .github/scripts/ci/batch-trigger.test.sh`.
Release steps: commit the `template.tpl` change, read `git rev-parse HEAD`, then commit the new first `versions[]` entry in `metadata.yaml` pointing at it (README "Releasing (maintainers)"); both commits ride in one PR.
