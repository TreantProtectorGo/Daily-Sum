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

    func testNewTransactionRefreshesTravelCurrencyAndReappliesUntouchedDefault() throws {
        let source = try sourceContents(
            at: "Flux/Views/Sheets/TransactionEntrySheet.swift"
        )

        XCTAssertTrue(
            source.contains(
                ".task {\n                await refreshDetectedTravelCurrency()\n            }"
            )
        )
        XCTAssertTrue(
            source.contains(
                ".onChange(of: detectedTravelCurrencyCode) { _, _ in\n" +
                "                applyTravelTransactionDefaultIfNeeded()\n" +
                "            }"
            )
        )
    }

    func testAppActivationRefreshesTravelCurrencyOutsideMaintenanceThrottle() throws {
        let source = try sourceContents(at: "Flux/FluxApp.swift")
        let activationStart = try XCTUnwrap(
            source.range(of: ".onChange(of: scenePhase)")
        )
        let activationSource = source[activationStart.lowerBound...]
        let refreshIndex = try XCTUnwrap(
            activationSource.range(of: "await refreshTravelCurrencyPreferenceIfNeeded()")
        ).lowerBound
        let throttleIndex = try XCTUnwrap(
            activationSource.range(of: "activationMaintenancePolicy.claimRun()")
        ).lowerBound

        XCTAssertLessThan(refreshIndex, throttleIndex)
    }

    func testIncomeAndExpenseEntriesExposeIndependentForeignCurrencyControls() throws {
        let source = try sourceContents(
            at: "Flux/Views/Sheets/TransactionEntrySheet.swift"
        )
        let pickerSource = try sourceContents(
            at: "Flux/Components/Inputs/TransactionCurrencyPickerView.swift"
        )

        XCTAssertTrue(source.contains("manualTransactionCurrencyCode"))
        XCTAssertTrue(pickerSource.contains("transaction.travel.currency"))
        XCTAssertTrue(source.contains("private var availableTransactionCurrencies"))
        XCTAssertTrue(source.contains("SupportedCurrency.allCases"))
        XCTAssertTrue(
            source.contains(
                "if existingTravelSnapshot == nil, isTravelTransaction"
            )
        )
        XCTAssertTrue(
            source.contains(
                "manualTransactionCurrencyCode ?? resolvedCurrentTravelCurrencyCode"
            )
        )
        XCTAssertTrue(
            source.contains(
                "convertInputAmountPreservingAccountValue"
            )
        )
        XCTAssertFalse(source.contains("guard transactionType == .expense else { return }"))
        XCTAssertFalse(
            source.contains(
                "guard transactionType == .expense,\n              isTravelTransaction"
            )
        )
    }

    func testTransactionCurrencyPickerSupportsSuggestedRecentAndSearchableCurrencies() throws {
        let entrySource = try sourceContents(
            at: "Flux/Views/Sheets/TransactionEntrySheet.swift"
        )
        let pickerSource = try sourceContents(
            at: "Flux/Components/Inputs/TransactionCurrencyPickerView.swift"
        )

        XCTAssertTrue(entrySource.contains("TransactionCurrencyPickerView("))
        XCTAssertTrue(entrySource.contains("suggestedTransactionCurrencyCode"))
        XCTAssertTrue(pickerSource.contains(".searchable("))
        XCTAssertTrue(pickerSource.contains("transaction.currencyPicker.suggested"))
        XCTAssertTrue(pickerSource.contains("transaction.currencyPicker.recent"))
        XCTAssertTrue(pickerSource.contains("transaction.currencyPicker.all"))
        XCTAssertTrue(pickerSource.contains("RecentTransactionCurrencyPreference.record"))
    }

    func testTransactionEntryOmitsSectionTitlesToPreserveKeyboardSpace() throws {
        let source = try sourceContents(
            at: "Flux/Views/Sheets/TransactionEntrySheet.swift"
        )

        XCTAssertFalse(
            source.contains(
                "Section(AppLocalization.string(\"transaction.amount\""
            )
        )
        XCTAssertFalse(
            source.contains(
                "Text(AppLocalization.string(\"transaction.details\""
            )
        )
        XCTAssertFalse(source.contains("\"transaction.schedule.header\""))
        XCTAssertFalse(
            source.contains(
                "Section(AppLocalization.string(\"transaction.notes\""
            )
        )
        XCTAssertTrue(source.contains("\"transaction.schedule.footer\""))
        XCTAssertTrue(source.contains("\"transaction.notes.placeholder\""))
    }

    func testTravelCurrencyDetectionUsesRecentCoarseLocationBeforeRequestingANewFix() throws {
        let source = try sourceContents(
            at: "Flux/Services/TravelCurrencyLocationService.swift"
        )

        XCTAssertTrue(source.contains("locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers"))
        XCTAssertTrue(source.contains("locationManager.location"))
        XCTAssertTrue(source.contains("TravelCurrencyLocationSelection.isRecent"))
        XCTAssertTrue(
            source.contains(
                "horizontalAccuracy <= kCLLocationAccuracyThreeKilometers"
            )
        )
    }

    func testSuccessfulSaveInvalidatesEveryMountedTransactionSurface() throws {
        let entrySource = try sourceContents(
            at: "Flux/Views/Sheets/TransactionEntrySheet.swift"
        )
        let listSource = try sourceContents(
            at: "Flux/Views/TransactionListView.swift"
        )
        let dashboardSource = try sourceContents(
            at: "Flux/Views/DashboardView.swift"
        )

        XCTAssertTrue(
            entrySource.contains("TransactionDataChangeStore.shared.markChanged()")
        )
        XCTAssertTrue(
            listSource.contains(
                "@State private var transactionDataChanges = TransactionDataChangeStore.shared"
            )
        )
        XCTAssertTrue(
            listSource.contains(".task(id: transactionDataChanges.revision)")
        )
        XCTAssertTrue(
            dashboardSource.contains(
                "@State private var transactionDataChanges = TransactionDataChangeStore.shared"
            )
        )
        XCTAssertTrue(
            dashboardSource.contains("transactionDataChanges.revision")
        )
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
