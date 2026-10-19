import Foundation

enum MapParser {
    private static let number = #"[+-]?(?:\d+(?:\.\d*)?|\.\d+)"#
    private static let pair = "(\(number)),\\s*(\(number))"

    static func parse(_ input: String) -> MapResult? {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if let url = extractURL(value) { return parseURL(url, original: value) }
        if let point = coordinate(value, source: "Coordinates") {
            return MapResult(points: [point], original: value, service: "Coordinates")
        }
        return nil
    }

    static func extractURL(_ text: String) -> URL? {
        guard let range = text.range(of: #"(?:https?://|geo:)[^\s<>]+"#, options: .regularExpression) else { return nil }
        let raw = String(text[range]).trimmingCharacters(in: CharacterSet(charactersIn: ".,);]"))
        return URL(string: raw)
    }

    static func parseURL(_ url: URL, original: String? = nil) -> MapResult? {
        let host = (url.host ?? "").lowercased()
        let text = url.absoluteString.removingPercentEncoding ?? url.absoluteString
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func q(_ key: String) -> String? { query.first(where: { $0.name.lowercased() == key })?.value }
        func result(_ points: [MapPoint], _ service: String, _ note: String? = nil) -> MapResult? {
            guard !points.isEmpty else { return nil }
            return MapResult(points: points, original: original ?? url.absoluteString, service: service, note: note)
        }
        if url.scheme == "geo" {
            let value = String(url.absoluteString.dropFirst(4)).replacingOccurrences(of: "//", with: "")
            return result([coordinate(value, source: "Geo URI"), q("q").flatMap { coordinate($0, source: "Geo URI") }].compactMap { $0 }, "Geo URI")
        }
        if host == "maps.app.goo.gl" || host == "goo.gl" || host == "maps.apple" {
            return nil // Online redirect resolution is offered separately.
        }
        if host.contains("google.") || host == "maps.google.com" {
            let service = "Google Maps"
            var route: [MapPoint] = []
            for key in ["origin", "saddr"] {
                if let value = q(key) { route.append(coordinateOrName(value, service)) ; break }
            }
            if let waypoints = q("waypoints") {
                route += waypoints.split(separator: "|").map { coordinateOrName(String($0), service) }
            }
            for key in ["destination", "daddr"] {
                if let value = q(key) { route.append(coordinateOrName(value, service)); break }
            }
            if !route.isEmpty { return result(route, service) }
            for key in ["q", "query", "ll", "viewpoint", "center"] {
                if let value = q(key), let point = coordinate(value, source: service) { return result([point], service) }
            }
            // A place pin in the data segment is more precise than the map center.
            if let point = regexPoint(text, pattern: "!3d(\(number))!4d(\(number))", source: service) {
                return result([point], service)
            }
            if let point = regexPoint(text, pattern: "@\(pair)", source: service) {
                var named = point
                named.name = pathName(url)
                return result([named], service)
            }
            if let value = q("q") ?? q("query") { return result([coordinateOrName(value, service)], service) }
            if let name = pathName(url) { return result([MapPoint(name: name, source: service)], service, "This link contains a place name but no coordinates.") }
            return nil
        }
        if host == "maps.apple.com" || host == "maps.apple" {
            let service = "Apple Maps"
            let routeKeys = ["source", "waypoint", "destination", "saddr", "daddr"]
            let route = query.filter { routeKeys.contains($0.name) }.compactMap { $0.value }.map { coordinateOrName($0, service) }
            if !route.isEmpty { return result(route, service) }
            let name = q("name") ?? q("address") ?? q("q")
            for key in ["ll", "coordinate", "q", "sll", "near", "center"] {
                if let value = q(key), var point = coordinate(value, source: service) {
                    point.name = name.flatMap { coordinate($0, source: service) == nil ? $0 : nil }
                    return result([point], service)
                }
            }
            if let name { return result([MapPoint(name: name, source: service)], service) }
            return nil
        }
        if host == "openstreetmap.org" || host == "www.openstreetmap.org" || host == "osm.org" {
            let service = "OpenStreetMap"
            if url.pathComponents.count > 2, url.pathComponents[1] == "go", let point = GeoHash.osm(url.pathComponents[2]) { return result([point], service) }
            if let lat = q("mlat") ?? q("lat"), let lon = q("mlon") ?? q("lon"), let point = coordinate("\(lat),\(lon)", source: service) { return result([point], service) }
            if let value = q("to"), let point = coordinate(value, source: service) { return result([point], service) }
            let fragment = url.fragment ?? ""
            if let point = regexPoint(fragment, pattern: "map=\\d+(?:\\.\\d+)?/(\(number))/(\(number))", source: service) { return result([point], service) }
            return nil
        }
        if host == "waze.com" || host == "www.waze.com" {
            if let value = q("ll"), let point = coordinate(value, source: "Waze") { return result([point], "Waze") }
        }
        if host == "here.com" || host == "wego.here.com" || host == "www.here.com" {
            if let point = regexPoint(text, pattern: "map=\(pair)", source: "HERE WeGo") { return result([point], "HERE WeGo") }
        }
        if host == "omaps.app" || host == "comaps.at" || host == "ge0.me" {
            let service = host == "comaps.at" ? "CoMaps" : "Organic Maps"
            if let value = q("ll"), let point = coordinate(value, source: service) { return result([point], service) }
            if url.pathComponents.count > 1, var point = GeoHash.ge0(url.pathComponents[1], source: service) {
                if url.pathComponents.count > 2 { point.name = url.pathComponents[2].replacingOccurrences(of: "_", with: " ") }
                return result([point], service)
            }
        }
        if host == "osmand.net" || host == "www.osmand.net" {
            let service = "OsmAnd"
            let route = [q("start"), q("finish")].compactMap { $0 }.compactMap { coordinate($0, source: service) }
            if !route.isEmpty { return result(route, service) }
            if let value = q("pin"), let point = coordinate(value, source: service) { return result([point], service) }
            if let point = regexPoint(url.fragment ?? "", pattern: "^[0-9.]+/(\(number))/(\(number))", source: service) { return result([point], service) }
        }
        if host == "mapy.com" || host == "mapy.cz" || host.hasSuffix(".mapy.com") || host.hasSuffix(".mapy.cz") {
            let service = "Mapy.com"
            if let value = q("id"), let point = reversedCoordinate(value, source: service) { return result([point], service) }
            if let longitude = q("x"), let latitude = q("y"), let point = coordinate("\(latitude),\(longitude)", source: service) { return result([point], service) }
        }
        if host == "magicearth.com" {
            let service = "Magic Earth"
            if let latitude = q("lat"), let longitude = q("lon"), var point = coordinate("\(latitude),\(longitude)", source: service) {
                point.name = q("name") ?? q("daddr") ?? q("q")
                return result([point], service)
            }
            if let name = q("name") ?? q("daddr") ?? q("q") { return result([MapPoint(name: name, source: service)], service) }
        }
        if host == "cartes-ign.ign.fr" {
            if let latitude = q("lat"), let longitude = q("lng"), let point = coordinate("\(latitude),\(longitude)", source: "Cartes IGN") { return result([point], "Cartes IGN") }
        }
        if host == "kagi.com" || host == "www.kagi.com", url.path.hasPrefix("/maps") {
            let service = "Kagi Maps"
            if url.path.contains("/directions"), let value = q("q") {
                let route = value.split(separator: "|", omittingEmptySubsequences: true).map { item -> MapPoint in
                    let parts = item.split(separator: "~", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
                    let value = parts.last ?? ""
                    var point = coordinate(value, source: service) ?? MapPoint(name: parts.first, source: service)
                    if parts.count > 1, !parts[0].isEmpty { point.name = parts[0] }
                    return point
                }
                if !route.isEmpty { return result(route, service) }
            }
            if let id = q("id"), id.hasPrefix("point_") {
                let parts = id.dropFirst(6).split(separator: "_")
                if parts.count == 2, var point = coordinate("\(parts[0]),\(parts[1])", source: service) {
                    point.name = q("q")
                    return result([point], service)
                }
            }
            if let value = q("ll"), var point = coordinate(value, source: service) { point.name = q("q"); return result([point], service) }
            if let point = regexPoint(url.fragment ?? "", pattern: "^[0-9.]+/(\(number))/(\(number))", source: service) { return result([point], service) }
            if let name = q("q") { return result([MapPoint(name: name, source: service)], service) }
        }
        if host == "map.yahoo.co.jp" || host == "map.yahoo.com" {
            let service = "Yahoo! Maps"
            if q("gid") == nil, let latitude = q("lat"), let longitude = q("lon"), var point = coordinate("\(latitude),\(longitude)", source: service) {
                point.name = q("q")
                return result([point], service)
            }
        }
        if host.hasPrefix("2gis.") || host.hasPrefix("go.2gis.") || host.hasPrefix("maps.urbi.") || host.hasPrefix("go.urbi.") {
            let service = "2GIS / Urbi"
            if let value = q("m")?.components(separatedBy: "/").first,
               let point = reversedCoordinate(value, source: service) { return result([point], service) }
            if let component = url.pathComponents.map({ $0.removingPercentEncoding ?? $0 }).first(where: { $0.contains(",") }),
               let point = reversedCoordinate(component, source: service) { return result([point], service) }
            if let value = q("center"), var point = reversedCoordinate(value, source: service) {
                point.name = q("title")
                return result([point], service)
            }
        }
        // Unknown providers sometimes expose an unambiguous coordinate pair.
        for key in ["ll", "q", "query", "center", "coordinates"] {
            if let value = q(key), let point = coordinate(value, source: host) { return result([point], host) }
        }
        return nil
    }

    private static func coordinateOrName(_ value: String, _ source: String) -> MapPoint {
        coordinate(value, source: source) ?? MapPoint(name: value, source: source)
    }

    private static func reversedCoordinate(_ value: String, source: String) -> MapPoint? {
        let parts = value.split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let longitude = Double(parts[0].trimmingCharacters(in: .whitespaces)),
              let latitude = Double(parts[1].trimmingCharacters(in: .whitespaces)),
              (-90...90).contains(latitude), (-180...180).contains(longitude) else { return nil }
        return MapPoint(latitude: latitude, longitude: longitude, source: source)
    }

    private static func coordinate(_ value: String, source: String) -> MapPoint? {
        guard let regex = try? NSRegularExpression(pattern: "^\\s*\(pair)\\s*$"),
              let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
              let latRange = Range(match.range(at: 1), in: value),
              let lonRange = Range(match.range(at: 2), in: value),
              let lat = Double(value[latRange]), let lon = Double(value[lonRange]),
              (-90...90).contains(lat), (-180...180).contains(lon) else { return nil }
        return MapPoint(latitude: lat, longitude: lon, source: source)
    }

    private static func regexPoint(_ text: String, pattern: String, source: String) -> MapPoint? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let a = Range(match.range(at: 1), in: text), let b = Range(match.range(at: 2), in: text) else { return nil }
        return coordinate("\(text[a]),\(text[b])", source: source)
    }

    private static func pathName(_ url: URL) -> String? {
        let parts = url.pathComponents
        guard let index = parts.firstIndex(of: "place") ?? parts.firstIndex(of: "search"), index + 1 < parts.count else { return nil }
        return parts[index + 1].replacingOccurrences(of: "+", with: " ").removingPercentEncoding
    }
}
