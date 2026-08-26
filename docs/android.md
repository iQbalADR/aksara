# Android (Kotlin)

Aksara's Android runtime is published to **Maven Central**.

- `aksara-core` — pure Kotlin/JVM runtime (ships as a **JAR**; no Android resources).
- `aksara-compose` — Jetpack Compose bindings (ships as an **AAR**).

**Requirements:** JDK 17, `minSdk 24`, `compileSdk 34`.

## Install

=== "Kotlin DSL (build.gradle.kts)"

    ```kotlin
    dependencies {
        implementation("io.github.iqbaladr:aksara-core:0.2.0")
        implementation("io.github.iqbaladr:aksara-compose:0.2.0") // optional
    }
    ```

=== "Groovy (build.gradle)"

    ```groovy
    dependencies {
        implementation 'io.github.iqbaladr:aksara-core:0.2.0'
        implementation 'io.github.iqbaladr:aksara-compose:0.2.0' // optional
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
    bundledLoader = { code -> context.assets.open("$code.json").readBytes() },
    cacheDir = context.cacheDir,
    // parser = MyCustomParser(),   // optional: accept your own JSON model
))
```

## Look things up

```kotlin
loc.t("common.welcome", mapOf("name" to "Oncom")) // "Welcome, Oncom!"
loc.t("common.items", count = 3)                   // plural-aware
loc.setLanguage("id")                              // triggers live update
```

## Over-the-air updates — you fetch, Aksara applies

Aksara never downloads anything. Fetch the bytes with whatever client you already use
(OkHttp, Ktor, Retrofit…), then hand them in:

```kotlin
val json: ByteArray = myHttpClient.get("https://cdn.example.com/i18n/id.json")
loc.applyBundle(json, "id")   // parse + validate + atomic swap; last-good on failure

// or let the convenience helper run your fetch for you:
loc.update("id") { lang -> myHttpClient.get("https://cdn.example.com/i18n/$lang.json") }
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
automatically** on every language switch or applied update — no manual refresh.

!!! note "Mirrors the Swift API"
    The method names and behavior match the [iOS runtime](installation.md) exactly.
    See the [JSON format](format.md) for authoring bundles.
