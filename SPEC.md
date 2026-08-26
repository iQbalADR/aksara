# Project: Aksara — Cross-Platform Live Localization Runtime (iOS + Android)

> **Name: Aksara** — Sanskrit/Indonesian for "letter / character / script,"
> fitting a localization runtime and the project's "global by design" ethos. The
> Swift package/products are `Aksara` / `AksaraSwiftUI`; the Kotlin modules are
> `aksara-core` / `aksara-compose` (package `com.aksara`); the CLI (if it ships in
> v3) is `aksara`.
>
> Repo: **https://github.com/iQbalADR/aksara**. Still to confirm before first
> publish: the name is free on Swift Package Index, CocoaPods trunk
> (`pod trunk info Aksara`), and your Maven Central group.

---

## What this is

A pair of native mobile libraries — one Swift (iOS), one Kotlin (Android) —
that load translations from a **single shared i18next-style JSON source of
truth** and render them in the UI, with three defining capabilities:

1. **Over-the-air (OTA) updates** — fetch a newer translation bundle at
   runtime and swap it in live, no app-store release needed.
2. **Top-tier lookup performance** — O(1) key lookup, off-main-thread parsing.
3. **Live UI reflection** — when the language changes or an OTA update lands,
   the visible UI updates in real time, across SwiftUI/Compose **and** legacy
   XIB/UIKit + Android XML views.

Both libraries expose a **mirrored API** (same method names, same behavior,
mirrored tests). That symmetry is the product's guarantee that iOS and Android
stay in sync — they read the same JSON through the same interface.

## Why it exists

Teams shipping the same app on iOS and Android maintain two divergent native
localization systems (`.xcstrings`/`.strings` vs `res/values/strings.xml`).
The web world long ago standardized on i18next-style JSON. This project brings
that single-source-of-truth model to native mobile **and** adds OTA + live
binding, which even most web setups don't have natively. It is "global by
design": contributors show up to add handling for their own language's plural
rules, so the project naturally attracts international collaborators.

## Scope (strict)

- **In scope:** iOS/Swift and Android/Kotlin native runtime libraries only.
- **Out of scope (v1):** web/JS, React Native / Flutter / KMP-shared UI,
  backend localization, machine translation, a translation-editor GUI.
  Say no to these to keep scope tight and first PRs easy.

---

## The JSON format (shared spec — define this first)

i18next-compatible so existing web tooling and translators can be reused.

- **Top-level keys = namespaces.** Nested objects allowed; addressed by dot
  path: `t("auth.biometric_prompt")`.
- **Interpolation:** `{{var}}` placeholders.
- **Pluralization:** CLDR plural categories as sub-keys
  (`zero`, `one`, `two`, `few`, `many`, `other`). Resolver maps
  `(language, count) -> category`. `other` is always required as fallback.
- **One file per language**, e.g. `en.json`, `id.json`, `ja.json`.

```json
{
  "common": {
    "welcome": "Welcome, {{name}}!",
    "items": {
      "one": "{{count}} item",
      "other": "{{count}} items"
    }
  },
  "auth": {
    "login": "Log in",
    "biometric_prompt": "Authenticate with Face ID"
  }
}
```

**Fallback chain for a lookup:** active language → configured `fallbackLng` →
the raw key itself (never crash, never show blank).

---

## Mirrored public API

Keep method names identical across platforms. Any addition to one library is a
PR obligation to add the twin on the other (enforced in `CONTRIBUTING.md`).

**Swift**
```swift
let loc = Localizer.shared
loc.configure(.init(
    defaultLanguage: "en",
    fallbackLanguage: "en",
    bundledResource: "en"        // sync-loaded at startup
    // parser: MyCustomParser()  // optional — default is I18nextParser
))
loc.t("common.welcome", args: ["name": "Oncom"])   // -> "Welcome, Oncom!"
loc.t("common.items", count: 3)                    // plural-aware
loc.setLanguage("id")                              // triggers live update
try loc.applyBundle(data, for: "id")               // you fetched `data`; parse + atomic swap
```

**Kotlin (mirror)**
```kotlin
val loc = Localizer.instance
loc.configure(LocalizationConfig(
    defaultLanguage = "en",
    fallbackLanguage = "en",
    bundledResource = "en",
    // parser = MyCustomParser(),  // optional — default is I18nextParser
))
loc.t("common.welcome", mapOf("name" to "Oncom"))
loc.t("common.items", count = 3)
loc.setLanguage("id")
loc.applyBundle(data, "id")        // you fetched `data`; parse + atomic swap
```

---

## Feature requirements & mechanisms

### 1. Over-the-air updates (consumer-driven, network-agnostic)
- Bundle a default JSON in app resources. **The SDK does not fetch** — the consumer
  downloads newer bundles with whatever transport they choose and calls
  `applyBundle(data, for: language)` (or the `update(for:using:)` convenience that
  runs a caller-supplied fetch closure).
- **Pluggable parsing:** a `TranslationParser` (default `I18nextParser`) turns raw
  bytes into the flat lookup map, so consumers can inject their own JSON model.
- **Atomic swap:** parse & validate the payload, build the new table, then replace
  **one immutable in-memory reference**. Never mutate in place.
- **Last-good:** on a parse/validation failure, keep the current table. Never leave
  the app in a half-updated state.
- **Disk cache:** persist the last applied bundle; re-parse it on next launch (warm
  start). Change detection and transport security are the consumer's responsibility.

### 2. Performance
- On load, **flatten** the nested JSON into a single `[String: String]`
  (Swift) / `Map<String, String>` (Kotlin) so every `t(...)` is an O(1)
  hash lookup — no tree walking per call.
- **Parse off the main thread**, publish the finished table to the main
  thread.
- Interpolation: simple `{{var}}` replacement first. Only cache compiled
  templates if profiling shows a hot path — do **not** pre-optimize.
- Pluralization: cheap `(lang, count) -> category` lookup, then one dict hit.
- Lookup must never appear in a UI trace. Add a micro-benchmark to prove it.

### 3. Default language: static + in memory
- Load the **bundled base language synchronously at startup** — it's small,
  so first render never waits on disk or network.
- Load other languages and remote updates lazily/async on top.
- Keep only **active + fallback** languages resident; lazy-load and evict
  others rather than holding every language in memory at once.

### 4. Live UI reflection (split into two very different problems)

**4a. Declarative — SwiftUI + Jetpack Compose (the easy 80%, ship first)**
- iOS: `LocalizationManager` as an `ObservableObject` with a `@Published revision`
  counter (deployment floor is **iOS 15**, so use `ObservableObject`/`@Published`
  rather than the iOS-17 `@Observable` macro); provide a `LocText("key", args:)`
  view. Any view observing the manager re-renders when `revision` bumps.
- Android: back the manager with `State` / a `CompositionLocal`; provide a
  `locString("key")` composable. Recomposition on language/OTA change.

**4b. Imperative — XIB/UIKit + Android XML/View (the hard 20%, the differentiator)**
- Build a **binding registry**: UI elements register a localization key and a
  weak self-reference with the manager, and re-apply their text on broadcast.
- iOS: `LocLabel: UILabel` (and friends) with `@IBInspectable var locKey`,
  registering on `awakeFromNib`, updated via `NotificationCenter`.
- Android: custom `app:locKey` attribute on a `LocTextView` etc.,
  registering on inflate, updated via a listener/`LiveData`/`Flow`.
- This lets a dev set a key **in Interface Builder or the XML layout** and
  have it update live. Almost nothing open-source does this cleanly for
  native — this is the star-worthy feature.

**Cautions (write these into the design):**
- **No method swizzling as the default** on either platform — fragile and a
  red flag in a banking/fintech codebase. Offer it only as an explicit opt-in
  module, if at all.
- On Android, do **not** try to override the resource system for raw
  `@string/` XML references (requires invasive `Context` wrapping). The
  custom-view + `app:locKey` route is the supported, contributor-friendly one.

---

## Security (fintech-grade — this is a differentiator, not an afterthought)

- **Validate** every applied bundle before it can replace the live table (the
  `TranslationParser` throws on malformed input); reject bad payloads and keep last-good.
- **Transport security is the consumer's** — Aksara doesn't fetch, so TLS/certificate
  pinning and auth live in the network layer the app already trusts. (No MITM surface
  is added by the SDK.)
- Support an **optional signed-payload mode** — a `TranslationParser` that verifies a
  signature over the JSON before returning entries (a natural fit for the pluggable
  parser).
- Downloading *strings* (data, not code) is App Store / Play Store compliant —
  document this explicitly so adopters aren't scared off. Firebase Remote
  Config does the same thing.

---

## Architecture

```
core-spec (documented format + behavior, language-agnostic)
   │
   ├── ios/   Localizer, TranslationParser, PluralResolver, Interpolator,
   │            BindingRegistry (v2)  (+ SwiftUI + UIKit modules)
   │
   └── android/  mirror of the above         (+ Compose + View modules)
```

- **Modular per concern** so a contributor can touch one thing:
  `PluralResolver`, `Interpolator`, `TranslationParser`, `BindingRegistry`, and one
  binding class per UI widget.
- The **binding registry is the prime contributor surface** — "add live
  binding for `UISegmentedControl`", "add `app:locKey` to `Button`" are
  perfect self-contained `good first issue` tickets.
- Plural rules per language are another clean contributor surface — one file /
  one PR per language family.

---

## Distribution

- iOS: Swift Package Manager (add a Homebrew formula only if a CLI ships).
- Android: Maven Central via Gradle.
- Semantic versioning; keep the two libraries' major/minor versions aligned.

---

## Phased roadmap (ship value early, invite contributors for the hard parts)

**v1 — the working 80%**
- JSON spec + flattened O(1) loader
- Bundled default (sync) + interpolation + CLDR plurals
- Remote fetch with atomic swap + last-good + disk cache
- SwiftUI + Compose live updates
- Mirrored Swift/Kotlin API, mirrored tests, micro-benchmark
- Endpoint pinning + schema validation

**v2 — the hard differentiator**
- Binding registry for XIB/UIKit (`LocLabel` + `@IBInspectable locKey`)
- Binding registry for Android XML/View (`app:locKey`)
- Signed-payload mode

**v3 — reach**
- More widget bindings, more language plural rules (contributor-driven)
- Optional CLI to validate/convert i18next JSON

**Refinements / backlog**
- **Public-key (SPKI) pinning** as an alternative to the current full-certificate
  pinning, so a pin survives certificate renewal on the same key (namespaced pin
  format). Today `CertificatePinner` pins the whole DER cert.
- **Interpolation template caching** — pre-compile/cache templates only if profiling
  shows a hot path (`Interpolator` currently does a plain per-call scan).

---

## Contributor-friendliness

- Tight scope; every widget binding and every language plural set is a
  single-file, single-PR contribution.
- Ship with: `CONTRIBUTING.md`, `good first issue` labels, `hacktoberfest`
  topic, a clear `README` with a 60-second quickstart.
- **API-parity rule:** any public API added to one platform must be added to
  the other in the same or a linked PR. State this in `CONTRIBUTING.md`.

---

## First batch of issues (starter backlog)

1. Define and document the JSON format spec in `/docs/format.md`.
2. Implement the flattener: nested JSON → `[String:String]` (Swift + Kotlin).
3. Implement `t(key)` with `{{var}}` interpolation + fallback chain.
4. Implement `PluralResolver` with CLDR categories (start: en, id, ja, ar).
5. Bundled default language: synchronous startup load.
6. `applyBundle(data, for:)`: parse (via `TranslationParser`) → validate → atomic
   swap → last-good → disk cache (warm start). No networking in the SDK.
7. `TranslationParser` protocol/`fun interface` with a default `I18nextParser`, so
   consumers can inject a custom JSON model.
8. SwiftUI `LocText` + `ObservableObject`/`@Published` revision-based re-render (iOS 15+).
9. Compose `locString` + state/CompositionLocal re-render.
10. Micro-benchmark proving O(1) lookup off the hot path.
11. `CONTRIBUTING.md` with the API-parity rule + `good first issue` guide.
12. `README` quickstart (install → configure → `t()` → switch language live).

*(v2 issues — XIB `LocLabel`, Android `app:locKey`, signed payloads — filed
once v1 lands.)*