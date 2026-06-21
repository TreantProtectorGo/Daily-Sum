import XCTest
@testable import Flux

final class CSVEncoderTests: XCTestCase {
    func testEncodeProducesUTF8BOMAndCRLFTerminatedRecords() throws {
        let data = try CSVEncoder().encode(
            headers: ["name", "amount"],
            rows: [[.text("Coffee"), .raw("12.5")]]
        )

        XCTAssertTrue(data.starts(with: [0xEF, 0xBB, 0xBF]))
        XCTAssertEqual(
            String(decoding: data.dropFirst(3), as: UTF8.self),
            "name,amount\r\nCoffee,12.5\r\n"
        )
    }

    func testEncodeSupportsHeaderOnlyExport() throws {
        let data = try CSVEncoder().encode(headers: ["id", "notes"], rows: [])

        XCTAssertEqual(
            String(decoding: data.dropFirst(3), as: UTF8.self),
            "id,notes\r\n"
        )
    }

    func testEncodeQuotesSpecialCharactersAndPreservesChineseText() throws {
        let data = try CSVEncoder().encode(
            headers: ["value"],
            rows: [
                [.text("港式,奶茶")],
                [.text("He said \"hello\"")],
                [.text("line 1\nline 2")],
                [.text("line 1\rline 2")]
            ]
        )

        XCTAssertEqual(
            String(decoding: data.dropFirst(3), as: UTF8.self),
            "value\r\n\"港式,奶茶\"\r\n\"He said \"\"hello\"\"\"\r\n\"line 1\nline 2\"\r\n\"line 1\rline 2\"\r\n"
        )
    }

    func testEncodeProtectsFormulaLikeTextButLeavesRawNumbersUnchanged() throws {
        let data = try CSVEncoder().encode(
            headers: ["notes", "amount"],
            rows: [
                [.text("=SUM(A1:A2)"), .raw("-12.5")],
                [.text("+cmd"), .raw("0")],
                [.text("-formula"), .raw("1")],
                [.text("@mention"), .raw("2")]
            ]
        )

        XCTAssertEqual(
            String(decoding: data.dropFirst(3), as: UTF8.self),
            "notes,amount\r\n'=SUM(A1:A2),-12.5\r\n'+cmd,0\r\n'-formula,1\r\n'@mention,2\r\n"
        )
    }

    func testEncodeRejectsRowsWithUnexpectedFieldCount() {
        XCTAssertThrowsError(
            try CSVEncoder().encode(
                headers: ["id", "notes"],
                rows: [[.raw("1")]]
            )
        ) { error in
            XCTAssertEqual(error as? CSVEncodingError, .fieldCountMismatch(expected: 2, actual: 1))
        }
    }
}
