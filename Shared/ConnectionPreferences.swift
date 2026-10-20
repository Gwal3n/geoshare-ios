import Foundation

enum ConnectionPreferences {
    static let store = SharedInbox.defaults ?? .standard
    static let automaticKey = "automaticallyResolveOnline"
    static let defaultMapKey = "defaultShareMap"
    static var automaticallyResolveOnline: Bool {
        store.bool(forKey: automaticKey)
    }
}
