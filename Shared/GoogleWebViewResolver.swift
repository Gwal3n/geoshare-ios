#if os(iOS)
import Foundation
import WebKit

@MainActor
enum GoogleWebViewResolver {
    private static let desktopUserAgent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/153.0.0.0 Safari/537.36"

    static func resolve(_ url: URL, original: String) async -> MapResult? {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 2, height: 2), configuration: configuration)
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
        webView.stopLoading()
        return nil
    }
}
#endif
