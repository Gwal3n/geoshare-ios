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
        check("https://osmand.net/map?pin=52.51628,13.37771", 52.51628, 13.37771)
        check("https://mapy.com/en/zakladni?x=14.0184810&y=50.0525078&z=9", 50.0525078, 14.0184810)
        check("https://magicearth.com/?show_on_map&lat=48.85649&lon=2.35216", 48.85649, 2.35216)
        check("https://cartes-ign.ign.fr?lng=-120.123456&lat=50.123456&z=3.14", 50.123456, -120.123456)
        check("https://kagi.com/maps/#16.13/50.735739/15.7395", 50.735739, 15.7395)
        check("https://map.yahoo.co.jp/place?lat=35.04038&lon=135.72895", 35.04038, 135.72895)
        check("https://2gis.ae/dubai/geo/55.171971%2C25.289452", 25.289452, 55.171971)
        check("https://mapy.com/en/zakladni?id=121.4684%2C31.2228", 31.2228, 121.4684)
        print("Parser smoke tests passed")
    }

    static func check(_ input: String, _ latitude: Double, _ longitude: Double) {
        guard let point = MapParser.parse(input)?.selected, let actualLat = point.latitude, let actualLon = point.longitude,
              abs(actualLat - latitude) < 0.0001, abs(actualLon - longitude) < 0.0001 else {
            fatalError("Incorrect location for \(input): \(String(describing: MapParser.parse(input)?.selected))")
        }
    }
}
