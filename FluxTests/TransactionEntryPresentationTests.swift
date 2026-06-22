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

        XCTAssertTrue(transactionSource.contains("session: amountInputSession"))
        XCTAssertTrue(transactionSource.contains(".dockedAmountNumberPad("))
        XCTAssertFalse(transactionSource.contains("safeAreaInset(edge: .bottom"))
        XCTAssertFalse(transactionSource.contains("DockedAmountNumberPad("))
        XCTAssertFalse(amountInputSource.contains("AmountNumberPadPresentation"))
        XCTAssertTrue(amountInputSource.contains("func dockedAmountNumberPad("))
        XCTAssertTrue(amountInputSource.contains("safeAreaInset(edge: .bottom"))
        XCTAssertTrue(amountInputSource.contains("DockedAmountNumberPad("))
        XCTAssertFalse(amountInputSource.contains("numberPad.grabber"))
        XCTAssertTrue(amountInputSource.contains("DragGesture"))
        XCTAssertFalse(amountInputSource.contains(".overlay(alignment: .top)"))
    }

    func testAmountInputDoesNotRetainLegacySheetPresentation() throws {
        let source = try sourceContents(
            at: "Flux/Components/Inputs/AmountInputView.swift"
        )

        XCTAssertFalse(source.contains("numberPadPresentation"))
        XCTAssertFalse(source.contains("sheetPresentationBinding"))
        XCTAssertFalse(source.contains("presentationDetents([.height(CustomNumberPadLayout.sheetHeight)])"))
        XCTAssertFalse(source.contains("presentationDragIndicator(.visible)"))
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
