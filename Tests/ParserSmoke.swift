import Foundation

@main
struct ParserSmoke {
    static func main() {
        check("https://www.google.com/maps/place/42.578496,1.895566/data=!4m6!3m5!1s0!7e2!8m2!3d42.5784957!4d1.8955661", 42.5784957, 1.8955661)
        check("https://maps.apple.com/?ll=40.7829,-73.9654&q=Central+Park", 40.7829, -73.9654)
        check("https://www.openstreetmap.org/#map=14/52.52/13.405", 52.52, 13.405)
        check("https://omaps.app/Umse5f0H8a/Nova_Iorque", 40.7127405, -74.005997)
        check("https://comaps.at/o4MnIOApKp/Kreuzberg", 52.4877386, 13.3815233)
        check("https://osm.org/go/0EEQjE--", 51.510772705078125, 0.054931640625)
        print("Parser smoke tests passed")
    }

    static func check(_ input: String, _ latitude: Double, _ longitude: Double) {
        guard let point = MapParser.parse(input)?.selected, let actualLat = point.latitude, let actualLon = point.longitude,
              abs(actualLat - latitude) < 0.0001, abs(actualLon - longitude) < 0.0001 else {
            fatalError("Incorrect location for \(input): \(String(describing: MapParser.parse(input)?.selected))")
        }
    }
}
