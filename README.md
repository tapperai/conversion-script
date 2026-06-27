# Tapper - Conversion Script — GTM Template

Records a conversion event via the [Tapper](https://tapper.ai) monitoring script.

## Setup

1. Import this template into your GTM workspace via the **Community Template Gallery**.
2. Create a new tag using the **Tapper - Conversion Script** template.
3. Enter your **Public Key (pk)** from the [Tapper dashboard](https://tapper.ai) (Settings → Public Key).
4. Optionally set a **Conversion Value** (defaults to `1`).
5. Set a trigger that fires on your conversion event (e.g. a purchase or sign-up).
6. Publish your container.

## Parameters

| Name | Display name | Required | Description |
|------|--------------|----------|-------------|
| `pk` | Public Key (pk) | Yes | Your Tapper Public Key (`pk_live_...` or `pk_test_...`). |
| `conversion` | Conversion Value | No | The conversion value to record. Defaults to `1`. Provided string values are coerced to a number. |

## Requirements

- A Tapper account — [sign up at tapper.ai](https://tapper.ai)
- Your Public Key (`pk_live_...` or `pk_test_...`)

## What it does

On fire, the tag ensures the Tapper monitoring script is loaded (injecting and
initialising it with your Public Key on first use), then records the conversion
by calling `tapper.push` with the conversion value.
