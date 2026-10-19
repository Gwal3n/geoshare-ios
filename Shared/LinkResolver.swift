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
    private static let desktopUserAgent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/153.0.0.0 Safari/537.36"
    private static let googleCookies = "CONSENT=PENDING+987; SOCS=CAESHAgBEhJnd3NfMjAyMzA4MTAtMF9SQzIaAmRlIAEaBgiAo_CmBg"

    static func resolve(_ input: String, allowNetwork: Bool) async throws -> MapResult {
        if let offline = MapParser.parse(input), offline.selected?.latitude != nil { return offline }
        guard allowNetwork else { throw ResolveError.unsupported }
        guard let url = MapParser.extractURL(input), url.scheme == "https", let host = url.host?.lowercased(), isAllowed(host) else { throw ResolveError.unsafeURL }
        let request = mapRequest(url)
        let (data, response) = try await URLSession.shared.data(for: request)
        var finalURL = response.url
        var html = String(decoding: data.prefix(2_000_000), as: UTF8.self)
        // Cookies on a short-link request do not necessarily carry over to Google
        // after URLSession follows the cross-domain redirect on iOS.
        if let redirectedURL = finalURL, isGoogle(redirectedURL), !isGoogle(url) {
            let mapURL = consentContinueURL(redirectedURL) ?? redirectedURL
            if let fresh = try? await URLSession.shared.data(for: mapRequest(mapURL)) {
                finalURL = fresh.1.url
                html = String(decoding: fresh.0.prefix(2_000_000), as: UTF8.self)
            }
        }
        #if os(iOS)
        if let finalURL, isGoogle(finalURL), finalURL.path.hasPrefix("/maps/placelists/list/") {
            if let list = await GoogleWebViewResolver.resolve(finalURL, original: input) { return list }
            throw ResolveError.noLocation
        }
        #endif
        if let finalURL, let parsed = MapParser.parseURL(finalURL, original: input), parsed.selected?.latitude != nil { return parsed }
        if let finalURL, isGoogle(finalURL), let previewURL = googlePlacePreviewURL(html, base: finalURL) {
            do {
                let (previewData, _) = try await URLSession.shared.data(for: mapRequest(previewURL))
                if let point = googlePlacePreviewPoint(previewData, name: googlePlaceName(finalURL)) {
                    return MapResult(points: [point], original: input, service: "Google Maps")
                }
            } catch {
                // Continue with page parsing and the browser fallback.
            }
        }
        if let lat = meta(html, key: "place:location:latitude"), let lon = meta(html, key: "place:location:longitude"), let result = MapParser.parse("\(lat),\(lon)") {
            return MapResult(points: result.points, original: input, service: host)
        }
        #if os(iOS)
        if let finalURL, isGoogle(finalURL),
           let result = await GoogleWebViewResolver.resolve(finalURL, original: input) {
            return result
        }
        #endif
        // Google may return a generic map centered on the requester's IP address.
        // Never treat that center as the shared place's coordinates.
        if !html.contains("<meta content=\"Google Maps\" itemprop=\"name\">") {
            let unescaped = html.replacingOccurrences(of: "\\u003d", with: "=")
                .replacingOccurrences(of: "\\u0026", with: "&")
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "\\/", with: "/")
            if let result = MapParser.parse(unescaped), result.selected?.latitude != nil { return result }
        }
        if let result = MapParser.parse(input) { return result }
        throw ResolveError.noLocation
    }

    private static func mapRequest(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue(desktopUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        if isGoogle(url) { request.setValue(googleCookies, forHTTPHeaderField: "Cookie") }
        return request
    }

    private static func isGoogle(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "google.com" || host.hasSuffix(".google.com")
    }

    private static func consentContinueURL(_ url: URL) -> URL? {
        guard url.host?.hasPrefix("consent.google.") == true,
              let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "continue" })?.value,
              let next = URL(string: value), next.scheme == "https", isGoogle(next) else { return nil }
        return next
    }

    private static func googlePlaceName(_ url: URL) -> String? {
        guard let name = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
            .first(where: { $0.name == "q" })?.value else { return nil }
        return name.replacingOccurrences(of: "+", with: " ")
    }

    private static func googlePlacePreviewURL(_ html: String, base: URL) -> URL? {
        let pattern = #"<link\s+href="([^"]*?/maps/preview/place\?[^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else { return nil }
        let value = String(html[range]).replacingOccurrences(of: "&amp;", with: "&")
        guard let url = URL(string: value, relativeTo: base)?.absoluteURL, isGoogle(url), url.path == "/maps/preview/place" else { return nil }
        return url
    }

    static func googlePlacePreviewPoint(_ data: Data, name: String?) -> MapPoint? {
        let prefix = String(decoding: data.prefix(1_000), as: UTF8.self)
        let number = #"-?\d+(?:\.\d+)?"#
        let pattern = "\\[\\[\(number),(\(number)),(\(number))\\]"
        guard prefix.hasPrefix(")]}'"), let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: prefix, range: NSRange(prefix.startIndex..., in: prefix)),
              let lonRange = Range(match.range(at: 1), in: prefix), let latRange = Range(match.range(at: 2), in: prefix),
              let lon = Double(prefix[lonRange]), let lat = Double(prefix[latRange]),
              (-90...90).contains(lat), (-180...180).contains(lon) else { return nil }
        return MapPoint(latitude: lat, longitude: lon, name: name, source: "Google Maps")
    }

    private static func isAllowed(_ host: String) -> Bool {
        let domains = ["google.com", "goo.gl", "apple.com", "maps.apple", "openstreetmap.org", "osm.org", "omaps.app", "comaps.at", "ge0.me", "waze.com", "here.com", "osmand.net", "mapy.com", "mapy.cz", "magicearth.com", "cartes-ign.ign.fr", "kagi.com", "yahoo.co.jp", "yahoo.com", "2gis.ae", "2gis.am", "2gis.az", "2gis.com", "2gis.cz", "2gis.kg", "2gis.kz", "2gis.ru", "2gis.uz", "urbi.ae"]
        return domains.contains { host == $0 || host.hasSuffix(".\($0)") }
    }

    private static func meta(_ html: String, key: String) -> String? {
        let pattern = #"<meta[^>]+(?:property|name)=["']"# + NSRegularExpression.escapedPattern(for: key) + #"["'][^>]+content=["']([^"']+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive), let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)), let range = Range(match.range(at: 1), in: html) else { return nil }
        return String(html[range])
    }
}
