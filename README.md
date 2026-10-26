# Coin Values: Coin Identifier

An iPhone app (SwiftUI, iOS 17+) that identifies a coin from photos of its front and back and shows the year, mint mark, rarity and an estimated value range, plus a collection with its total estimated value.

- **App Store name:** Coin Values: Coin Identifier (subtitle: Scan Old Coins Worth Money)
- **Bundle ID:** `com.coinvalues.identifier` · **Apple ID:** 6826951196 · **Team:** ZUCC9R4PP4
- **Subscriptions (group "Coin Values Pro"):** `com.coinvalues.identifier.weekly` ($4.99/week), `com.coinvalues.identifier.yearly` ($29.99/year, 3-day free trial)

## How it works

| Piece | Where |
|---|---|
| App | `CoinValues/` (XcodeGen spec in `project.yml`) |
| Identification API | `server/`, a Vercel function at `https://coin-values-api.vercel.app/api/identify` |
| Website, privacy policy, support | `site/`, published from the public repo [Jimtarfas/coin-values-site](https://github.com/Jimtarfas/coin-values-site) to https://jimtarfas.github.io/coin-values-site/ |
| App Store listing | `marketing/aso/listing.json`, applied with `node scripts/apply-metadata.mjs` |
| Screenshots | `scripts/capture-screens.sh` → `scripts/make-store-screenshots.swift` → `node scripts/upload-screenshots.mjs` |

The app sends two 768 px JPEGs plus the StoreKit 2 signed transaction to the server. The server:

1. rejects images over 800 px (this bounds input tokens),
2. verifies the signed transaction against Apple Root CA G3 with `@apple/app-store-server-library` (Sandbox and Production only) and checks the subscription is active,
3. calls Claude Sonnet 5.5 with thinking off, low effort, structured output and a 1,000-token cap.

A scan costs about 1.2¢ (measured: ~3.2k input + ~550 output tokens). The worst case is about 1.7¢, under the 2¢ budget.

Values are labelled as estimates everywhere, and the app asks for consent before sending the first photos to the AI service (guideline 5.1.2(i)).

## Build

```bash
xcodegen generate
```

Build output goes to `/Users/nouhe/Builds/CoinValues` because code signing fails inside `~/Desktop`.

Debug builds read `Config/Secrets.xcconfig` (gitignored), which holds `DEV_BYPASS_TOKEN`. That token lets local StoreKit-test purchases scan, since Xcode-signed transactions can't be verified by the server. Release builds never contain it.

## Server

```bash
cd server && npm install && npx tsc --noEmit -p . && vercel deploy --prod
```

Environment variables on Vercel: `ANTHROPIC_API_KEY`, `DEV_BYPASS_TOKEN`.

## Screenshots

```bash
scripts/capture-screens.sh <simulator-udid> marketing/screenshots/raw
swift scripts/make-store-screenshots.swift marketing/aso/screenshot-captions.json marketing/screenshots/raw marketing/screenshots/en-US-6.9 1320 2868
swift scripts/make-store-screenshots.swift marketing/aso/screenshot-captions.json marketing/screenshots/raw marketing/screenshots/en-US-6.5 1284 2778
```

The demo data in `marketing/demo/` comes from real identifications of public-domain coin photos (Wikimedia Commons, US Mint and Smithsonian NNC).
