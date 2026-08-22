import SwiftUI
import Aksara

/// A `Text` that localizes `key` and updates live when the language changes or an
/// OTA update lands.
///
/// ```swift
/// LocText("common.welcome", args: ["name": "Oncom"])
/// LocText("common.items", count: cartCount)
/// ```
///
/// Observes `LocalizationManager.shared` (an `ObservableObject`), so it re-renders on
/// every table swap. Works on iOS 15+.
public struct LocText: View {
    @StateObject private var manager = LocalizationManager.shared

    private let key: String
    private let args: [String: Any]
    private let count: Int?

    public init(_ key: String, args: [String: Any] = [:]) {
        self.key = key
        self.args = args
        self.count = nil
    }

    public init(_ key: String, count: Int, args: [String: Any] = [:]) {
        self.key = key
        self.args = args
        self.count = count
    }

    public var body: some View {
        Text(resolved)
    }

    private var resolved: String {
        if let count {
            return manager.t(key, count: count, args: args)
        }
        return manager.t(key, args: args)
    }
}
