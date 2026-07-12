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

    func testRecurringEditOffersBothGeneratedTransactionSyncScopes() throws {
        let source = try sourceContents(
            at: "Flux/Views/Sheets/TransactionEntrySheet.swift"
        )

        XCTAssertTrue(source.contains("showSubscriptionSyncScopeDialog"))
        XCTAssertTrue(source.contains(".confirmationDialog("))
        XCTAssertTrue(source.contains("syncScope: .todayAndFuture"))
        XCTAssertTrue(source.contains("syncScope: .allGenerated"))
        XCTAssertTrue(source.contains("transaction.subscription.sync.todayAndFuture"))
        XCTAssertTrue(source.contains("transaction.subscription.sync.allGenerated"))
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
