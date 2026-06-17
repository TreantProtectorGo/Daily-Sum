import XCTest

final class IconManagementLayoutTests: XCTestCase {
    func testAccountTypeManagementUsesListRowsInsteadOfGridItems() throws {
        let source = try sourceFile(
            "Components",
            "Inputs",
            "AccountTypeSelectionBox.swift"
        )
        let componentSource = try sourceFile(
            "Components",
            "Inputs",
            "IconColorSelectionComponents.swift"
        )

        XCTAssertTrue(source.contains("IconManagementReorderList("))
        XCTAssertTrue(componentSource.contains("IconManagementListRow"))
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
        let componentSource = try sourceFile(
            "Components",
            "Inputs",
            "IconColorSelectionComponents.swift"
        )

        XCTAssertTrue(source.contains("IconManagementReorderList("))
        XCTAssertTrue(componentSource.contains("IconManagementListRow"))
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

        XCTAssertTrue(accountTypeSource.contains("IconManagementReorderList("))
        XCTAssertTrue(accountTypeSource.contains("AccountTypeDefinitionService(context: modelContext).reorder"))
        XCTAssertFalse(accountTypeSource.contains("arrow.up.arrow.down"))
        XCTAssertFalse(accountTypeSource.contains("reorderMode"))
        XCTAssertFalse(accountTypeSource.contains(".environment(\\.editMode"))
        XCTAssertFalse(accountTypeSource.contains(".onMove(perform: moveDefinitions)"))
        XCTAssertFalse(accountTypeSource.contains(".draggable"))
        XCTAssertFalse(accountTypeSource.contains(".dropDestination"))
        XCTAssertFalse(accountTypeSource.contains("EditButton("))

        XCTAssertTrue(categorySource.contains("IconManagementReorderList("))
        XCTAssertTrue(categorySource.contains("CategoryService(context: modelContext).reorder"))
        XCTAssertFalse(categorySource.contains("arrow.up.arrow.down"))
        XCTAssertFalse(categorySource.contains("reorderMode"))
        XCTAssertFalse(categorySource.contains(".environment(\\.editMode"))
        XCTAssertFalse(categorySource.contains(".onMove(perform: moveCategories)"))
        XCTAssertFalse(categorySource.contains(".draggable"))
        XCTAssertFalse(categorySource.contains(".dropDestination"))
        XCTAssertFalse(categorySource.contains("EditButton("))
    }

    func testUIKitReorderListSupportsLongPressDragTapAndIconOnlyDestructiveSwipe() throws {
        let source = try sourceFile(
            "Components",
            "Inputs",
            "IconColorSelectionComponents.swift"
        )

        XCTAssertTrue(source.contains("struct IconManagementReorderList"))
        XCTAssertTrue(source.contains("UITableViewDragDelegate"))
        XCTAssertTrue(source.contains("UITableViewDropDelegate"))
        XCTAssertTrue(source.contains("tableView.dragInteractionEnabled = true"))
        XCTAssertTrue(source.contains("itemsForBeginning"))
        XCTAssertTrue(source.contains("didSelectRowAt"))
        XCTAssertTrue(source.contains("trailingSwipeActionsConfigurationForRowAt"))
        XCTAssertTrue(source.contains("UIContextualAction(style: .destructive, title: nil"))
        XCTAssertTrue(source.contains("UIImage(systemName: \"trash\")"))
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

    func testManagementListRowDoesNotWrapWholeRowInButton() throws {
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

        XCTAssertFalse(rowSource.contains("Button(action: onEdit)"))
        XCTAssertFalse(rowSource.contains(".swipeActions"))
        XCTAssertFalse(rowSource.contains("\n                Label("))
    }

    func testPickerListsFollowSortOrder() throws {
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

        XCTAssertTrue(accountTypeSource.contains("@Query(sort: \\AccountTypeDefinition.sortOrder)"))
        XCTAssertTrue(categorySource.contains("@Query(sort: \\Category.sortOrder)"))
        XCTAssertFalse(categorySource.contains("@Query(sort: \\Category.nameKey)"))
    }

    func testNoVisibleReorderToolbarButton() throws {
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

        for source in [accountTypeSource, categorySource] {
            XCTAssertFalse(source.contains("arrow.up.arrow.down"))
            XCTAssertFalse(source.contains("line.3.horizontal"))
            XCTAssertFalse(source.contains("EditButton("))
            XCTAssertFalse(source.contains("reorderMode"))
        }
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
