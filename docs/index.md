# Aksara

**Cross-platform live localization runtime for iOS & Android.** One shared
i18next-style JSON source of truth, over-the-air updates, O(1) lookup, and live
SwiftUI / Jetpack Compose UI — with a **mirrored Swift/Kotlin API** kept in lockstep
by mirrored tests.

[Get started — iOS](installation.md){ .md-button .md-button--primary }
[Get started — Android](android.md){ .md-button }

---

## Why Aksara

- **Over-the-air updates** — ship new translations without an app-store release.
- **O(1) lookup** — JSON is flattened to a hash map, parsed off the main thread.
- **Live UI** — language switches and OTA swaps update the visible UI in real time
  (SwiftUI **and** Jetpack Compose).
- **One source of truth** — the same i18next JSON on both platforms.
- **Fintech-grade** — schema validation + certificate pinning on the update endpoint.

## Install

=== "iOS · Swift Package Manager"

    ```swift
    // Package.swift
    dependencies: [ .package(url: "https://github.com/iQbalADR/aksara.git", from: "0.1.0") ]
    ```

    Also available via **CocoaPods** and **Carthage** — see [iOS install](installation.md).

=== "Android · Gradle"

    ```kotlin
    dependencies {
        implementation("io.github.iqbaladr:aksara-core:0.1.0")
        implementation("io.github.iqbaladr:aksara-compose:0.1.0") // optional Compose bindings
    }
    ```

    Published to **Maven Central** — see [Android install](android.md).

## Quick look

=== "Swift"

    ```swift
    import Aksara

    Localizer.shared.configure(.init(
        defaultLanguage: "en", fallbackLanguage: "en", bundledResource: "en"
    ))
    Localizer.shared.t("common.welcome", args: ["name": "Oncom"]) // "Welcome, Oncom!"
    Localizer.shared.t("common.items", count: 3)                  // plural-aware
    Localizer.shared.setLanguage("id")                            // live update
    ```

=== "Kotlin"

    ```kotlin
    val loc = Localizer.instance

    loc.configure(LocalizationConfig(
        defaultLanguage = "en", fallbackLanguage = "en", bundledResource = "en"
    ))
    loc.t("common.welcome", mapOf("name" to "Oncom")) // "Welcome, Oncom!"
    loc.t("common.items", count = 3)                   // plural-aware
    loc.setLanguage("id")                              // live update
    ```

!!! tip "Same API, both platforms"
    Every public method exists with the same name and behavior on Swift and Kotlin,
    and both libraries ship with 47 matching unit tests.

## Learn more

- [JSON format](format.md) — how to author your translation bundles.
- [Design &amp; roadmap](https://github.com/iQbalADR/aksara/blob/main/SPEC.md) — architecture and what's planned next.
- [GitHub repository](https://github.com/iQbalADR/aksara)
