# Android (Kotlin)

Aksara's Android runtime is published to **Maven Central**.

- `aksara-core` — pure Kotlin/JVM runtime (ships as a **JAR**; no Android resources).
- `aksara-compose` — Jetpack Compose bindings (ships as an **AAR**).

**Requirements:** JDK 17, `minSdk 24`, `compileSdk 34`.

## Install

=== "Kotlin DSL (build.gradle.kts)"

    ```kotlin
    dependencies {
        implementation("io.github.iqbaladr:aksara-core:0.1.0")
        implementation("io.github.iqbaladr:aksara-compose:0.1.0") // optional
    }
    ```

=== "Groovy (build.gradle)"

    ```groovy
    dependencies {
        implementation 'io.github.iqbaladr:aksara-core:0.1.0'
        implementation 'io.github.iqbaladr:aksara-compose:0.1.0' // optional
    }
    ```

Make sure `mavenCentral()` is in your `repositories {}`.

## Configure (at app startup)

```kotlin
val loc = Localizer.instance
loc.configure(LocalizationConfig(
    defaultLanguage = "en",
    fallbackLanguage = "en",
    bundledResource = "en",
    remoteUrl = "https://cdn.example.com/i18n/",                      // optional OTA
    bundledLoader = { code -> context.assets.open("$code.json").readBytes() },
    cacheDir = context.cacheDir,
))
```

## Look things up

```kotlin
loc.t("common.welcome", mapOf("name" to "Oncom")) // "Welcome, Oncom!"
loc.t("common.items", count = 3)                   // plural-aware
loc.setLanguage("id")                              // triggers live update
loc.checkForUpdates()                              // suspend: OTA fetch + atomic swap
```

## Compose — updates itself

```kotlin
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import com.aksara.compose.locString

@Composable
fun Welcome(cartCount: Int) {
    Text(locString("common.welcome", mapOf("name" to "Oncom")))
    Text(locString("common.items", count = cartCount))
}
```

`locString(...)` collects the runtime's `revision` flow, so it **recomposes
automatically** on every language switch or OTA update — no manual refresh.

!!! note "Mirrors the Swift API"
    The method names and behavior match the [iOS runtime](installation.md) exactly.
    See the [JSON format](format.md) for authoring bundles.
