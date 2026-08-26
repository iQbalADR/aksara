# Aksara — Android / Kotlin

The Kotlin runtime, mirrored 1:1 with the Swift library in [`../ios/`](../ios/).
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

## Install (Gradle)

Published to **Maven Central** as `io.github.iqbaladr`:

```kotlin
dependencies {
    implementation("io.github.iqbaladr:aksara-core:0.1.0")       // core runtime (JAR)
    implementation("io.github.iqbaladr:aksara-compose:0.1.0")    // Compose bindings (AAR), optional
}
```

> `aksara-core` is a pure-Kotlin/JVM library, so it ships as a **JAR** (no Android
> resources/manifest — Android apps consume it fine). `aksara-compose` depends on
> Jetpack Compose and ships as an **AAR**.

## Build & test

```bash
cd android
./gradlew :aksara-core:test        # runs the 47 JVM unit tests
./gradlew :aksara-core:build
```

The Compose module needs an Android SDK, so it's excluded from the default build.
Opt in with `-PwithAndroid` (with an SDK installed):

```bash
./gradlew -PwithAndroid :aksara-compose:assembleRelease   # produces the AAR
```

## Publishing to Maven Central (maintainers)

Publishing uses the [Vanniktech maven-publish plugin](https://github.com/vanniktech/gradle-maven-publish-plugin)
(handles the core JAR and the compose AAR uniformly, plus sources/javadoc jars and
GPG signing). It runs automatically on a `v*` tag via
[`.github/workflows/publish.yml`](../.github/workflows/publish.yml).

**One-time setup:**
1. Create a **Sonatype Central Portal** account and verify the `io.github.iqbaladr`
   namespace (GitHub-verifiable).
2. Generate a **GPG key** and publish it to a keyserver.
3. Add these **repository secrets**:
   - `MAVEN_CENTRAL_USERNAME`, `MAVEN_CENTRAL_PASSWORD` — Central Portal token.
   - `SIGNING_KEY` — ASCII-armored GPG private key; `SIGNING_KEY_PASSWORD` — its passphrase.

**Release:** bump `VERSION_NAME` in [gradle.properties](gradle.properties), tag
`vX.Y.Z`, and push — or run the workflow manually. Locally:

```bash
./gradlew publishAndReleaseToMavenCentral -PwithAndroid
```

Keep the version aligned with the iOS release.

## Mirrored public API

Same method names and behavior as Swift (see `../ios/Sources/Aksara/`).

```kotlin
val loc = Localizer.instance
loc.configure(LocalizationConfig(
    defaultLanguage = "en",
    fallbackLanguage = "en",
    bundledResource = "en",
    bundledLoader = { code -> context.assets.open("$code.json").readBytes() }, // Android
    cacheDir = context.cacheDir,
    // parser = MyCustomParser(),  // optional: accept your own JSON model
))

loc.t("common.welcome", mapOf("name" to "Oncom"))  // "Welcome, Oncom!"
loc.t("common.items", count = 3)                    // plural-aware
loc.setLanguage("id")                               // triggers live update

// Over-the-air: you fetch (any client), Aksara parses + swaps:
loc.applyBundle(myHttpClient.get(".../id.json"), "id")
loc.update("id") { lang -> myHttpClient.get(".../$lang.json") }  // convenience
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
language switch or applied update.

## Module ↔ Swift file map

| Kotlin | Swift | Responsibility |
|---|---|---|
| `Flattener.kt` | `Flattener.swift` | nested JSON → `Map<String, String>` |
| `Interpolator.kt` | `Interpolator.swift` | `{{var}}` replacement |
| `PluralResolver.kt` / `PluralRules.kt` | `PluralResolver.swift` / `PluralRules.swift` | `(lang, count) → category`; en/id/ja/ar |
| `SchemaValidator.kt` | `SchemaValidator.swift` | validate the default i18next format |
| `TranslationParser.kt` | `TranslationParser.swift` | pluggable format → flat map (`I18nextParser` default) |
| `TranslationTable.kt` | `TranslationTable.swift` | immutable flattened table |
| `DiskCache.kt` | `DiskCache.swift` | last-good bundle warm-start persistence |
| `Localizer.kt` | `Localizer.swift` | orchestration, `t`, `applyBundle`, atomic swap, `revision` |
| `aksara-compose/LocalizedText.kt` | `AksaraSwiftUI/*` | `locString()` / `LocText` live UI |

> Aksara does **no** networking — there's no fetcher or certificate pinner. You fetch
> bundles yourself and hand them to `applyBundle`.

## Parity notes

- **Atomic swap:** Swift swaps an immutable `TranslationTable` under `NSLock`; Kotlin
  uses `AtomicReference<State>` — lock-free reads for the hot `t(...)` path.
- **Custom parsing:** Swift `TranslationParser` protocol; Kotlin `fun interface
  TranslationParser` — inject your own to accept any JSON model.
- **Change broadcast:** Swift posts `Notification.Name.aksaraDidChange`; Kotlin
  exposes `revision: StateFlow<Int>` (Compose collects it).
- **Distribution:** Maven Central via Gradle; keep major/minor aligned with Swift.

## Publishing (Kotlin representation of a bool leaf)

Note one intentional platform difference: a JSON boolean leaf stringifies to
`"true"`/`"false"` on Kotlin (kotlinx-serialization) vs `"1"`/`"0"` on Swift
(`NSNumber`). Author bundles with string values to avoid relying on either.

## v2 (filed once v1 lands)

- Android XML/View binding registry via a custom `app:locKey` attribute on a
  `LocTextView` (mirrors iOS `LocLabel`).
- Signed-payload mode.
