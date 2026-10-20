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

    func testSharedONEOKFieldLinkOnIOS() async throws {
        let start = Date()
        let result = try await LinkResolver.resolve("https://maps.app.goo.gl/g3go7HTmFPYWMtaeA?g_st=ic", allowNetwork: true)
        let point = try XCTUnwrap(result.selected)
        XCTAssertEqual(try XCTUnwrap(point.latitude), 36.1605489, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(point.longitude), -95.9882522, accuracy: 0.001)
        XCTAssertTrue((point.name ?? "").contains("ONEOK Field"))
        print("ONEOK Field link resolved in \(Date().timeIntervalSince(start)) seconds")
        XCTAssertLessThan(Date().timeIntervalSince(start), 10)
    }

    func testPreviewFindsRequestedPlaceAfterNearbySuggestions() throws {
        let ftid = "0x87b6ebaad12cff0d:0x19170843ea61b3c0"
        let preview = ")]}'\n[null,[null,null,36.158393,-95.989368],\"other-place\",[null,null,36.1605489,-95.9882522],\"\(ftid)\",\"ONEOK Field\"]"
        let point = try XCTUnwrap(LinkResolver.googlePlacePreviewPoint(Data(preview.utf8), name: "ONEOK Field", ftid: ftid))
        XCTAssertEqual(try XCTUnwrap(point.latitude), 36.1605489, accuracy: 0.000001)
        XCTAssertEqual(try XCTUnwrap(point.longitude), -95.9882522, accuracy: 0.000001)
    }

    func testGooglePlaceListOnIOS() async throws {
        let result = try await LinkResolver.resolve("https://www.google.com/maps/placelists/list/mfmnkPs6RuGyp0HOmXLSKg", allowNetwork: true)
        XCTAssertEqual(result.points.count, 8)
        XCTAssertEqual(try XCTUnwrap(result.points.first?.latitude), 59.1293656, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(result.points.first?.longitude), 11.4585672, accuracy: 0.001)
        XCTAssertEqual(result.points.first?.name, "The Ford")
    }

    func testPlaceListJSONRejectsOutOfRangeCoordinates() {
        let points = GooglePlaceListParser.points(#"[{"lat":59.12,"lon":11.45},{"lat":999,"lon":11}]"#)
        XCTAssertEqual(points?.count, 1)
        XCTAssertEqual(points?.first?.name, "Place 1")
    }
}
