# Backlog

Living list of every TODO the user has called out. When the user mentions
something new, capture it here as a one-line technical paraphrase before
starting work: never verbatim, never customer names, rates, domains or
operator quotes (this is a public repo; see the public-repo rule in
CLAUDE.md). When something
lands, move it under "Done" with the SHA / date.

Categories:

- **P0 — open**: explicitly asked, not shipped yet.
- **P0 — needs verification**: code says done but never end-to-end checked
  with the user; treat as suspect until verified.
- **P1 — open**: asked-for but lower urgency, or feature-parity items the
  user wants but hasn't blocked on.
- **P2 — open**: nice-to-have, future parity, deferred.
- **Done**: shipped + verified.

---

## P0 — open

(Explicitly asked, not shipped yet. Add new items here as the user mentions
them. Each item should have enough context to pick up cold.)

- Confirmation-page placement guidance in the tag editor (a LABEL parameter plus help text on Conversion Value and Order Value saying to fire the tag on the order confirmation page only, never on a landing page): open, not started. Editor text only, no runtime change. Needs a `template.tpl` change plus a `metadata.yaml` release. Split out of closed PR #3.
- Idempotent bundle loader (closed PR #3): dropped 2026-09-30, not re-landed. `master` already skips `injectScript` when `window.tapper` exists (since the initial release) and de-dupes repeat fires with the `tapper-monitor-script` cache token. PR #3's extra `window.tapperObject` branch added nothing: after a clean bundle run `window.tapper` is defined non-configurable and non-writable, so that branch cannot be reached; after a failed run it would block the second copy that the bundle's load-once guard lets recover (the guard needs a live `window.tapper`).

---

## P0 — needs verification

(Implemented somewhere in the build but the user hasn't manually seen it work.
Walk through each one before claiming done.)

---

## P1 — open

(Asked-for but lower urgency, or feature-parity items the user wants but
hasn't blocked on.)

---

## P2 — open

(Nice-to-have, future parity, deferred. Each gets its own spec when
prioritized.)

---

## Meta / hygiene

- Keep this file fresh: each new explicit user ask gets an entry **before** I
  start coding it. After it ships and the user confirms, move it under Done.
- Never silently drop an item — if I push back on scope, note the rationale
  inline.

---

## Done

- Value conversions (Order Value / Currency / Transaction ID); non-numeric or
  out-of-range values fall back to `1` instead of pushing `NaN`/bad amounts.
  Released as `metadata.yaml` version sha `dc40adcd92bded343f73dda758df2c1cc737ea57`.
- Initial release of the Tapper Conversion Script template. Released as
  `metadata.yaml` version sha `62179c382db9008e24664b55e10527715db280b8`.
- Wired `document-first-template` submodule + bootstrapped `docs/` — 2026-08-26.
