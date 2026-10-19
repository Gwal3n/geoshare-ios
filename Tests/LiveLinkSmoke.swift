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
        guard point.name?.contains("Center of the Universe") == true else {
            fatalError("Google place name was lost: \(String(describing: point.name))")
        }
        print("Google Maps short link resolved to \(point.coordinateText ?? "missing coordinates")")
        fflush(stdout)

        let list = try await LinkResolver.resolve("https://www.google.com/maps/placelists/list/mfmnkPs6RuGyp0HOmXLSKg", allowNetwork: true)
        guard list.points.count == 8,
              let first = list.points.first,
              abs((first.latitude ?? 0) - 59.1293656) < 0.001,
              abs((first.longitude ?? 0) - 11.4585672) < 0.001,
              first.name == "The Ford" else {
            fatalError("Failed to resolve Google place list: \(list.points)")
        }
        print("Google place list resolved to \(list.points.count) named places")
    }
}
