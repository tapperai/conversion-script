# Conversion Script — Testing

> **Parent:** [Conversion Script](SPEC.md)

This repo has no server, database, or queue — testing is two layers: an
environment-independent structural validator, and a set of sandboxed-JS
scenarios embedded directly in `template.tpl`. `npm test` runs both (the
scenarios through the local emulator `scripts/run_template_tests.mjs`), locally
and in CI; the GTM template editor's "Tests" tab is the authoritative harness
for the scenarios.

---

## Layer 1 — Structural validator (`npm test`, first step)

```bash
npm test                # scripts/validate-template.js, then scripts/run_template_tests.mjs template.tpl
npm run test:changed    # the one local command: npm test unless the change is prose only
```

No secrets, no network, no dependencies. Checks:

1. `metadata.yaml` parses and `versions[0].sha` is a real commit reachable in
   this checkout (via `git cat-file -t <sha>`, only when run inside a git repo).
2. `template.tpl` contains every required GTM section
   (`___TERMS_OF_SERVICE___`, `___INFO___`, `___TEMPLATE_PARAMETERS___`, `___SANDBOXED_JS_FOR_WEB_TEMPLATE___`,
   `___WEB_PERMISSIONS___`, `___TESTS___`).
3. The embedded JSON blocks (`___INFO___`, `___TEMPLATE_PARAMETERS___`,
   `___WEB_PERMISSIONS___`) are valid JSON.

CI runs the same command — `.github/workflows/tests.yml` (required check
`Validate template.tpl (pre-deploy gate)`) runs `npm test` on every ready PR
targeting `master`, in every gate mode, and in the test batch, so a failing
`___TESTS___` scenario (Layer 2) fails that check too.

---

## Layer 2 — Sandbox scenarios (`___TESTS___` in `template.tpl`)

Run them two ways:

- **Locally / CI:** `node scripts/run_template_tests.mjs template.tpl` (part of
  `npm test`). The runner is ported from tracking-script: it emulates the
  sandbox APIs this template uses (`injectScript`, `callInWindow`,
  `copyFromWindow`, `logToConsole`, `getType`, `makeNumber`, `makeString`)
  with GTM's exact-path `access_globals` permission check, and the test APIs
  the scenarios use (`mock`, `runCode`, `assertApi`, `assertThat`, `fail`). An
  API it does not emulate fails the scenario loudly. `wasCalledWith` compares
  arguments strictly: `'1'` is not `1`, and a trailing `undefined` is not a
  missing argument.
- **In GTM:** **Templates → Tapper - Conversion Script → Tests tab → Run All
  Tests.** The authoritative harness; run it before a release.

The shared `setup:` block mocks `injectScript` to call its success callback
(the test sandbox loads no real script), so every scenario reaches
`tapper.init` and `recordConversion()`. `callInWindow` stays unmocked, so the
`tapper.init` / `tapper.push` grants are permission-checked on every
scenario. Each scenario sets `data` and asserts on the `tapper.push` call.

| Scenario | What it proves |
|---|---|
| Records conversion with default value | Empty `conversion` still fires success (defaults to `1`). |
| Records conversion with custom value | `conversion: '5'` fires success. |
| Fails without pk | Missing `pk` → `gtmOnFailure()`, no push. |
| Legacy fire when Order Value is empty | `orderValue` empty → `tapper.push(1)` (legacy path). |
| Rich fire with value and currency | `orderValue: '49.99'`, `currency: 'EUR'`, `transactionId: 'ORD-1'` → `tapper.push(49.99, 'EUR', 'ORD-1')`. |
| Rich fire without currency uses account default | `orderValue` set, `currency`/`transactionId` empty → `tapper.push(49.99, undefined, undefined)`. |
| Non-numeric Order Value falls back to legacy conversion | `orderValue: 'not-a-number'` → falls back to `tapper.push(1)`, conversion still recorded. |
| Non-numeric Conversion Value falls back to 1 | `conversion: 'abc'` → `tapper.push(1)`. |
| Zero Order Value with an id and the option absent / off records the plain conversion (2) | `orderValue: '0'` + id, `sendOrderIdWithZeroValue` absent or `false` → `tapper.push(1)` exactly as before; no `tapper.push(0, ...)`. |
| Zero Order Value with an id and the option on records value 0 with the id | box on, `orderValue: '0'`, `EUR`, `ORD-0` → `tapper.push(0, 'EUR', 'ORD-0')`. |
| Order Value 0.00 with the option on and no currency records value 0 with the id | `orderValue: '0.00'`, currency empty → `tapper.push(0, undefined, 'ORD-0')`. |
| Numeric Order Value 0 with the option on keeps a T-prefixed id as a string | `orderValue: 0`, `transactionId: 'T123456789'` → `tapper.push(0, 'EUR', 'T123456789')`. |
| A numeric order id stays a string on the zero-value push | `transactionId: 123456789` (a number) → `tapper.push(0, 'EUR', '123456789')`. |
| Zero Order Value with the option on and an empty id / no id field records the plain conversion (2) | box on, value 0, id `''` or absent → `tapper.push(conversion)`. |
| Blank / False Order Value with the option on records the plain conversion (2) | `orderValue: ' '` or `false` (both coerce to 0) → `tapper.push(1)`, not a zero-value order. |
| Positive Order Value with the option on / off is unchanged (2) | `49.99`, `EUR`, `ORD-1` → `tapper.push(49.99, 'EUR', 'ORD-1')` either way. |
| Negative / non-numeric / empty Order Value with the option on records the plain conversion (3) | `'-10'`, `'not-a-number'`, `''` with an id → `tapper.push(1)`. |

To add a scenario: edit the `scenarios:` YAML list under `___TESTS___` in
`template.tpl` directly (it is GTM's own mock/assert DSL — `runCode`,
`assertApi(...).wasCalled()` / `.wasCalledWith(...)`).

---

## Manual end-to-end check

1. Import `template.tpl` into a GTM workspace (or preview the template
   directly in the editor).
2. Create a tag from **Tapper - Conversion Script**, set a test `pk`
   (`pk_test_...`).
3. Use GTM Preview mode against a page that doesn't already load
   `monitor.tapper.ai/bundle.js`, fire the trigger, and confirm in the
   browser console / Network tab that:
   - `bundle.js` loads once,
   - `tapper.init(pk)` is called before `tapper.push`,
   - `tapper.push(...)` is called with the expected arguments for the
     Order Value vs legacy path being tested.
