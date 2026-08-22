// swift-tools-version: 5.9
import PackageDescription
import Foundation

// The manifest lives at the repository root (required for remote SwiftPM
// consumption) while the Swift sources stay under `swift/` per the cross-platform
// layout. Sibling `kotlin/` holds the Android mirror.
//
// Package/product names are `Aksara` / `AksaraSwiftUI`. Confirm the name is free on
// your GitHub org and Swift Package Index before the first public release.

// SwiftPM consumers get static libraries by default. The XCFramework build script
// (scripts/build-xcframework.sh) exports AKSARA_DYNAMIC=1 so `xcodebuild archive`
// emits `.framework` bundles — needed for Carthage and manual XCFramework use.
let libraryType: Product.Library.LibraryType? =
    ProcessInfo.processInfo.environment["AKSARA_DYNAMIC"] == "1" ? .dynamic : nil

let package = Package(
    name: "Aksara",
    platforms: [
        // Floor set by URLSession.data(for:) async and SecTrustCopyCertificateChain.
        // The SwiftUI layer uses ObservableObject/@Published (not @Observable) so it
        // works on this floor too.
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8),
    ],
    products: [
        // Core runtime: loader, plurals, interpolation, OTA. No UI dependency.
        .library(name: "Aksara", type: libraryType, targets: ["Aksara"]),
        // SwiftUI live-binding layer (LocalizationManager + LocText).
        .library(name: "AksaraSwiftUI", type: libraryType, targets: ["AksaraSwiftUI"]),
    ],
    targets: [
        .target(
            name: "Aksara",
            path: "swift/Sources/Aksara"
        ),
        .target(
            name: "AksaraSwiftUI",
            dependencies: ["Aksara"],
            path: "swift/Sources/AksaraSwiftUI"
        ),
        .testTarget(
            name: "AksaraTests",
            dependencies: ["Aksara"],
            path: "swift/Tests/AksaraTests",
            resources: [.process("Resources")]
        ),
    ]
)
