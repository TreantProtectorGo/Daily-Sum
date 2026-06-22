import XCTest
@testable import Flux

final class TransactionEntryPresentationTests: XCTestCase {
    func testNewTransactionAmountUsesBottomDockedNumberPadPresentation() throws {
        let transactionSource = try sourceContents(
            at: "Flux/Views/Sheets/TransactionEntrySheet.swift"
        )
        let amountInputSource = try sourceContents(
            at: "Flux/Components/Inputs/AmountInputView.swift"
        )

        XCTAssertTrue(transactionSource.contains("numberPadPresentation: .docked"))
        XCTAssertTrue(transactionSource.contains("safeAreaInset(edge: .bottom"))
        XCTAssertTrue(transactionSource.contains("DockedAmountNumberPad"))
        XCTAssertTrue(amountInputSource.contains("enum AmountNumberPadPresentation"))
        XCTAssertTrue(amountInputSource.contains("case docked"))
        XCTAssertTrue(amountInputSource.contains("numberPad.grabber"))
        XCTAssertTrue(amountInputSource.contains("DragGesture"))
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
