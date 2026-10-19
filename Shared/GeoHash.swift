import Foundation

enum GeoHash {
    private static let ge0Alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
    private static let osmAlphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_~")

    static func ge0(_ value: String, source: String) -> MapPoint? {
        guard value.count >= 3 else { return nil }
        let hash = String(value.dropFirst())
        return decode(hash, alphabet: ge0Alphabet, longitudeFirst: false, midpoint: true, latitudeAdjustment: true, source: source)
    }

    static func osm(_ value: String) -> MapPoint? {
        let hash = String(value.prefix { $0 != "-" })
        guard hash.count >= 2 else { return nil }
        return decode(hash, alphabet: osmAlphabet, longitudeFirst: true, midpoint: false, latitudeAdjustment: false, source: "OpenStreetMap")
    }

    private static func decode(_ hash: String, alphabet: [Character], longitudeFirst: Bool, midpoint: Bool, latitudeAdjustment: Bool, source: String) -> MapPoint? {
        var x: UInt64 = 0
        var y: UInt64 = 0
        var xBits = 0
        var yBits = 0
        var bitIndex = 0
        for character in hash {
            guard let value = alphabet.firstIndex(of: character) else { return nil }
            for bit in (0..<6).reversed() {
                let digit = UInt64((value >> bit) & 1)
                let goesToLongitude = (bitIndex % 2 == 0) == longitudeFirst
                if goesToLongitude { x = (x << 1) | digit; xBits += 1 }
                else { y = (y << 1) | digit; yBits += 1 }
                bitIndex += 1
            }
        }
        guard xBits < 62, yBits < 62, xBits > 0, yBits > 0 else { return nil }
        let adjustment = midpoint ? 0.5 : 0.0
        let xCells = pow(2.0, Double(xBits))
        let yCells = pow(2.0, Double(yBits)) - (latitudeAdjustment ? pow(2.0, Double(yBits) - 30.0) : 0.0)
        let longitude = (Double(x) + adjustment) / xCells * 360.0 - 180.0
        let latitude = (Double(y) + adjustment) / yCells * 180.0 - 90.0
        guard (-90...90).contains(latitude), (-180...180).contains(longitude) else { return nil }
        return MapPoint(latitude: latitude, longitude: longitude, source: source)
    }
}
