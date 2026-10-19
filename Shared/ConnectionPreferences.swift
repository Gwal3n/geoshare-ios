import Foundation

enum ConnectionPreferences {
    static let store = SharedInbox.defaults ?? .standard
    static let automaticKey = "automaticallyResolveOnline"
    static var automaticallyResolveOnline: Bool {
        store.bool(forKey: automaticKey)
    }
}
