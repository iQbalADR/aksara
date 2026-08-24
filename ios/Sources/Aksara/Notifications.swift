import Foundation

public extension Notification.Name {
    /// Posted (always on the main queue) whenever the active translation table
    /// changes — a language switch, an OTA swap, or a disk-cache load.
    ///
    /// UI layers observe this to re-apply localized text live; the SwiftUI layer
    /// (`LocalizationManager`) does this for you.
    static let aksaraDidChange = Notification.Name("com.aksara.didChange")
}
