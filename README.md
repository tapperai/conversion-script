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
7. Optionally add rows to **Additional fields** to send extra details about the
   transaction (see "Additional fields").
8. Set a trigger that fires on your conversion event (e.g. a purchase or sign-up).
9. Publish your container.

## Parameters

| Name | Display name | Required | Description |
|------|--------------|----------|-------------|
| `pk` | Public Key (pk) | Yes | Your Tapper Public Key (`pk_live_...` or `pk_test_...`). |
| `conversion` | Conversion Value | No | Legacy conversion value, defaults to `1`. Provided string values are coerced to a number; a non-numeric value records as `1`. Only used when **Order Value** is empty. |
| `orderValue` | Order Value | No | Your order total, e.g. `{{Ecommerce Value}}`. Coerced to a number; if it is not a positive number the tag falls back to the legacy conversion — the conversion is never dropped. |
| `currency` | Currency | No | 3-letter code, e.g. `EUR`. Leave empty to use your ad account's currency. |
| `transactionId` | Transaction ID | No | Your order/transaction id. Enables value corrections. |
| `sendOrderIdWithZeroValue` | Send the order id when the order value is 0 | No | Checkbox, off by default. When ticked, an order whose **Order Value** is exactly `0` (e.g. `0`, `'0'`, `'0.00'`) and that has a **Transaction ID** is recorded as `tapper.push(0, currency, transactionId)` (the id as a string) instead of a plain conversion without the id. With it off nothing changes. |
| `additionalFields` | Additional fields | No | Table of **Name** and **Value** rows, empty by default. Each row adds one field to the conversion; the whole set rides as a 4th argument, `tapper.push(value, currency, transactionId, fields)`. With no rows the tag pushes exactly the arguments it pushed before. See "Additional fields". |

## Additional fields

Each row of **Additional fields** sends one extra detail about the transaction
with the conversion, so the values can be used to shape bidding and to group
conversions. Map the **Value** column to one of your own GTM variables, for
example `{{DLV - voucher_applied}}`.

| Rule | What happens |
|------|--------------|
| Name | Starts with a letter, then letters, numbers or underscores, up to 40 characters. Lowercase with underscores is suggested, e.g. `partner_purchase`. Case is kept, so `Plan` and `plan` are two different fields: pick one spelling. |
| Value | Text of 1 to 100 characters, a number, or `true` / `false`. A number of 8 or more digits is skipped, see **Digits**. |
| Empty | A row with an empty name, or whose variable has no value, is skipped. `0` and `false` are values and are kept. |
| How many | The first 20 fields are kept. An object of more than 200 entries is dropped whole. |
| Lists and objects | Not accepted. Send one value per row. |
| Digits | A value of 8 or more digits made only of digits and separators is skipped: it cannot be told from a phone or card number. Give an id a letter, like `T801884423`. A Unix time in seconds (10 digits) or milliseconds (13 digits) between 2001 and 2033 is kept under a name ending in `_at`, `_time`, `_timestamp`, `_ts`, `_epoch` or `_date`; send a later date, such as a subscription that ends after 2033, as text like `2041-10-21`, which is always kept. |
| Personal data | Also skipped: 32 or more hex characters, a hash, an IP address (with or without a port), an IBAN, an email address, a phone number, a street address, and any field whose name points at a person (`email`, `phone`, `msisdn`, `first_name`, `address`, `postal_code` and the like) or at a secret (`cvv`, `pin`, `otp`, `password`, `token`, `api_key` and the like). |

A field we cannot accept is dropped on its own: the conversion, its value, its
currency and its order id are always recorded.

Send facts about the transaction, never details about the person. A one-time
voucher code points at a person, so send `voucher_applied` rather than the code
itself.

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
- **Additional fields set** - the rows are built into one object and passed as
  the 4th argument of whichever push above applies (the legacy path sends
  `tapper.push(conversion, undefined, undefined, fields)`). With no usable row
  the 4th argument is left off entirely, so the call is the one the tag made
  before the option existed.

## Releasing (maintainers)

A new `metadata.yaml` version on `master` is the release: the GTM Community
Template Gallery publishes from `metadata.yaml`, so a push that adds no
`versions[]` entry releases nothing. Each `versions[].sha` must be a REAL commit sha, which
forces a two-commit dance per release:

1. Commit the `template.tpl` change and read its sha with `git rev-parse HEAD`.
2. Commit a new `metadata.yaml` `versions[]` entry pointing at that sha (with
   `changeNotes`).

Never point a version entry at a sha that does not exist yet. If the `template.tpl` change goes through a PR, merge it first and take its sha from `master`: a squash or rebase merge rewrites it. Maintainers open and merge their own release PRs: PRs merge directly as merge commits (so every sha in the PR survives; there is no merge queue), and the required check `Validate template.tpl (pre-deploy gate)` (`npm test`) runs on the ready PR. Both commits of the dance can ride in one PR, since the merge commit keeps the template commit's sha. Before marking the release PR ready, run `npm test`, run the `___TESTS___` scenarios in the GTM template editor's Tests tab (`npm test` runs them in a local emulator; GTM's own runner is the authoritative one), and get one code review when the change alters how conversions or order values are recorded. Merging a new `metadata.yaml` version to `master` is the release.
