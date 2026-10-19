import Foundation

enum ResolveError: LocalizedError {
    case unsupported, unsafeURL, noLocation
    var errorDescription: String? {
        switch self {
        case .unsupported: return "No map location was found in this link."
        case .unsafeURL: return "Only public HTTPS map links can be resolved online."
        case .noLocation: return "The map page did not reveal coordinates."
        }
    }
}

enum LinkResolver {
    static func resolve(_ input: String, allowNetwork: Bool) async throws -> MapResult {
        if let offline = MapParser.parse(input), offline.selected?.latitude != nil { return offline }
        guard allowNetwork else { throw ResolveError.unsupported }
        guard let url = MapParser.extractURL(input), url.scheme == "https", let host = url.host?.lowercased(), isAllowed(host) else { throw ResolveError.unsafeURL }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("GeoShare-iOS/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let finalURL = response.url, let parsed = MapParser.parseURL(finalURL, original: input), parsed.selected?.latitude != nil { return parsed }
        let html = String(decoding: data.prefix(1_000_000), as: UTF8.self)
        if let lat = meta(html, key: "place:location:latitude"), let lon = meta(html, key: "place:location:longitude"), let result = MapParser.parse("\(lat),\(lon)") {
            return MapResult(points: result.points, original: input, service: host)
        }
        let unescaped = html.replacingOccurrences(of: "\\u003d", with: "=")
            .replacingOccurrences(of: "\\u0026", with: "&")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "\\/", with: "/")
        if let result = MapParser.parse(unescaped), result.selected?.latitude != nil { return result }
        if let result = MapParser.parse(input) { return result }
        throw ResolveError.noLocation
    }

    private static func isAllowed(_ host: String) -> Bool {
        let domains = ["google.com", "goo.gl", "apple.com", "maps.apple", "openstreetmap.org", "osm.org", "omaps.app", "comaps.at", "ge0.me", "waze.com", "here.com"]
        return domains.contains { host == $0 || host.hasSuffix(".\($0)") }
    }

    private static func meta(_ html: String, key: String) -> String? {
        let pattern = #"<meta[^>]+(?:property|name)=["']"# + NSRegularExpression.escapedPattern(for: key) + #"["'][^>]+content=["']([^"']+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive), let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)), let range = Range(match.range(at: 1), in: html) else { return nil }
        return String(html[range])
    }
}
