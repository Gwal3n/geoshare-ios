import XCTest
@testable import GeoShare

final class MapShareLinkTests: XCTestCase {
    func testEveryMapSharesAResolvableHTTPSLocation() throws {
        let point = MapPoint(latitude: 36.1605489, longitude: -95.9882522, name: "ONEOK Field", source: "Test")
        for target in MapTarget.allCases {
            let url = try XCTUnwrap(target.webURL(for: point), "\(target.rawValue) has no share link")
            XCTAssertEqual(url.scheme, "https", target.rawValue)
            let parsed = try XCTUnwrap(MapParser.parseURL(url)?.selected, target.rawValue)
            XCTAssertEqual(try XCTUnwrap(parsed.latitude), 36.1605489, accuracy: 0.000001, target.rawValue)
            XCTAssertEqual(try XCTUnwrap(parsed.longitude), -95.9882522, accuracy: 0.000001, target.rawValue)
        }
    }

    func testOrganicAndCoMapsShareTheirSupportedMapLinks() throws {
        let point = MapPoint(latitude: 36.1605489, longitude: -95.9882522, name: "ONEOK Field", source: "Test")
        for target in [MapTarget.organic, .comaps] {
            let url = try XCTUnwrap(target.webURL(for: point))
            XCTAssertEqual(url.path, "/map")
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            XCTAssertEqual(items.first(where: { $0.name == "v" })?.value, "1")
            XCTAssertEqual(items.first(where: { $0.name == "n" })?.value, "ONEOK Field")
        }
    }
}
