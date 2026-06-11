import XCTest
@testable import Flux

final class BalanceTrendChartSeriesTests: XCTestCase {
    func testSplitsLineAtZeroCrossing() {
        let start = Date(timeIntervalSince1970: 0)
        let end = Date(timeIntervalSince1970: 10)

        let points = BalanceTrendChartSeries.points(
            from: [
                BalanceTrendPoint(date: start, balance: -10),
                BalanceTrendPoint(date: end, balance: 10)
            ]
        )

        XCTAssertEqual(points.count, 4)
        XCTAssertEqual(points.map(\.polarity), [.negative, .negative, .positive, .positive])
        XCTAssertEqual(points[1].balance, 0)
        XCTAssertEqual(points[2].balance, 0)
        XCTAssertEqual(points[1].date, points[2].date)
        XCTAssertNotEqual(points[1].segmentID, points[2].segmentID)
        XCTAssertEqual(points[1].date.timeIntervalSince1970, 5, accuracy: 0.001)
    }

    func testKeepsPositiveAndNegativeRunsInSeparateSegments() {
        let dates = (0..<5).map { Date(timeIntervalSince1970: Double($0 * 10)) }

        let points = BalanceTrendChartSeries.points(
            from: [
                BalanceTrendPoint(date: dates[0], balance: 10),
                BalanceTrendPoint(date: dates[1], balance: -10),
                BalanceTrendPoint(date: dates[2], balance: -5),
                BalanceTrendPoint(date: dates[3], balance: 5),
                BalanceTrendPoint(date: dates[4], balance: 8)
            ]
        )

        let positiveSegments = Set(points.filter { $0.polarity == .positive }.map(\.segmentID))
        let negativeSegments = Set(points.filter { $0.polarity == .negative }.map(\.segmentID))

        XCTAssertEqual(positiveSegments.count, 2)
        XCTAssertEqual(negativeSegments.count, 1)
    }
}
