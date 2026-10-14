# Conversion Script — Environment Spinup

> **Status:** `IMPLEMENTED`
>
> **Created:** 2026-08-26
> **Last updated:** 2026-08-26
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
npm test      # scripts/validate-template.js — see docs/TESTING.md
```

No env vars, no services to start, no ports.

## CI/CD

`.github/workflows/test.yml` (job and required check `conversion-script-gate`,
`ubuntu-24.04-arm`, 5-minute timeout) runs `npm test` on every ready PR
targeting `master` and on every merge-queue group (`actions/checkout` with
`fetch-depth: 0` so the validator can verify `metadata.yaml`'s sha is
reachable, then `actions/setup-node` at Node 20). Draft PRs run nothing: the
job is skipped and the required check reports as passing. `master` takes
changes only through the merge queue (ruleset `merge-queue-master`: merge
commits, groups of up to 5, ALLGREEN, org admins may bypass), so there is no
push run: the queue run already validated the exact merge commit that lands. CI does not deploy anything — publishing to the Community Template
Gallery happens on Google's side, keyed off a new `metadata.yaml`
`versions[]` entry on `master`, not a CI step in this repo. See `docs/SPEC.md` → "Operational Procedures" for the
release (two-commit) procedure.

## Secrets & Configuration

None. No API keys, database URLs, or Secret Manager entries are used by this
repo or its CI workflow.

## Verification

`npm test` exiting 0 is the full health check for this repo — there is no
running service to probe.
