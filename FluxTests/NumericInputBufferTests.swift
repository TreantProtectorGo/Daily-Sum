import XCTest
@testable import Flux

final class NumericInputBufferTests: XCTestCase {
    func testAcceptsUpToFourFractionDigitsAndRejectsFifth() {
        var buffer = NumericInputBuffer(maxFractionDigits: 4)

        "12.34567".forEach { buffer.appendCharacter($0) }

        XCTAssertEqual(buffer.text, "12.3456")
        XCTAssertEqual(buffer.decimalValue, Decimal(string: "12.3456"))
    }

    func testMultipleDecimalSeparatorsAreIgnoredAfterFirst() {
        var buffer = NumericInputBuffer(maxFractionDigits: 4)

        "1..2.3".forEach { buffer.appendCharacter($0) }

        XCTAssertEqual(buffer.text, "1.23")
        XCTAssertEqual(buffer.decimalValue, Decimal(string: "1.23"))
    }

    func testBackspaceAcrossFractionIntegerAndEmpty() {
        var buffer = NumericInputBuffer(maxFractionDigits: 4)
        "12.3".forEach { buffer.appendCharacter($0) }

        buffer.backspace()
        XCTAssertEqual(buffer.text, "12.")

        buffer.backspace()
        XCTAssertEqual(buffer.text, "12")

        buffer.backspace()
        XCTAssertEqual(buffer.text, "1")

        buffer.backspace()
        XCTAssertEqual(buffer.text, "")

        buffer.backspace()
        XCTAssertEqual(buffer.text, "")
        XCTAssertEqual(buffer.decimalValue, 0)
    }

    func testNegativeSignIsIgnored() {
        var buffer = NumericInputBuffer(maxFractionDigits: 4)

        buffer.appendCharacter("-")
        "123".forEach { buffer.appendCharacter($0) }

        XCTAssertEqual(buffer.text, "123")
        XCTAssertEqual(buffer.decimalValue, 123)
    }

    func testInitialValueFormattingDoesNotInsertGroupingSeparators() {
        let buffer = NumericInputBuffer(initialValue: Decimal(string: "1234.5678")!, maxFractionDigits: 4)

        XCTAssertEqual(buffer.text, "1234.5678")
        XCTAssertEqual(buffer.decimalValue, Decimal(string: "1234.5678"))
    }

    func testInitialTextWithGroupingSeparatorIsParsedCorrectly() {
        let buffer = NumericInputBuffer(initialText: "1,234.56", maxFractionDigits: 4)

        XCTAssertEqual(buffer.text, "1234.56")
        XCTAssertEqual(buffer.decimalValue, Decimal(string: "1234.56"))
    }
}
