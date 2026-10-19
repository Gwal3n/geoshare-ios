import Foundation

enum GooglePlaceListParser {
    static func apiURL(for listURL: URL) -> URL? {
        guard listURL.path.hasPrefix("/maps/placelists/list/"),
              let id = listURL.pathComponents.last,
              id.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil,
              var components = URLComponents(string: "https://www.google.com/maps/preview/entitylist/getlist") else { return nil }
        components.queryItems = [
            URLQueryItem(name: "authuser", value: "0"),
            URLQueryItem(name: "hl", value: "en"),
            URLQueryItem(name: "gl", value: "us"),
            URLQueryItem(name: "pb", value: "!1m1!1s\(id)!2e2!3e2!4i500")
        ]
        return components.url
    }

    static func endpointURL(html: String, base: URL) -> URL? {
        let pattern = #"<link\s+href="([^"]*?/maps/preview/entitylist/getlist\?[^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else { return nil }
        let value = String(html[range]).replacingOccurrences(of: "&amp;", with: "&")
        guard let url = URL(string: value, relativeTo: base)?.absoluteURL,
              let host = url.host?.lowercased(),
              host == "google.com" || host.hasSuffix(".google.com"),
              url.path == "/maps/preview/entitylist/getlist" else { return nil }
        return url
    }

    static func points(data: Data) -> [MapPoint]? {
        let body = String(decoding: data, as: UTF8.self)
        guard body.hasPrefix(")]}'"), let newline = body.firstIndex(of: "\n"),
              let json = String(body[body.index(after: newline)...]).data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: json) else { return nil }
        var points: [MapPoint] = []
        func walk(_ value: Any) {
            guard let array = value as? [Any] else { return }
            if array.count > 2,
               let detail = array[1] as? [Any], detail.count > 5,
               let coordinate = detail[5] as? [Any], coordinate.count > 3,
               let latitude = coordinate[2] as? NSNumber,
               let longitude = coordinate[3] as? NSNumber,
               (-90...90).contains(latitude.doubleValue), (-180...180).contains(longitude.doubleValue) {
                let name = array[2] as? String
                points.append(MapPoint(latitude: latitude.doubleValue, longitude: longitude.doubleValue, name: name, source: "Google Maps"))
            }
            for child in array { walk(child) }
        }
        walk(root)
        return points.isEmpty ? nil : points
    }

    static func points(_ json: String) -> [MapPoint]? {
        guard let data = json.data(using: .utf8),
              let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Double]] else { return nil }
        let points = items.enumerated().compactMap { index, item -> MapPoint? in
            guard let latitude = item["lat"], let longitude = item["lon"],
                  (-90...90).contains(latitude), (-180...180).contains(longitude) else { return nil }
            return MapPoint(latitude: latitude, longitude: longitude, name: "Place \(index + 1)", source: "Google Maps")
        }
        return points.isEmpty ? nil : points
    }
}
