# Conversion Script (GTM Template)

> **Status:** ACTIVE
>
> **Created:** 2026-08-26
> **Last updated:** 2026-10-21
>
> **Implemented in:** conversion-script

## Overview

`conversion-script` is a single-file Google Tag Manager Community Template
(`template.tpl`) that records a Tapper conversion event client-side. When the
tag fires, its sandboxed JS ensures the Tapper monitoring script
(`https://monitor.tapper.ai/bundle.js`) is loaded and initialised with the
merchant's public key, then calls `tapper.push(...)` to record the
conversion — either a plain legacy conversion value or a rich order value
with currency and transaction id (and, only when the opt-in
`sendOrderIdWithZeroValue` box is ticked, a zero-value order with its id),
optionally carrying a flat object of additional fields built from the
`additionalFields` table. The repo has no server, no build step, and
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
  ├── sendOrderIdWithZeroValue ticked AND Order Value exactly 0 AND Transaction ID non-empty
  │     ──> tapper.push(0, currency || undefined, makeString(transactionId))
  └── Order Value absent/invalid (or 0 with the box off or no id)
        ──> tapper.push(conversion)   # legacy path, conversion defaults to 1

  additionalFields rows that survive the skip rules
        ──> the same push with the fields object appended as the 4th argument
            (legacy path: tapper.push(conversion, undefined, undefined, fields))
        ──> no usable row: the 4th argument is left off, byte-identical to before
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
| `sendOrderIdWithZeroValue` | CHECKBOX | No | `false` (off) |
| `additionalFields` | SIMPLE_TABLE (`name`, `value`) | No | empty |

---

## Contracts

Not an HTTP API. The template calls two global functions injected by the
Tapper monitoring bundle onto `window`:

| Call | Args | When |
|---|---|---|
| `tapper.init` | `(pk)` | Once, right after `bundle.js` loads for the first time on the page |
| `tapper.push` | `(orderValue, currency?, transactionId?)`, `(0, currency?, transactionId)` (opt-in, see below) or `(conversion)`, each with an optional 4th `fields` object | Every tag fire |

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
- **`sendOrderIdWithZeroValue`** (checkbox, default off) — when ticked, an
  Order Value of exactly 0 (the number `0`, or a string such as `'0'` or
  `'0.00'` that parses to 0 and holds a `0` digit) with a non-empty
  `transactionId` pushes `(0, currency || undefined, makeString(transactionId))`
  instead of the legacy conversion, which carries no order id. The id always
  goes as a string, so a numeric-looking id never becomes a number. A blank
  string or `false` (which `makeNumber` also turns into 0), a negative, a
  non-numeric or an empty Order Value, or a zero value without an id, keep
  the legacy path. With the box off (or absent, on a tag saved before the
  option existed) every input pushes exactly the same arguments as before
  the option; the "not a positive number" console warning is skipped only
  when the zero-value push is sent.
- **`additionalFields`** (SIMPLE_TABLE, columns `name` and `value`, empty by
  default) - each row becomes one key of a plain object passed as the 4th
  argument of whichever push above applies. The template applies TWO rules and
  no more: a row whose name is empty (after `makeString`) is skipped, and a row
  whose value is `undefined`, `null` or an empty cell (`makeString` of it is
  `''`, which is what a variable that resolved to nothing leaves in a text
  column) is skipped. `0` and `false` are values and are kept. Values are
  passed as the types GTM produced: no coercion, no trimming, no truncation.
  Everything else (the name shape
  `^[A-Za-z][A-Za-z0-9_]{0,39}$`, the 1 to 100 character text bound, finite
  numbers, booleans, at most 20 fields, the whole object dropped above 200
  entries, no lists or nested objects, the personal-data screen) is applied
  where the conversion is received, which is what the help text states too: a
  field we cannot accept is dropped on its own and never costs the conversion.
  The help text names the screen's surprising rules in the merchant's words,
  from the final back-end list (back-end#2814, `src/services/conversionMetadata.ts`):
  a value of 8 or more digits made only of digits and separators is skipped
  (an id needs a letter, `T801884423`; a Unix time in seconds or milliseconds
  is kept under a key ending in `_at`, `_time`, `_timestamp`, `_ts`, `_epoch`
  or `_date`, but only in range, `[1e9, 2e9)` seconds and `[1e12, 2e12)`
  milliseconds, which is 2001-09-09 to 2033-05-18: any wider ceiling re-admits
  10-digit North American phone numbers, whose area codes start at 2. An ISO
  date as text is always kept), as are 32+ hex characters, a base64 digest, an IP address
  with or without a port, an IBAN, an email address, a phone number, a street
  address, a number past 2^53 - 1, and any key naming a person or a secret. An `additionalFields` value
  that is not an array (`getType`) is ignored. With no usable row the 4th
  argument is LEFT OFF, so every call is byte-identical to the one the template
  made before the option existed. No new sandbox permission: `callInWindow` is
  covered by the exact-path `access_globals` `execute` grant on `tapper.push`,
  which does not depend on the argument types.

---

## Edge Cases

- **`orderValue` is non-numeric string** (e.g. `"not-a-number"`) — falls back
  to `tapper.push(conversion)` (legacy), logs a console warning, still calls
  `gtmOnSuccess()`.
- **`conversion` is non-numeric** (e.g. `"abc"`) — falls back to `1`.
- **`orderValue` is 0** — box off: legacy `tapper.push(conversion)`, as
  before. Box on with a Transaction ID: `tapper.push(0, currency, id)`; box
  on without one: legacy push.
- **A field name typed as a number** (e.g. a variable returning `2026`) -
  `makeString` makes it the text key `"2026"`; the receiving side then refuses
  it, because a name must start with a letter.
- **The same name twice** - the GTM editor refuses it (`isUnique` on the Name
  column), and a name differing only in case (`Plan` and `plan`) is two
  different fields: pick one spelling.
- **A row with a name and a blank value cell** - skipped, so the call keeps the
  shape it had before the option existed. This is the one rule the template
  applies that the receiving side would also have applied: without it a blank
  cell would append `{"plan": ""}` to a tag whose editor shows an empty row.
- **No usable row** - the 4th argument is left off, not sent as `{}`: a
  differential run over 70,200 input combinations carrying no usable field
  (including named rows with a blank, `null` or `undefined` value) found zero
  behaviour differences against the previous template.
- **A pre-init page with fields, Currency empty and a Transaction ID set** -
  `callInWindow` is `Array.prototype.push` on the stub, so the arguments land
  as separate entries and today's drain reads a bare number followed by a
  non-currency string as a score: the value, the order id AND the fields are
  lost, and only the score is recorded. The value and order-id half of that is
  older than this option; map Currency whenever you map fields. On a page where
  the bundle has already loaded (the common case: the tag injects and
  initialises it itself) every argument arrives.
- **`tapper` already exists on `window`** (script loaded by an earlier tag
  fire on the same page) — skips `injectScript`/`tapper.init` and calls
  `recordConversion()` directly.
- **Script injection fails** (network/CSP block) — logs and calls
  `gtmOnFailure()`.

---

## Testing

See [`TESTING.md`](TESTING.md) — this repo's tests are the
environment-independent structural validator (`scripts/validate-template.js`)
and the `___TESTS___` sandbox scenarios embedded in `template.tpl`, executed
by the dependency-free emulator `scripts/run_template_tests.mjs`. `npm test`
runs both, locally and in CI; the GTM template editor's Tests tab stays the
authoritative harness for the scenarios.

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

Never point a version entry at a sha that does not exist yet. If the `template.tpl` change goes through a PR, merge it first and take its sha from `master`: a squash or rebase merge rewrites it. Maintainers open and merge their own release PRs: PRs merge directly as merge commits (so every sha in the PR survives; there is no merge queue), and the required check `Validate template.tpl (pre-deploy gate)` (`npm test`) runs on the ready PR. Both commits of the dance can ride in one PR, since the merge commit keeps the template commit's sha. Before marking the release PR ready, run `npm test`, run the `___TESTS___` scenarios in the GTM template editor's Tests tab (`npm test` runs them in a local emulator; GTM's own runner is the authoritative one), and get one code review when the change alters how conversions or order values are recorded. Merging a new `metadata.yaml` version to `master` is the release.

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
  (`___TERMS_OF_SERVICE___` included) with valid embedded JSON. It does not
  execute the `___TESTS___` scenarios; the next file does.
- `scripts/run_template_tests.mjs` -- dependency-free Node emulator (ported
  from tracking-script) that runs every `___TESTS___` scenario against the
  sandboxed JS with GTM's exact-path `access_globals` checks; `npm test` runs
  it after the validator and fails on any failing scenario.
- `.github/workflows/tests.yml` -- CI: job `Validate template.tpl (pre-deploy
  gate)` runs `npm test` on every ready PR targeting `master` (required, every
  gate mode; drafts run nothing; there is no push run); `test-batch.yml` runs it
  in batches.
- `scripts/test-changed.mjs` -- `npm run test:changed`, the one local test
  command (testing policy in CLAUDE.md); `scripts/test-changed.test.mjs` is its
  `node --test` check, which CI also runs.
- `README.md` -- end-user setup instructions (GTM import, parameter mapping)
  and the maintainer release procedure.
