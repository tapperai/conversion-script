# Tapper - Conversion Script — GTM Template

Records a conversion event via the [Tapper](https://tapper.ai) monitoring script.

## Setup

1. Import this template into your GTM workspace via the **Community Template Gallery**.
2. Create a new tag using the **Tapper - Conversion Script** template.
3. Enter your **Public Key (pk)** from the [Tapper dashboard](https://tapper.ai) (Settings → Public Key).
4. Optionally set a **Conversion Value** (defaults to `1`; only used when
   **Order Value** is empty).
5. Map **Order Value** to your order total variable (e.g. `{{Ecommerce Value}}`)
   to record the order amount. Leave it empty to record a plain conversion.
6. Optionally set **Currency** (3-letter code, e.g. `EUR`; leave empty to use
   your ad account's currency) and a **Transaction ID** (your order/transaction
   id — enables value corrections).
   Optionally tick **Send the order id when the order value is 0** (off by
   default): see "What it does".
7. Set a trigger that fires on your conversion event (e.g. a purchase or sign-up).
8. Publish your container.

## Parameters

| Name | Display name | Required | Description |
|------|--------------|----------|-------------|
| `pk` | Public Key (pk) | Yes | Your Tapper Public Key (`pk_live_...` or `pk_test_...`). |
| `conversion` | Conversion Value | No | Legacy conversion value, defaults to `1`. Provided string values are coerced to a number; a non-numeric value records as `1`. Only used when **Order Value** is empty. |
| `orderValue` | Order Value | No | Your order total, e.g. `{{Ecommerce Value}}`. Coerced to a number; if it is not a positive number the tag falls back to the legacy conversion — the conversion is never dropped. |
| `currency` | Currency | No | 3-letter code, e.g. `EUR`. Leave empty to use your ad account's currency. |
| `transactionId` | Transaction ID | No | Your order/transaction id. Enables value corrections. |
| `sendOrderIdWithZeroValue` | Send the order id when the order value is 0 | No | Checkbox, off by default. When ticked, an order whose **Order Value** is exactly `0` (e.g. `0`, `'0'`, `'0.00'`) and that has a **Transaction ID** is recorded as `tapper.push(0, currency, transactionId)` (the id as a string) instead of a plain conversion without the id. With it off nothing changes. |

## Requirements

- A Tapper account — [sign up at tapper.ai](https://tapper.ai)
- Your Public Key (`pk_live_...` or `pk_test_...`)

## What it does

On fire, the tag ensures the Tapper monitoring script is loaded (injecting and
initialising it with your Public Key on first use), then records the conversion:

- **Order Value set** — calls `tapper.push(orderValue, currency, transactionId)`
  (amount-first). Currency omitted → your connected ad account's default
  currency applies.
- **Order Value empty** — calls `tapper.push(conversion)`, the legacy path,
  exactly as before.
- **Order Value 0** — with **Send the order id when the order value is 0**
  off (the default), the legacy `tapper.push(conversion)`, exactly as before.
  With it ticked and a Transaction ID set, `tapper.push(0, currency,
  transactionId)`, so the order id of a zero-value order is recorded. A
  negative, non-numeric or blank Order Value always records the legacy
  conversion.

## Releasing (maintainers)

A new `metadata.yaml` version on `master` is the release: the GTM Community
Template Gallery publishes from `metadata.yaml`, so a push that adds no
`versions[]` entry releases nothing. Each `versions[].sha` must be a REAL commit sha, which
forces a two-commit dance per release:

1. Commit the `template.tpl` change and read its sha with `git rev-parse HEAD`.
2. Commit a new `metadata.yaml` `versions[]` entry pointing at that sha (with
   `changeNotes`).

Never point a version entry at a sha that does not exist yet. If the `template.tpl` change goes through a PR, merge it first and take its sha from `master`: a squash or rebase merge rewrites it. Maintainers open and merge their own release PRs: PRs merge directly as merge commits (so every sha in the PR survives; there is no merge queue), and the required check `Validate template.tpl (pre-deploy gate)` (`npm test`) runs on the ready PR. Both commits of the dance can ride in one PR, since the merge commit keeps the template commit's sha. Before marking the release PR ready, run `npm test`, run the `___TESTS___` scenarios in the GTM template editor's Tests tab (`npm test` runs them in a local emulator; GTM's own runner is the authoritative one), and get one code review when the change alters how conversions or order values are recorded. Merging a new `metadata.yaml` version to `master` is the release.
