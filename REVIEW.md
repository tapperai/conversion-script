# Review guide: conversion-script

A single-file GTM Community Template (`template.tpl`) that records conversions client-side through
`tapper.push`. A new `metadata.yaml` version on `master` IS the release (the Gallery publishes from
it); a merge without one releases nothing. This repo is PUBLIC: findings stay technical. PR history
is short and mostly docs, so this guide comes from the template rules and the sister template's
permission defect (tracking-script#7).

## Proof rule

- Every finding cites `path:line` at the reviewed sha (`git show <sha>:template.tpl`), says which
  conversion is lost, duplicated or wrong, and how you know: `npm test` output or a GTM Preview.
- No `path:line`, no finding.

## Real bugs here (block on these)

- **A conversion sent twice or not at all**: a tag that can fire `tapper.push` more than once per
  conversion, or returns before it pushes, changes customer revenue numbers.
- **Value fields mis-mapped**: value, currency and order id passed under the wrong key or type. They
  feed revenue and must never be invented or defaulted silently.
- **A permission that does not match the call**: GTM checks `access_globals` against the exact dotted
  key and operation (the tracking-script#7 defect). Each window path needs its exact grant, and no
  wider one.
- **A broken release**: the two-commit release (template change, then a `metadata.yaml` `versions`
  entry naming that real sha) done in the wrong order, or an entry pointing at a sha that does not
  exist. See README "Releasing (maintainers)".
- **Public-repo leaks**: customer names, domains, ids, rates, counts or internal table names anywhere,
  the PR body and commit messages included.

## Skip

- `conversion-script-gate` (`.github/workflows/test.yml`, `scripts/validate-template.js` via
  `npm test`) is required; do not restate its output.
- README wording and template field labels that are not wrong.

## Checks worth running

- `npm test`
