# Installation (iOS / Swift)

Aksara ships two products:

| Product | Import | What it gives you |
|---|---|---|
| `Aksara` | `import Aksara` | Core runtime: `Localizer`, plurals, interpolation, `applyBundle`. No UI dependency. |
| `AksaraSwiftUI` | `import AksaraSwiftUI` | `LocalizationManager` + `LocText` — SwiftUI views that update live. |

Pick your package manager:

| Manager | Builds from | Best for |
|---|---|---|
| [Swift Package Manager](#swift-package-manager) | source | most projects (recommended) |
| [CocoaPods](#cocoapods) | source | apps already on CocoaPods |
| [Carthage](#carthage) | prebuilt XCFrameworks | apps already on Carthage |
| [Manual XCFramework](#manual-xcframework) | prebuilt XCFrameworks | no dependency manager |

> Repo: **https://github.com/iQbalADR/aksara**

## Requirements

- **Xcode 15+**, **Swift 5.9+**
- Deployment targets: **iOS 15+, macOS 12+, tvOS 15+, watchOS 8+**
  (the SwiftUI layer uses `ObservableObject`/`@Published`, so it works on iOS 15).

---

## Swift Package Manager

The `Package.swift` manifest lives at the **repository root**, so the repo is
consumable directly.

### Xcode

1. **File ▸ Add Package Dependencies…**
2. Enter the repo URL: `https://github.com/iQbalADR/aksara.git`
3. Choose a version rule (e.g. *Up to Next Major* from `0.1.0`).
4. Add the products you need — `Aksara` and/or `AksaraSwiftUI` — to your target.

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/iQbalADR/aksara.git", from: "0.1.0"),
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "Aksara", package: "aksara"),
            .product(name: "AksaraSwiftUI", package: "aksara"), // optional
        ]
    ),
]
```

### Local / monorepo path

If you vendor this repo alongside your app:

```swift
dependencies: [ .package(path: "../aksara") ],
```

### Build & test the package itself

```bash
swift build
swift test
```

---

## CocoaPods

The [`Aksara.podspec`](https://github.com/iQbalADR/aksara/blob/main/Aksara.podspec) is at the repository root. It exposes two
subspecs; **`Core` is the default**.

### Podfile

```ruby
# Core runtime only:
pod 'Aksara'

# Core + the SwiftUI layer:
pod 'Aksara/SwiftUI'
```

Then:

```bash
pod install
```

and open the generated `.xcworkspace`.

### Consuming from the Git repo before it's published to trunk

```ruby
pod 'Aksara', :git => 'https://github.com/iQbalADR/aksara.git', :tag => '0.1.0'
pod 'Aksara/SwiftUI', :git => 'https://github.com/iQbalADR/aksara.git', :tag => '0.1.0'
```

### Maintainer notes

- Validate the spec before releasing:
  ```bash
  pod lib lint Aksara.podspec --allow-warnings
  ```
- **Add a `LICENSE` file** — the podspec references it and `pod trunk push` requires it.
- Publish: `pod trunk push Aksara.podspec`.

---

## Carthage

Carthage **does not build Swift Package Manager packages**, so Aksara is distributed
to Carthage as **prebuilt XCFrameworks** attached to each GitHub Release. Your app
consumes those binaries.

### Cartfile

```
github "iQbalADR/aksara" ~> 0.1.0
```

Then build (XCFrameworks are required — always pass `--use-xcframeworks`):

```bash
carthage update --use-xcframeworks --platform iOS
```

Carthage downloads the `*.xcframework.zip` assets from the matching release (it does
**not** compile them). You'll get, in `Carthage/Build/`:

- `Aksara.xcframework`
- `AksaraSwiftUI.xcframework` (only if you need the SwiftUI layer)

Drag the ones you need into your target's **General ▸ Frameworks, Libraries, and
Embedded Content** and set them to **Embed & Sign**. (XCFrameworks don't need the old
`copy-frameworks` run-script phase.)

### Alternative: explicit binary spec

If you're not resolving via GitHub, point Carthage at a binary spec JSON per framework:

```
binary "https://cdn.example.com/carthage/Aksara.json"
binary "https://cdn.example.com/carthage/AksaraSwiftUI.json"
```

where `Aksara.json` maps versions to the zipped XCFramework:

```json
{
  "0.1.0": "https://github.com/iQbalADR/aksara/releases/download/0.1.0/Aksara.xcframework.zip"
}
```

### Maintainer notes — producing the release artifacts

```bash
./scripts/build-xcframework.sh
```

This archives each scheme for iOS device + simulator, repackages the Swift module
interface into each `.framework`, and emits:

```
build/xcframeworks/Aksara.xcframework           (+ Aksara.xcframework.zip)
build/xcframeworks/AksaraSwiftUI.xcframework    (+ AksaraSwiftUI.xcframework.zip)
```

Attach both `*.xcframework.zip` files to the GitHub Release for the version tag so the
`github "iQbalADR/aksara"` route above finds them. To add tvOS / watchOS / macOS slices,
uncomment entries in the `PLATFORMS` list at the top of the script.

---

## Manual XCFramework

No dependency manager? Build the binaries yourself and embed them:

```bash
./scripts/build-xcframework.sh
```

Drag `build/xcframeworks/Aksara.xcframework` (and `AksaraSwiftUI.xcframework` if
needed) into your target's **Frameworks, Libraries, and Embedded Content**, set to
**Embed & Sign**, and `import Aksara`.

---

## Verify the integration

```swift
import Aksara
import AksaraSwiftUI // if you added it

Localizer.shared.configure(.init(
    defaultLanguage: "en",
    fallbackLanguage: "en",
    bundledResource: "en"
))
print(Localizer.shared.t("common.welcome", args: ["name": "Oncom"]))
```

See the [Home page](index.md) for the full API
and the [format spec](format.md) for how to author `en.json`.
