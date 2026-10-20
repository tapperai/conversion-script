# Conversion Script (GTM Template)

> **Status:** ACTIVE
>
> **Created:** 2026-08-26
> **Last updated:** 2026-10-20
>
> **Implemented in:** conversion-script

## Overview

`conversion-script` is a single-file Google Tag Manager Community Template
(`template.tpl`) that records a Tapper conversion event client-side. When the
tag fires, its sandboxed JS ensures the Tapper monitoring script
(`https://monitor.tapper.ai/bundle.js`) is loaded and initialised with the
merchant's public key, then calls `tapper.push(...)` to record the
conversion — either a plain legacy conversion value or a rich order value
with currency and transaction id. The repo has no server, no build step, and
no runtime process: `metadata.yaml` + `template.tpl` together ARE the
deployable artifact, published to the GTM Community Template Gallery.

---

## Architecture

```
GTM container (merchant's site)
    |
    | tag fires on trigger (e.g. Purchase)
    v
template.tpl sandboxed JS
    ├── tapper already on window? ──> recordConversion()
    └── not yet loaded ──> injectScript(monitor.tapper.ai/bundle.js)
                                ├── success ──> tapper.init(pk) ──> recordConversion()
                                └── failure ──> logToConsole + gtmOnFailure()

recordConversion():
  ├── Order Value valid (positive, finite, <= maxOrderValue)
  │     ──> tapper.push(orderValue, currency || undefined, transactionId || undefined)
  └── Order Value absent/invalid
        ──> tapper.push(conversion)   # legacy path, conversion defaults to 1
```

---

## Schema

None — no database. The only "schema" is the GTM template parameter set
declared in `template.tpl` under `___TEMPLATE_PARAMETERS___`:

| Field | Type | Required | Default |
|---|---|---|---|
| `pk` | TEXT | Yes | — |
| `conversion` | TEXT (coerced to number) | No | `1` |
| `orderValue` | TEXT (coerced to number) | No | — |
| `currency` | TEXT | No | — |
| `transactionId` | TEXT | No | — |

---

## Contracts

Not an HTTP API. The template calls two global functions injected by the
Tapper monitoring bundle onto `window`:

| Call | Args | When |
|---|---|---|
| `tapper.init` | `(pk)` | Once, right after `bundle.js` loads for the first time on the page |
| `tapper.push` | `(orderValue, currency?, transactionId?)` or `(conversion)` | Every tag fire |

---

## Validation rules (`___SANDBOXED_JS_FOR_WEB_TEMPLATE___`)

- `pk` missing → `gtmOnFailure()`, no push.
- `maxOrderValue = 9999999999` is the shared upper bound for both paths.
- **Legacy `conversion`** — coerced with `makeNumber`; valid only if
  `=== itself` (excludes `NaN`), `> 0`, and `<= maxOrderValue`; otherwise
  falls back to `1`.
- **`orderValue`** — only considered "has a value" when the field is present
  and non-empty; valid only if positive, finite, and `<= maxOrderValue`.
  Invalid or absent `orderValue` always falls back to the legacy `conversion`
  path — the conversion is never dropped just because the value is bad.
- `currency` / `transactionId` are passed through only when the Order Value
  path is used, and only as truthy strings (`|| undefined`).

---

## Edge Cases

- **`orderValue` is non-numeric string** (e.g. `"not-a-number"`) — falls back
  to `tapper.push(conversion)` (legacy), logs a console warning, still calls
  `gtmOnSuccess()`.
- **`conversion` is non-numeric** (e.g. `"abc"`) — falls back to `1`.
- **`tapper` already exists on `window`** (script loaded by an earlier tag
  fire on the same page) — skips `injectScript`/`tapper.init` and calls
  `recordConversion()` directly.
- **Script injection fails** (network/CSP block) — logs and calls
  `gtmOnFailure()`.

---

## Testing

See [`TESTING.md`](TESTING.md) — this repo's tests are the `___TESTS___`
sandbox scenarios embedded in `template.tpl`, run inside the GTM template
editor, plus the environment-independent structural validator
(`npm test` → `scripts/validate-template.js`) that also runs in CI.

---

## Operational Procedures

### Releasing (maintainers)

A new `metadata.yaml` version on `master` IS the release — the GTM Community
Template Gallery publishes from `metadata.yaml`, so a push that adds no
`versions[]` entry releases nothing. Each `versions[].sha` must be a real,
reachable commit sha, which forces a two-commit dance:

1. Commit the `template.tpl` change, then read its sha — `git rev-parse HEAD`.
2. Commit a new `metadata.yaml` `versions[]` entry pointing at that sha, with
   `changeNotes`.

Never point a version entry at a sha that does not exist yet. If the `template.tpl` change goes through a PR, merge it first and take its sha from `master`: a squash or rebase merge rewrites it. Maintainers open and merge their own release PRs: PRs merge directly as merge commits (so every sha in the PR survives; there is no merge queue), and the required check `Validate template.tpl (pre-deploy gate)` (`npm test`) runs on the ready PR. Both commits of the dance can ride in one PR, since the merge commit keeps the template commit's sha. Before marking the release PR ready, run `npm test`, run the `___TESTS___` scenarios in the GTM template editor's Tests tab (CI does not run them), and get one code review when the change alters how conversions or order values are recorded. Merging a new `metadata.yaml` version to `master` is the release.

---

## Files

- `template.tpl` -- the entire GTM Community Template: terms-of-service
  header, `___INFO___`, `___TEMPLATE_PARAMETERS___`, sandboxed JS
  (`___SANDBOXED_JS_FOR_WEB_TEMPLATE___`), `___WEB_PERMISSIONS___`, and the
  embedded `___TESTS___` scenarios.
- `metadata.yaml` -- Community Template Gallery release manifest: homepage,
  docs link, and the `versions[]` sha/changeNotes ledger that drives publish.
- `scripts/validate-template.js` -- environment-independent pre-release check
  (`npm test`): checks `metadata.yaml`'s `versions[0].sha` is a real reachable
  commit, and that `template.tpl` has all six required sections
  (`___TERMS_OF_SERVICE___` included) with valid embedded JSON. Deliberately does NOT execute the `___TESTS___` scenarios
  (no standalone GTM sandbox test runner exists outside the template editor).
- `.github/workflows/tests.yml` -- CI: job `Validate template.tpl (pre-deploy
  gate)` runs `npm test` on every ready PR targeting `master` (required, every
  gate mode; drafts run nothing; there is no push run); `test-batch.yml` runs it
  in batches.
- `scripts/test-changed.mjs` -- `npm run test:changed`, the one local test
  command (testing policy in CLAUDE.md); `scripts/test-changed.test.mjs` is its
  `node --test` check, which CI also runs.
- `README.md` -- end-user setup instructions (GTM import, parameter mapping)
  and the maintainer release procedure.
