import Foundation

struct MapPoint: Identifiable, Equatable {
    let id = UUID()
    var latitude: Double? = nil
    var longitude: Double? = nil
    var name: String? = nil
    var source: String

    var coordinateText: String? {
        guard let latitude, let longitude else { return nil }
        return String(format: "%.6f, %.6f", latitude, longitude)
    }

    var geoURL: URL? {
        guard let coordinateText else { return nil }
        return URL(string: "geo:\(coordinateText.replacingOccurrences(of: " ", with: ""))")
    }
}

struct MapResult {
    var points: [MapPoint]
    var original: String
    var service: String
    var note: String? = nil

    var selected: MapPoint? { points.last }
}

enum SharedInbox {
    static let defaults = UserDefaults(suiteName: "group.app.gwal3n.geoshare")
    static let key = "pendingInput"

    static func save(_ value: String) { defaults?.set(value, forKey: key) }
    static func take() -> String? {
        let value = defaults?.string(forKey: key)
        defaults?.removeObject(forKey: key)
        return value
    }
}
