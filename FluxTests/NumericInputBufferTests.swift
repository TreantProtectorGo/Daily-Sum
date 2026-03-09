import XCTest
@testable import Flux

final class NumericInputBufferTests: XCTestCase {
    private let enUS = Locale(identifier: "en_US")

    func testDisplaysGroupingSeparatorsWhileAcceptingUpToFourFractionDigits() {
        var buffer = NumericExpressionBuffer(maxFractionDigits: 4)

        "1234.56789".forEach { _ = buffer.appendCharacter($0) }

        XCTAssertEqual(buffer.displayText(locale: enUS), "1,234.5678")
        XCTAssertEqual(buffer.liveDecimalValue, Decimal(string: "1234.5678"))
    }

    func testAcceptsLocaleCommaAsDecimalSeparatorInput() {
        var buffer = NumericExpressionBuffer(maxFractionDigits: 4)

        "1234,5".forEach { _ = buffer.appendCharacter($0) }

        XCTAssertEqual(buffer.displayText(locale: enUS), "1,234.5")
        XCTAssertEqual(buffer.liveDecimalValue, Decimal(string: "1234.5"))
    }

    func testChainedOperationsUseStandardPrecedenceWhenCommitted() {
        var buffer = NumericExpressionBuffer(maxFractionDigits: 4)

        "12".forEach { _ = buffer.appendCharacter($0) }
        _ = buffer.insertOperator(.add)
        "3".forEach { _ = buffer.appendCharacter($0) }
        _ = buffer.insertOperator(.multiply)
        "4".forEach { _ = buffer.appendCharacter($0) }

        let committed = buffer.commit()

        XCTAssertEqual(committed, 24)
        XCTAssertEqual(buffer.displayText(locale: enUS), "24")
    }

    func testCommitIgnoresTrailingOperator() {
        var buffer = NumericExpressionBuffer(maxFractionDigits: 4)

        "12".forEach { _ = buffer.appendCharacter($0) }
        _ = buffer.insertOperator(.add)

        let committed = buffer.commit()

        XCTAssertEqual(committed, 12)
        XCTAssertEqual(buffer.displayText(locale: enUS), "12")
    }

    func testDivisionByZeroBecomesNoOpDuringCommit() {
        var buffer = NumericExpressionBuffer(maxFractionDigits: 4)

        "12".forEach { _ = buffer.appendCharacter($0) }
        _ = buffer.insertOperator(.add)
        "8".forEach { _ = buffer.appendCharacter($0) }
        _ = buffer.insertOperator(.divide)
        _ = buffer.appendCharacter("0")

        let committed = buffer.commit()

        XCTAssertEqual(committed, 20)
        XCTAssertEqual(buffer.displayText(locale: enUS), "20")
    }

    func testCommitRoundsHalfUpToFourFractionDigits() {
        var buffer = NumericExpressionBuffer(maxFractionDigits: 4)

        _ = buffer.appendCharacter("2")
        _ = buffer.insertOperator(.divide)
        _ = buffer.appendCharacter("3")

        let committed = buffer.commit()

        XCTAssertEqual(committed, Decimal(string: "0.6667"))
        XCTAssertEqual(buffer.displayText(locale: enUS), "0.6667")
    }

    func testBackspaceTraversesDigitsThenOperatorsWhileKeepingDisplayFormatted() {
        var buffer = NumericExpressionBuffer(maxFractionDigits: 4)

        "1234".forEach { _ = buffer.appendCharacter($0) }
        _ = buffer.insertOperator(.add)
        "56".forEach { _ = buffer.appendCharacter($0) }

        XCTAssertEqual(buffer.displayText(locale: enUS), "1,234 + 56")

        _ = buffer.backspace()
        XCTAssertEqual(buffer.displayText(locale: enUS), "1,234 + 5")

        _ = buffer.backspace()
        XCTAssertEqual(buffer.displayText(locale: enUS), "1,234 + ")

        _ = buffer.backspace()
        XCTAssertEqual(buffer.displayText(locale: enUS), "1,234")
    }
}
