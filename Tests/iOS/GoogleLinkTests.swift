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
}
