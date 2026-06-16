import XCTest

final class IconManagementLayoutTests: XCTestCase {
    func testAccountTypeManagementUsesListRowsInsteadOfGridItems() throws {
        let source = try sourceFile(
            "Components",
            "Inputs",
            "AccountTypeSelectionBox.swift"
        )

        XCTAssertTrue(source.contains("IconManagementListRow"))
        XCTAssertTrue(source.contains("IconColorCircle(icon: definition.icon, color: definition.color, size: .small)"))
        XCTAssertFalse(source.contains("IconManagementGridItem("))
        XCTAssertFalse(source.contains("managementGridColumns"))
        XCTAssertFalse(source.contains("minHeight: 68"))
    }

    func testCategoryManagementUsesListRowsInsteadOfGridItems() throws {
        let source = try sourceFile(
            "Components",
            "Inputs",
            "CategoryPickerView.swift"
        )

        XCTAssertTrue(source.contains("IconManagementListRow"))
        XCTAssertTrue(source.contains("IconColorCircle(icon: category.icon, color: category.color, size: .small)"))
        XCTAssertFalse(source.contains("IconManagementGridItem("))
        XCTAssertFalse(source.contains("managementGridColumns"))
        XCTAssertFalse(source.contains("minHeight: 68"))
    }

    func testManagementListsSupportReordering() throws {
        let accountTypeSource = try sourceFile(
            "Components",
            "Inputs",
            "AccountTypeSelectionBox.swift"
        )
        let categorySource = try sourceFile(
            "Components",
            "Inputs",
            "CategoryPickerView.swift"
        )

        XCTAssertTrue(accountTypeSource.contains(".draggable"))
        XCTAssertTrue(accountTypeSource.contains(".dropDestination"))
        XCTAssertTrue(accountTypeSource.contains("AccountTypeDefinitionService(context: modelContext).reorder"))
        XCTAssertFalse(accountTypeSource.contains("arrow.up.arrow.down"))
        XCTAssertFalse(accountTypeSource.contains("reorderMode"))
        XCTAssertFalse(accountTypeSource.contains(".environment(\\.editMode"))
        XCTAssertFalse(accountTypeSource.contains(".onMove(perform: moveDefinitions)"))

        XCTAssertTrue(categorySource.contains(".draggable"))
        XCTAssertTrue(categorySource.contains(".dropDestination"))
        XCTAssertTrue(categorySource.contains("CategoryService(context: modelContext).reorder"))
        XCTAssertFalse(categorySource.contains("arrow.up.arrow.down"))
        XCTAssertFalse(categorySource.contains("reorderMode"))
        XCTAssertFalse(categorySource.contains(".environment(\\.editMode"))
        XCTAssertFalse(categorySource.contains(".onMove(perform: moveCategories)"))
    }

    func testManagementListRowUsesDefaultListSizing() throws {
        let source = try sourceFile(
            "Components",
            "Inputs",
            "IconColorSelectionComponents.swift"
        )

        XCTAssertTrue(source.contains("struct IconManagementListRow"))
        XCTAssertTrue(source.contains("HStack(spacing: 12)"))
        XCTAssertFalse(source.contains("minHeight: 68"))
    }

    func testManagementListRowUsesIconOnlyRedDeleteSwipeAction() throws {
        let source = try sourceFile(
            "Components",
            "Inputs",
            "IconColorSelectionComponents.swift"
        )

        guard let rowSource = source
            .components(separatedBy: "struct IconManagementListRow")
            .last?
            .components(separatedBy: "struct IconColorItemDraft")
            .first
        else {
            return XCTFail("IconManagementListRow should exist")
        }

        XCTAssertTrue(rowSource.contains("Button(role: .destructive, action: onDelete)"))
        XCTAssertTrue(rowSource.contains("Image(systemName: \"trash\")"))
        XCTAssertTrue(rowSource.contains(".tint(.red)"))
        XCTAssertTrue(rowSource.contains(".accessibilityLabel(AppLocalization.string(\"action.delete\""))
        XCTAssertFalse(rowSource.contains("\n                Label("))
    }

    private func sourceFile(_ pathComponents: String...) throws -> String {
        var sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Flux")

        for component in pathComponents {
            sourceURL.appendPathComponent(component)
        }

        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
