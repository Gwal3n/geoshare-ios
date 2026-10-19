#if os(iOS)
import Foundation
import WebKit

@MainActor
enum GoogleWebViewResolver {
    private static let desktopUserAgent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/153.0.0.0 Safari/537.36"

    static func resolve(_ url: URL, original: String) async -> MapResult? {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1024, height: 768), configuration: configuration)
        webView.customUserAgent = desktopUserAgent
        var request = URLRequest(url: url)
        request.timeoutInterval = 25
        request.setValue("CONSENT=PENDING+987; SOCS=CAESHAgBEhJnd3NfMjAyMzA4MTAtMF9SQzIaAmRlIAEaBgiAo_CmBg", forHTTPHeaderField: "Cookie")
        webView.load(request)

        var candidateURL: URL?
        var candidateSince = Date()
        for _ in 0..<40 {
            if Task.isCancelled { break }
            try? await Task.sleep(nanoseconds: 750_000_000)
            if url.path.hasPrefix("/maps/placelists/list/"),
               let json = (try? await webView.evaluateJavaScript(placeListJavaScript)) as? String,
               let points = GooglePlaceListParser.points(json), !points.isEmpty {
                webView.stopLoading()
                return MapResult(points: points, original: original, service: "Google Maps")
            }
            let href = (try? await webView.evaluateJavaScript("location.href")) as? String
            guard let current = href.flatMap(URL.init(string:)) ?? webView.url,
                  let host = current.host?.lowercased(),
                  host == "google.com" || host.hasSuffix(".google.com"),
                  let result = MapParser.parseURL(current, original: original),
                  result.selected?.coordinateText != nil,
                  current.path.contains("/maps/place/") || current.absoluteString.contains("!3d") || current.absoluteString.contains("!4d") else { continue }
            if current != candidateURL {
                candidateURL = current
                candidateSince = Date()
            } else if Date().timeIntervalSince(candidateSince) >= 3 {
                webView.stopLoading()
                return result
            }
        }
        if url.path.hasPrefix("/maps/placelists/list/") {
            let title = (try? await webView.evaluateJavaScript("document.title")) as? String ?? "unknown"
            let stateType = (try? await webView.evaluateJavaScript("typeof window.APP_INITIALIZATION_STATE")) as? String ?? "unknown"
            print("Google place list unresolved; URL=\(webView.url?.absoluteString ?? "unknown") title=\(title) state=\(stateType)")
        }
        webView.stopLoading()
        return nil
    }

    // Ported from GeoShare Android's GoogleMapsPlaceListInputImpl: inspect only the
    // serialized list data in APP_INITIALIZATION_STATE, not the map viewport center.
    private static let placeListJavaScript = #"""
    (() => {
        const state = window.APP_INITIALIZATION_STATE;
        if (!Array.isArray(state)) return null;
        const pattern = /\[(?:null,null,|null,\[)([+ ]?-?\d{1,2}(?:\.\d{1,17})?),([+ ]?-?\d{1,3}(?:\.\d{1,17})?)\]/g;
        for (const item of state) {
            if (item === null || typeof item !== 'object' || Array.isArray(item)) continue;
            for (const value of Object.values(item)) {
                if (!Array.isArray(value)) continue;
                for (const text of value) {
                    if (typeof text !== 'string') continue;
                    const matches = [...text.matchAll(pattern)].map(m => ({lat: Number(m[1]), lon: Number(m[2])}));
                    if (matches.length) return JSON.stringify(matches);
                }
            }
        }
        return null;
    })()
    """#
}
#endif
