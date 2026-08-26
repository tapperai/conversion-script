# Conversion Script — Testing

> **Parent:** [Conversion Script](SPEC.md)

This repo has no server, database, or queue — testing is two layers: an
environment-independent structural validator that runs in CI, and a set of
sandboxed-JS scenarios embedded directly in `template.tpl` that run inside
the GTM template editor's "Tests" tab.

---

## Layer 1 — Structural validator (`npm test`)

```bash
cd "/Users/rezi/Desktop/tapper /conversion-script"
npm test   # runs scripts/validate-template.js
```

No secrets, no network, no dependencies. Checks:

1. `metadata.yaml` parses and `versions[0].sha` is a real commit reachable in
   this checkout (via `git cat-file -t <sha>`, only when run inside a git repo).
2. `template.tpl` contains every required GTM section
   (`___INFO___`, `___TEMPLATE_PARAMETERS___`, `___SANDBOXED_JS_FOR_WEB_TEMPLATE___`,
   `___WEB_PERMISSIONS___`, `___TESTS___`).
3. The embedded JSON blocks (`___INFO___`, `___TEMPLATE_PARAMETERS___`,
   `___WEB_PERMISSIONS___`) are valid JSON.

This is also the CI gate — `.github/workflows/test.yml` runs `npm test` on
push to `master` and on every PR targeting it. It deliberately does NOT
execute the `___TESTS___` sandbox scenarios below — Google publishes no
standalone runner for those outside the template editor.

---

## Layer 2 — Sandbox scenarios (`___TESTS___` in `template.tpl`)

Run these in GTM: **Templates → Tapper - Conversion Script → Tests tab →
Run All Tests.** Each scenario mocks `data`, `gtmOnSuccess`/`gtmOnFailure`,
and `callInWindow`, then asserts on the call.

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
