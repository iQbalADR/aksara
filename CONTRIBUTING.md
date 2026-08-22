# Contributing

Thanks for helping! This project is deliberately **tightly scoped** so almost every
contribution is a single file and a single PR.

## The API-parity rule (please read)

The whole value of this project is that iOS and Android read the same JSON through
the **same interface**. So:

> **Any public API added to one platform must be added to the other in the same PR
> or a linked PR, with mirrored tests.**

Method names and behavior must match. If you add `Localizer.t(_:count:)` in Swift,
the Kotlin `Localizer.t(key, count)` twin ships alongside it. A PR that changes only
one side will be asked to add the other before merge.

## Great first contributions

These are self-contained and well-scoped — perfect `good first issue` material:

- **Add a language's plural rules.** One `PluralRule` struct/class + registration +
  a mirrored test. Reference the
  [CLDR plural chart](https://www.unicode.org/cldr/charts/latest/supplemental/language_plural_rules.html).
  Built-ins so far: `en`, `id`, `ja`, `ar`.
- **Add a UI widget binding** (v2): a new `app:locKey`-style binding class for one
  widget (`UIButton`, `UISegmentedControl`, Android `Button`, …).
- **Translations:** add or improve a `*.json` bundle.

## Setup

**Swift** (the `Package.swift` manifest is at the repo root; sources live under `ios/`)
```bash
swift build
swift test        # must be green before you open a PR
```

See [docs/installation.md](docs/installation.md) for how the package is consumed via
SPM / CocoaPods / Carthage.

**Kotlin** — see [android/README.md](android/README.md) (mirror in progress).

## Ground rules

- Match the surrounding code's style, naming, and comment density.
- Add tests for anything you add or fix. Mirror them across platforms.
- Keep the scope tight. Out of scope for now: web/JS, React Native / Flutter /
  KMP-shared UI, backend localization, machine translation, translation-editor GUIs.
- **Commit messages** are authored by you, the human contributor — no tool
  attribution or `Co-Authored-By` bot trailers.

## Adding a plural rule (worked example, Swift)

```swift
// PluralRules.swift
struct FrenchPluralRule: PluralRule {
    func category(for count: Int) -> PluralCategory {
        // CLDR fr: 0 and 1 are `one`, otherwise `other`
        (abs(count) == 0 || abs(count) == 1) ? .one : .other
    }
}
```
```swift
// PluralResolver.makeDefault()
"fr": FrenchPluralRule(),
```
```swift
// PluralResolverTests.swift
func testFrench() {
    XCTAssertEqual(PluralResolver.default.category(for: 0, language: "fr"), .one)
    XCTAssertEqual(PluralResolver.default.category(for: 2, language: "fr"), .other)
}
```

Then add the mirrored Kotlin `FrenchPluralRule` + test in the same/linked PR.
