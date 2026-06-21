import XCTest
@testable import Flux

final class TransactionEntryPresentationTests: XCTestCase {
    func testNewTransactionAmountUsesInlineNumberPadPresentation() throws {
        let transactionSource = try sourceContents(
            at: "Flux/Views/Sheets/TransactionEntrySheet.swift"
        )
        let amountInputSource = try sourceContents(
            at: "Flux/Components/Inputs/AmountInputView.swift"
        )

        XCTAssertTrue(transactionSource.contains("numberPadPresentation: .inline"))
        XCTAssertTrue(amountInputSource.contains("enum AmountNumberPadPresentation"))
        XCTAssertTrue(amountInputSource.contains("case inline"))
    }

    func testAmountInputKeepsSheetPresentationAsDefaultForOtherFlows() throws {
        let source = try sourceContents(
            at: "Flux/Components/Inputs/AmountInputView.swift"
        )

        XCTAssertTrue(source.contains("numberPadPresentation: AmountNumberPadPresentation = .sheet"))
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
