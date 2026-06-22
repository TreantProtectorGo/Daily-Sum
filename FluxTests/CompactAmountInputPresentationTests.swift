import XCTest
@testable import Flux

final class CompactAmountInputPresentationTests: XCTestCase {
    func testAccountAndBudgetAmountsUseSharedDockedNumberPad() throws {
        let accountSource = try sourceContents(
            at: "Flux/Views/Sheets/AccountEntrySheet.swift"
        )
        let budgetSource = try sourceContents(
            at: "Flux/Views/Sheets/BudgetEntrySheet.swift"
        )
        let amountInputSource = try sourceContents(
            at: "Flux/Components/Inputs/AmountInputView.swift"
        )

        for source in [accountSource, budgetSource] {
            XCTAssertTrue(source.contains("@State private var amountInputSession = AmountInputSession()"))
            XCTAssertTrue(source.contains("numberPadPresentation: .docked"))
            XCTAssertTrue(source.contains("session: amountInputSession"))
            XCTAssertTrue(source.contains(".dockedAmountNumberPad("))
        }

        let compactSource = try compactAmountInputSource(from: amountInputSource)
        XCTAssertTrue(compactSource.contains("numberPadPresentation: AmountNumberPadPresentation = .sheet"))
        XCTAssertTrue(compactSource.contains("session: AmountInputSession? = nil"))
        XCTAssertTrue(compactSource.contains("@State private var ownedSession = AmountInputSession()"))
        XCTAssertFalse(compactSource.contains("@State private var isNumberPadPresented"))
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

    private func compactAmountInputSource(from source: String) throws -> String {
        let start = try XCTUnwrap(source.range(of: "struct CompactAmountInput: View"))
        let end = try XCTUnwrap(source.range(of: "private extension CustomNumberPadActionResult"))
        return String(source[start.lowerBound..<end.lowerBound])
    }
}
