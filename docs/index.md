# Aksara

[![Maven Central](https://img.shields.io/maven-central/v/io.github.iqbaladr/aksara-core?label=Maven%20Central&color=indigo)](https://central.sonatype.com/artifact/io.github.iqbaladr/aksara-core)
[![Latest tag](https://img.shields.io/github/v/tag/iQbalADR/aksara?label=release&sort=semver&color=indigo)](https://github.com/iQbalADR/aksara/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/iQbalADR/aksara/blob/main/LICENSE)

**Cross-platform live localization runtime for iOS & Android.** One shared
i18next-style JSON source of truth, over-the-air updates, O(1) lookup, and live
SwiftUI / Jetpack Compose UI — with a **mirrored Swift/Kotlin API** kept in lockstep
by mirrored tests.

[Get started — iOS](installation.md){ .md-button .md-button--primary }
[Get started — Android](android.md){ .md-button }

---

## Why Aksara

- **Over-the-air updates** — ship new translations without an app-store release.
- **Bring your own transport** — Aksara never fetches; you download bundles however
  you like and feed them in with `applyBundle`.
- **Pluggable parsing** — a default i18next parser, or inject your own to accept any
  JSON model.
- **O(1) lookup** — JSON is flattened to a hash map.
- **Live UI** — language switches and applied updates update the visible UI in real
  time (SwiftUI **and** Jetpack Compose).
- **One source of truth** — the same JSON on both platforms.
- **Safe swaps** — every bundle is validated before it can replace the live table.

## Install

=== "iOS · Swift Package Manager"

    ```swift
    // Package.swift
    dependencies: [ .package(url: "https://github.com/iQbalADR/aksara.git", from: "0.2.0") ]
    ```

    Also available via **CocoaPods** and **Carthage** — see [iOS install](installation.md).

=== "Android · Gradle"

    ```kotlin
    dependencies {
        implementation("io.github.iqbaladr:aksara-core:0.2.0")
        implementation("io.github.iqbaladr:aksara-compose:0.2.0") // optional Compose bindings
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
