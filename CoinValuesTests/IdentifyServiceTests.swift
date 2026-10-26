import XCTest
@testable import CoinValues

/// Calls the live identification server with the bundled sample coin. Debug builds send the
/// dev token, so no App Store purchase is needed.
final class IdentifyServiceTests: XCTestCase {
    func testSampleCoinIsIdentified() async throws {
        let front = try XCTUnwrap(UIImage(named: "SampleFront").flatMap { ImageProcessing.jpeg($0.scaled(toMaxSide: ImageProcessing.uploadSize)) })
        let back = try XCTUnwrap(UIImage(named: "SampleBack").flatMap { ImageProcessing.jpeg($0.scaled(toMaxSide: ImageProcessing.uploadSize)) })
        let result = try await CoinIdentifier(transactionJWS: nil).identify(front: front, back: back)
        XCTAssertTrue(result.isCoin)
        XCTAssertTrue(result.name.contains("Quarter"), result.name)
        XCTAssertEqual(result.year, "1944")
        XCTAssertTrue(result.mintMark.hasPrefix("S"), result.mintMark)
        XCTAssertGreaterThan(result.valueHighUSD, 0)
        XCTAssertLessThanOrEqual(result.valueLowUSD, result.valueHighUSD)
    }
}
