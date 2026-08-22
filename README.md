# Aksara

> **Aksara** — Sanskrit/Indonesian for "letter / character / script." A single
> shared source of truth for the words in your app, on iOS and Android.

Cross-platform **live localization runtime** for native mobile. iOS (Swift) and
Android (Kotlin) load translations from a **single shared i18next-style JSON source
of truth** and render them in the UI, with three defining capabilities:

1. **Over-the-air (OTA) updates** — fetch a newer bundle at runtime and swap it in
   live, no app-store release needed.
2. **O(1) lookup** — JSON is flattened to a hash map, parsed off the main thread.
3. **Live UI reflection** — language switches and OTA updates update the visible UI
   in real time.

Both libraries expose a **mirrored API** — same method names, same behavior — so
iOS and Android stay in sync by construction.

## Status

| Platform | Package | v1 (core + OTA + declarative UI) |
|----------|---------|----------------------------------|
| iOS / Swift | [`ios/`](ios/) | ✅ core + OTA + SwiftUI — `swift test` green (47 tests) |
| Android / Kotlin | [`android/`](android/) | ✅ core + OTA — `./gradlew :aksara-core:test` green (47 tests); Compose layer source provided (needs Android SDK) |

The two libraries are mirrored 1:1 — same API, same behavior, **47 matching tests each**.

The [phased roadmap](docs/DESIGN.md) is: **v1** the working 80% (this), **v2** the
imperative XIB/`app:locKey` binding registry + signed payloads, **v3** reach.

## Install

**iOS** — Swift Package Manager, CocoaPods, or Carthage (see the full
[installation guide](docs/installation.md)). Quickest (SPM):

```swift
// Package.swift
dependencies: [ .package(url: "https://github.com/iQbalADR/aksara.git", from: "0.1.0") ],
targets: [ .target(name: "App", dependencies: [
    .product(name: "Aksara", package: "aksara"),
    .product(name: "AksaraSwiftUI", package: "aksara"),
]) ]
```

**Android** — Maven Central (see [android/README.md](android/README.md)):

```kotlin
dependencies {
    implementation("io.github.iqbaladr:aksara-core:0.1.0")
    implementation("io.github.iqbaladr:aksara-compose:0.1.0") // optional Compose bindings
}
```

## 60-second quickstart (iOS)

Bundle an `en.json` (see [docs/format.md](docs/format.md)) and configure at startup:

```swift
import Aksara

Localizer.shared.configure(.init(
    defaultLanguage: "en",
    fallbackLanguage: "en",
    bundledResource: "en",                                  // sync-loaded at startup
    remoteURL: URL(string: "https://cdn.example.com/i18n/") // optional OTA
))
```

Look things up:

```swift
Localizer.shared.t("common.welcome", args: ["name": "Oncom"]) // "Welcome, Oncom!"
Localizer.shared.t("common.items", count: 3)                  // plural-aware
```

Switch language live, or pull an OTA update:

```swift
Localizer.shared.setLanguage("id")          // UI updates live
await Localizer.shared.checkForUpdates()      // fetch + atomic swap, last-good on failure
```

### SwiftUI — updates itself

```swift
import AksaraSwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            LocText("common.welcome", args: ["name": "Oncom"])
            LocText("common.items", count: cartCount)
            Button("Bahasa Indonesia") { LocalizationManager.shared.setLanguage("id") }
        }
    }
}
```

`LocText` (and anything reading through `LocalizationManager`) re-renders
automatically on every language switch or OTA swap — no manual refresh.

## Architecture

```
core-spec (docs/format.md — documented format + behavior, language-agnostic)
   │
   ├── ios/   Localizer, Flattener, PluralResolver, Interpolator,
   │            SchemaValidator, DiskCache, OTAUpdater  (+ AksaraSwiftUI)
   │
   └── android/  mirror of the above                     (+ Compose)
```

Modular per concern so a contributor can touch one thing: `PluralResolver`
(one rule per language family), `Interpolator`, `OTAUpdater`, and — in v2 — one
binding class per UI widget. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Building & testing (iOS)

The `Package.swift` manifest is at the repo root; the Swift sources live under
[`ios/`](ios/).

```bash
swift build
swift test

# Build distributable XCFrameworks (for Carthage / manual integration):
./scripts/build-xcframework.sh
```

## Building & testing (Android)

The Kotlin core is a pure JVM library (no Android SDK needed to test it):

```bash
cd android
./gradlew :aksara-core:test    # 47 JVM unit tests, mirror of the Swift suite
```

The Compose UI layer (`aksara-compose`) needs an Android SDK — see
[android/README.md](android/README.md).

## Security

- Every downloaded bundle is **schema-validated** before it can replace the live
  table; malformed payloads are rejected and last-good is kept.
- The OTA endpoint supports **certificate pinning**
  (`base64(SHA-256(DER cert))` pins).
- Signed-payload mode is planned for v2.
- Downloading strings (data, not code) is store-compliant.

## License

[MIT](LICENSE) © iQbalADR
