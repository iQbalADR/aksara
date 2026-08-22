# Aksara — Android / Kotlin

The Kotlin runtime, mirrored 1:1 with the Swift library in [`../swift/`](../swift/).
Same method names, same behavior, mirrored tests.

| Module | Status | Notes |
|---|---|---|
| `aksara-core` | ✅ implemented — **47 tests green** (`./gradlew :aksara-core:test`) | Pure Kotlin/JVM, no Android dependency |
| `aksara-compose` | 🚧 source provided; needs Android SDK to build | Jetpack Compose layer (mirror of `AksaraSwiftUI`) |

> `aksara-core` is deliberately a **pure Kotlin/JVM** library so it builds and
> unit-tests without the Android SDK (exactly mirroring how the Swift core is testable
> without a device). `aksara-compose` needs the Android Gradle Plugin + SDK, so it's
> excluded from the default build until an SDK is present.

## Requirements

- **JDK 17+**
- Gradle wrapper included (`./gradlew`)
- For `aksara-compose`: Android SDK + `compileSdk 34`, `minSdk 24`

## Build & test

```bash
cd kotlin
./gradlew :aksara-core:test        # runs the 47 JVM unit tests
./gradlew :aksara-core:build
```

To enable the Compose module, install an Android SDK and uncomment
`include(":aksara-compose")` in [settings.gradle.kts](settings.gradle.kts).

## Mirrored public API

Same method names and behavior as Swift (see `../swift/Sources/Aksara/`).

```kotlin
val loc = Localizer.instance
loc.configure(LocalizationConfig(
    defaultLanguage = "en",
    fallbackLanguage = "en",
    bundledResource = "en",
    remoteUrl = "https://cdn.example.com/i18n/",
    bundledLoader = { code -> context.assets.open("$code.json").readBytes() }, // Android
    cacheDir = context.cacheDir,
))

loc.t("common.welcome", mapOf("name" to "Oncom"))  // "Welcome, Oncom!"
loc.t("common.items", count = 3)                    // plural-aware
loc.setLanguage("id")                               // triggers live update
loc.checkForUpdates()                               // suspend: OTA fetch + atomic swap
```

### Compose — updates itself

```kotlin
import com.aksara.compose.locString

@Composable
fun Welcome(cartCount: Int) {
    Column {
        Text(locString("common.welcome", mapOf("name" to "Oncom")))
        Text(locString("common.items", count = cartCount))
        Button(onClick = { Localizer.instance.setLanguage("id") }) { Text("Bahasa Indonesia") }
    }
}
```

`locString(...)` collects the core's `revision` StateFlow, so it recomposes on every
language switch or OTA swap.

## Module ↔ Swift file map

| Kotlin | Swift | Responsibility |
|---|---|---|
| `Flattener.kt` | `Flattener.swift` | nested JSON → `Map<String, String>` |
| `Interpolator.kt` | `Interpolator.swift` | `{{var}}` replacement |
| `PluralResolver.kt` / `PluralRules.kt` | `PluralResolver.swift` / `PluralRules.swift` | `(lang, count) → category`; en/id/ja/ar |
| `SchemaValidator.kt` | `SchemaValidator.swift` | validate before swap |
| `TranslationTable.kt` | `TranslationTable.swift` | immutable flattened table |
| `DiskCache.kt` | `DiskCache.swift` | last-good bundle + ETag persistence |
| `RemoteBundleFetcher.kt` | `RemoteBundleFetcher.swift` | conditional GET + cert pinning |
| `CertificatePinner.kt` | `CertificatePinner.swift` | `base64(SHA-256(DER cert))` pinning |
| `OtaUpdater.kt` | `OTAUpdater.swift` | fetch → validate → build → last-good |
| `Localizer.kt` | `Localizer.swift` | orchestration, `t`, atomic swap, `revision` |
| `aksara-compose/LocalizedText.kt` | `AksaraSwiftUI/*` | `locString()` / `LocText` live UI |

## Parity notes

- **Atomic swap:** Swift swaps an immutable `TranslationTable` under `NSLock`; Kotlin
  uses `AtomicReference<State>` — lock-free reads for the hot `t(...)` path.
- **Off-main parsing → main publish:** Swift `async`; Kotlin coroutines
  (`Dispatchers.IO` to fetch, `Dispatchers.Default` to parse).
- **Change broadcast:** Swift posts `Notification.Name.aksaraDidChange`; Kotlin
  exposes `revision: StateFlow<Int>` (Compose collects it).
- **Cert pinning:** same pin format — `base64(SHA-256(DER cert))` — via a JDK
  `X509TrustManager` that validates the chain first, then checks pins.
- **Distribution:** Maven Central via Gradle; keep major/minor aligned with Swift.

## Publishing (Kotlin representation of a bool leaf)

Note one intentional platform difference: a JSON boolean leaf stringifies to
`"true"`/`"false"` on Kotlin (kotlinx-serialization) vs `"1"`/`"0"` on Swift
(`NSNumber`). Author bundles with string values to avoid relying on either.

## v2 (filed once v1 lands)

- Android XML/View binding registry via a custom `app:locKey` attribute on a
  `LocTextView` (mirrors iOS `LocLabel`).
- Signed-payload mode.
