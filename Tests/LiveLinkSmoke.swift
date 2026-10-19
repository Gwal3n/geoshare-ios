import Foundation

@main
struct LiveLinkSmoke {
    static func main() async throws {
        let input = "https://maps.app.goo.gl/botxZvRPfLrSpN8b6"
        let result = try await LinkResolver.resolve(input, allowNetwork: true)
        guard let point = result.selected, let latitude = point.latitude, let longitude = point.longitude,
              abs(latitude - 36.1568986) < 0.001, abs(longitude - -95.9915366) < 0.001 else {
            fatalError("Failed to resolve the shared Tulsa place: \(String(describing: result.selected))")
        }
        print("Google Maps short link resolved to \(point.coordinateText ?? "missing coordinates")")
    }
}
