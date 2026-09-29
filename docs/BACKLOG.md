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

- Idempotent bundle loader + confirmation-page placement rule: in progress, open PR #3 (`fix/conversion-tag-idempotent-loader`, opened 2026-09-07, no activity since). Not released: `metadata.yaml` `versions[0]` is still `dc40adcd`. Do not merge #3 as written: its text breaks this repo's public-repo rule (CLAUDE.md), so land the change from a clean branch with clean text and a clean squash message, then close #3. It changes how conversions are recorded, so it gets one code review. When it merges, move this line (do not add a second entry) to "P0 — needs verification" with the merge sha and "not released". Move it to Done only after the `metadata.yaml` version commit lands, citing that release sha as the existing Done lines do; a merge alone releases nothing.

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
