import XCTest
@testable import GeoShare

final class GoogleLinkTests: XCTestCase {
    func testTulsaShortLinkOnIOS() async throws {
        let result = try await LinkResolver.resolve("https://maps.app.goo.gl/botxZvRPfLrSpN8b6", allowNetwork: true)
        let point = try XCTUnwrap(result.selected)
        XCTAssertEqual(try XCTUnwrap(point.latitude), 36.1568986, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(point.longitude), -95.9915366, accuracy: 0.001)
        XCTAssertTrue((point.name ?? "").contains("Center of the Universe"))
    }

    func testGooglePlaceListOnIOS() async throws {
        let result = try await LinkResolver.resolve("https://www.google.com/maps/placelists/list/mfmnkPs6RuGyp0HOmXLSKg", allowNetwork: true)
        XCTAssertEqual(result.points.count, 8)
        XCTAssertEqual(try XCTUnwrap(result.points.first?.latitude), 59.1293656, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(result.points.first?.longitude), 11.4585672, accuracy: 0.001)
    }

    func testPlaceListJSONRejectsOutOfRangeCoordinates() {
        let points = GooglePlaceListParser.points(#"[{"lat":59.12,"lon":11.45},{"lat":999,"lon":11}]"#)
        XCTAssertEqual(points?.count, 1)
        XCTAssertEqual(points?.first?.name, "Place 1")
    }
}
