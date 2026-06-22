import XCTest
@testable import Flux

final class ExchangeCalculatorPresentationTests: XCTestCase {
    func testExchangeCalculatorUsesDockedAmountNumberPadForConsistentInputExperience() throws {
        let amountInputSource = try sourceContents(
            at: "Flux/Components/Inputs/AmountInputView.swift"
        )
        let inlineSource = try sourceContents(
            at: "Flux/Views/Sheets/ExchangeCalculatorInlineView.swift"
        )
        let sheetSource = try sourceContents(
            at: "Flux/Views/Sheets/ExchangeCalculatorSheet.swift"
        )

        XCTAssertTrue(inlineSource.contains("@State private var amountInputSession = AmountInputSession()"))
        XCTAssertTrue(inlineSource.contains("numberPadPresentation: .docked"))
        XCTAssertTrue(inlineSource.contains("session: amountInputSession"))
        XCTAssertTrue(inlineSource.contains(".dockedAmountNumberPad("))
        XCTAssertFalse(inlineSource.contains("safeAreaInset(edge: .bottom"))
        XCTAssertFalse(inlineSource.contains("DockedAmountNumberPad("))

        XCTAssertTrue(sheetSource.contains("@State private var amountInputSession = AmountInputSession()"))
        XCTAssertTrue(sheetSource.contains("numberPadPresentation: .docked"))
        XCTAssertTrue(sheetSource.contains("session: amountInputSession"))
        XCTAssertTrue(sheetSource.contains(".dockedAmountNumberPad("))
        XCTAssertFalse(sheetSource.contains("safeAreaInset(edge: .bottom"))
        XCTAssertFalse(sheetSource.contains("DockedAmountNumberPad("))

        XCTAssertTrue(amountInputSource.contains("func dockedAmountNumberPad("))
        XCTAssertTrue(amountInputSource.contains("safeAreaInset(edge: .bottom"))
        XCTAssertTrue(amountInputSource.contains("DockedAmountNumberPad("))
    }

    private var repositoryURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func sourceContents(at relativePath: String) throws -> String {
        try String(
            contentsOf: repositoryURL.appending(path: relativePath),
            encoding: .utf8
        )
    }
}
