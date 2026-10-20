import Foundation

enum MapTarget: String, CaseIterable, Identifiable {
    case apple = "Apple Maps", organic = "Organic Maps", comaps = "CoMaps", google = "Google Maps", waze = "Waze", openStreetMap = "OpenStreetMap"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .apple: return "map.fill"
        case .organic, .comaps: return "leaf.fill"
        case .google: return "mappin.and.ellipse"
        case .waze: return "car.fill"
        case .openStreetMap: return "globe.europe.africa.fill"
        }
    }
    func url(for point: MapPoint) -> URL? {
        guard let latitude = point.latitude, let longitude = point.longitude, let coordinates = point.coordinateText?.replacingOccurrences(of: " ", with: "") else { return nil }
        if self == .openStreetMap { return URL(string: "https://www.openstreetmap.org/?mlat=\(latitude)&mlon=\(longitude)#map=16/\(latitude)/\(longitude)") }
        let base: String
        switch self {
        case .apple: base = "https://maps.apple.com/"
        case .organic: base = "om://map"
        case .comaps: base = "cm://map"
        case .google: base = "comgooglemaps://"
        case .waze: base = "waze://"
        case .openStreetMap: return nil
        }
        guard var components = URLComponents(string: base) else { return nil }
        switch self {
        case .apple: components.queryItems = [URLQueryItem(name: "ll", value: coordinates), URLQueryItem(name: "q", value: point.name ?? coordinates)]
        case .organic, .comaps: components.queryItems = [URLQueryItem(name: "v", value: "1"), URLQueryItem(name: "ll", value: coordinates), URLQueryItem(name: "n", value: point.name ?? "Shared location")]
        case .google: components.queryItems = [URLQueryItem(name: "q", value: coordinates)]
        case .waze: components.queryItems = [URLQueryItem(name: "ll", value: coordinates)]
        case .openStreetMap: break
        }
        return components.url
    }

    func webURL(for point: MapPoint) -> URL? {
        guard let coordinates = point.coordinateText?.replacingOccurrences(of: " ", with: "") else { return nil }
        if self == .apple { return url(for: point) }
        let base: String
        switch self {
        case .apple: return nil
        case .organic: base = "https://omaps.app/map"
        case .comaps: base = "https://comaps.at/map"
        case .google: base = "https://www.google.com/maps/search/"
        case .waze: base = "https://www.waze.com/ul"
        case .openStreetMap: return url(for: point)
        }
        guard var components = URLComponents(string: base) else { return nil }
        switch self {
        case .organic, .comaps:
            components.queryItems = [URLQueryItem(name: "v", value: "1"), URLQueryItem(name: "ll", value: coordinates), URLQueryItem(name: "n", value: point.name ?? "Shared location")]
        case .waze:
            components.queryItems = [URLQueryItem(name: "ll", value: coordinates)]
        case .google:
            components.queryItems = [URLQueryItem(name: "api", value: "1"), URLQueryItem(name: "query", value: coordinates)]
        case .apple, .openStreetMap: break
        }
        return components.url
    }
}

enum LocationExport {
    static func gpx(_ points: [MapPoint]) -> String {
        let items = points.compactMap { point -> String? in
            guard let lat = point.latitude, let lon = point.longitude else { return nil }
            return "<wpt lat=\"\(lat)\" lon=\"\(lon)\"><name>\(xml(point.name ?? "Shared location"))</name></wpt>"
        }.joined()
        return "<?xml version=\"1.0\" encoding=\"UTF-8\"?><gpx version=\"1.1\" creator=\"GeoShare iOS\" xmlns=\"http://www.topografix.com/GPX/1/1\">\(items)</gpx>"
    }
    private static func xml(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }
}
