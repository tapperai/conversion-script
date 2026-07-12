# conversion-script — CLAUDE.md

## Push / deploy guard
This repo IS the deploy: the GTM Community Template Gallery reads `metadata.yaml`
on every push to **master** and publishes from it. Never `git push`, open a PR,
or bump `metadata.yaml` `versions[].sha` without EXPLICIT per-branch approval.
Local commits are fine. Default branch is **master** (not `main`/`dev`).

## What this repo is
A single **Google Tag Manager Community Template** — "Tapper - Conversion Script".
On fire it ensures the Tapper monitor script (`https://monitor.tapper.ai/bundle.js`)
is loaded (injecting + `tapper.init(pk)` on first use), then records a conversion
via `tapper.push(conversionValue)`. Customers install it in their own GTM
container. No server, no build, no runtime we host — the whole product is
`template.tpl`. Not a Node service despite the `package.json`.

## Stack
- **GTM sandboxed JS** (a restricted subset — NOT browser JS: no `document`,
  no `window`, no free functions; everything comes from `require(...)` GTM APIs
  like `injectScript`, `callInWindow`, `copyFromWindow`, `makeNumber`,
  `logToConsole`).
- Node 20 is used ONLY to run the validation gate. No third-party npm deps.

## Files
- `template.tpl` — the entire template. Sections: `___INFO___`,
  `___TEMPLATE_PARAMETERS___`, `___SANDBOXED_JS_FOR_WEB_TEMPLATE___` (the logic),
  `___WEB_PERMISSIONS___`, `___TESTS___`. **Edit the JS in the SANDBOXED_JS block.**
- `metadata.yaml` — version list the Gallery deploys from; each entry needs a
  real commit `sha`.
- `scripts/validate-template.js` — the gate (`npm test`).
- `.github/workflows/test.yml` — runs `npm test` on push/PR to master.
- `README.md` — end-user (GTM operator) install docs.

## Gate command (run before every commit)
```
npm test        # = node scripts/validate-template.js
```
Checks: `metadata.yaml` parses + `versions[0].sha` is a real commit in this
checkout; `template.tpl` has all required sections; the JSON blocks (`___INFO___`,
`___TEMPLATE_PARAMETERS___`, `___WEB_PERMISSIONS___`) are valid JSON. It exits 1
on failure — read the real exit code, don't pipe it through `head`. It does NOT
run the `___TESTS___` sandbox scenarios (Google ships no standalone runner);
run those in the GTM template editor "Tests" tab before publishing.

## Conventions
- Template params: `pk` (required, `pk_live_...`/`pk_test_...`) and `conversion`
  (optional, defaults to `"1"`, coerced via `makeNumber`).
- Every global/function the JS touches must be declared in `___WEB_PERMISSIONS___`
  `access_globals` (read/write/execute flags) and every injected URL in
  `inject_script` `urls`. Adding a new `callInWindow`/`copyFromWindow` key or a
  new script host that ISN'T listed = the Gallery rejects the submission and the
  tag fails at runtime. Keep permissions and code in sync.
- Failure path: on any error call `data.gtmOnFailure()` and `return`; on success
  call `data.gtmOnSuccess()` exactly once.

## What not to do
- Don't write standard browser JS in the sandboxed block (no `window`/`document`/
  `fetch`/inline functions) — only GTM `require` APIs.
- Don't change the monitor script host (`monitor.tapper.ai`) or the global names
  (`tapper`, `tapper.init`, `tapper.push`) without also updating
  `___WEB_PERMISSIONS___`.
- Don't hand-edit or reuse a `metadata.yaml` sha that isn't a real commit — the
  gate fails and the Gallery deploy breaks.
- Don't treat this as a buildable Node app; there's nothing to `npm run build`.

## Deploy
Merge/push to `master` → GTM Community Template Gallery picks up the new
`metadata.yaml` version. Add a new `versions[]` entry (with the release commit
`sha` + `changeNotes`) to ship a change.
