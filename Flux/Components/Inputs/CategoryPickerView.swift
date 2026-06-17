import SwiftUI
import SwiftData

enum CategoryPickerMode {
    case transaction(TransactionType)
    case budgetExpense

    var categoryType: TransactionType {
        switch self {
        case .transaction(let type):
            return type
        case .budgetExpense:
            return .expense
        }
    }

    var title: String {
        switch self {
        case .transaction(let type):
            return type == .expense
                ? AppLocalization.string("category.select.expense", defaultValue: "Select Category")
                : AppLocalization.string("category.select.income", defaultValue: "Select Category")
        case .budgetExpense:
            return AppLocalization.string("budget.category.select", defaultValue: "Select Budget Category")
        }
    }

    var placeholderTitle: String {
        switch self {
        case .transaction(let type):
            return type == .expense
                ? AppLocalization.string("category.select.expense", defaultValue: "Select Category")
                : AppLocalization.string("category.select.income", defaultValue: "Select Category")
        case .budgetExpense:
            return AppLocalization.string("budget.allCategories", defaultValue: "All Categories")
        }
    }

    var placeholderIcon: String {
        switch self {
        case .transaction:
            return "tag"
        case .budgetExpense:
            return "square.grid.2x2.fill"
        }
    }

    var showsPlaceholderOption: Bool {
        switch self {
        case .transaction:
            return false
        case .budgetExpense:
            return true
        }
    }

}

struct CategoryPickerView: View {
    @Binding var selectedCategory: Category?
    let mode: CategoryPickerMode
    let presentationTrigger: Int
    let onSelectionCompleted: ((Category?) -> Void)?
    
    @Query(sort: \Category.sortOrder) private var allCategories: [Category]
    @State private var showCategorySheet = false
    
    private var categories: [Category] {
        allCategories.filter { $0.type == mode.categoryType }.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
    }
    
    init(
        selectedCategory: Binding<Category?>,
        transactionType: TransactionType,
        presentationTrigger: Int = 0,
        onSelectionCompleted: ((Category?) -> Void)? = nil
    ) {
        self._selectedCategory = selectedCategory
        self.mode = .transaction(transactionType)
        self.presentationTrigger = presentationTrigger
        self.onSelectionCompleted = onSelectionCompleted
    }

    init(
        selectedCategory: Binding<Category?>,
        mode: CategoryPickerMode,
        presentationTrigger: Int = 0,
        onSelectionCompleted: ((Category?) -> Void)? = nil
    ) {
        self._selectedCategory = selectedCategory
        self.mode = mode
        self.presentationTrigger = presentationTrigger
        self.onSelectionCompleted = onSelectionCompleted
    }
    
    var body: some View {
        Button {
            showCategorySheet = true
        } label: {
            HStack {
                if let category = selectedCategory {
                    CategoryIcon(category: category, size: .small)
                    Text(category.displayName)
                        .font(.body)
                } else {
                    if mode.showsPlaceholderOption {
                        BudgetAllCategoriesIcon(size: .small)
                    } else {
                        PlaceholderCategoryIcon(size: .small)
                    }
                    Text(mode.placeholderTitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("transaction.categoryPicker.trigger")
        .onChange(of: presentationTrigger) { _, _ in
            showCategorySheet = true
        }
        .sheet(isPresented: $showCategorySheet) {
            CategorySelectionSheet(
                selectedCategory: $selectedCategory,
                categories: categories,
                mode: mode,
                onSelectionCompleted: onSelectionCompleted
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

private struct CategorySelectionSheet: View {
    @Binding var selectedCategory: Category?
    let categories: [Category]
    let mode: CategoryPickerMode
    let onSelectionCompleted: ((Category?) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var showManagement = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 16) {
                    if mode.showsPlaceholderOption {
                        CategoryPlaceholderGridItem(
                            title: mode.placeholderTitle,
                            icon: mode.placeholderIcon,
                            isSelected: selectedCategory == nil
                        ) {
                            selectedCategory = nil
                            onSelectionCompleted?(nil)
                            dismiss()
                        }
                    }

                    ForEach(categories) { category in
                        CategoryGridItem(
                            category: category,
                            isSelected: selectedCategory?.id == category.id
                        ) {
                            selectedCategory = category
                            onSelectionCompleted?(category)
                            dismiss()
                        }
                    }
                }
                .padding()
            }
            .accessibilityIdentifier("transaction.categoryPicker.sheet")
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    IconToolbarButton(
                        systemName: "pencil",
                        accessibilityLabel: AppLocalization.string(
                            "category.editList",
                            defaultValue: "Edit categories"
                        )
                    ) {
                        showManagement = true
                    }
                }
            }
            .sheet(isPresented: $showManagement) {
                CategoryManagementSheet(
                    selectedCategory: $selectedCategory,
                    mode: mode
                )
            }
        }
    }
}

private struct CategoryManagementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Binding var selectedCategory: Category?
    let mode: CategoryPickerMode

    @Query(sort: \Category.sortOrder) private var allCategories: [Category]
    @Query private var transactions: [Transaction]

    @State private var editorMode: EditorMode?
    @State private var deleteCandidate: Category?
    @State private var errorMessage = ""
    @State private var showError = false

    private var categories: [Category] {
        allCategories.filter { $0.type == mode.categoryType }.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            IconManagementReorderList(
                items: categories,
                selectedID: selectedCategory?.id,
                title: \.displayName,
                countText: { category in "\(usageCount(for: category))" },
                countAccessibilityLabel: transactionCountText,
                tintColor: \.color
            ) { category in
                IconColorCircle(icon: category.icon, color: category.color, size: .small)
            } onEdit: { category in
                editorMode = .edit(category)
            } onDelete: { category in
                deleteCandidate = category
            } onMove: { reorderedCategories in
                moveCategories(reorderedCategories)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(AppLocalization.string("category.title", defaultValue: "Categories"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    IconToolbarButton(
                        systemName: "checkmark",
                        accessibilityLabel: AppLocalization.string("action.finish", defaultValue: "Finish")
                    ) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    IconToolbarButton(
                        systemName: "plus",
                        accessibilityLabel: AppLocalization.string("action.add", defaultValue: "Add")
                    ) {
                        editorMode = .create
                    }
                }
            }
            .sheet(item: $editorMode) { mode in
                IconColorItemEditorSheet(
                    title: mode.title,
                    initialDraft: mode.initialDraft
                ) { draft in
                    try save(draft, mode: mode)
                }
            }
            .confirmationDialog(
                AppLocalization.string(
                    "category.delete.confirm.title",
                    defaultValue: "Delete Category?"
                ),
                isPresented: Binding(
                    get: { deleteCandidate != nil },
                    set: { if !$0 { deleteCandidate = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let deleteCandidate {
                    Button(AppLocalization.string("action.delete", defaultValue: "Delete"), role: .destructive) {
                        delete(deleteCandidate)
                    }

                    Button(
                        AppLocalization.string(
                            "category.delete.keep",
                            defaultValue: "Keep Category"
                        ),
                        role: .cancel
                    ) {
                        self.deleteCandidate = nil
                    }
                }
            } message: {
                Text(
                    AppLocalization.string(
                        "category.delete.confirm.message",
                        defaultValue: "Transactions using this category will keep the transaction and clear the category."
                    )
                )
            }
            .alert(AppLocalization.string("error.title", defaultValue: "Error"), isPresented: $showError) {
                Button(AppLocalization.string("action.ok", defaultValue: "OK")) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func moveCategories(_ reorderedCategories: [Category]) {
        do {
            try CategoryService(context: modelContext).reorder(
                reorderedCategories,
                type: mode.categoryType
            )
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func save(_ draft: IconColorItemDraft, mode: EditorMode) throws {
        let service = CategoryService(context: modelContext)
        switch mode {
        case .create:
            let category = try service.create(
                name: draft.name,
                icon: draft.icon,
                colorHex: draft.colorHex,
                type: self.mode.categoryType
            )
            selectedCategory = category
        case .edit(let category):
            try service.update(
                category,
                name: draft.name,
                icon: draft.icon,
                colorHex: draft.colorHex
            )
        }
    }

    private func usageCount(for category: Category) -> Int {
        transactions.filter { $0.category?.id == category.id }.count
    }

    private func transactionCountText(for category: Category) -> String {
        let count = usageCount(for: category)
        let key = count == 1 ? "transaction.count.one" : "transaction.count.other"
        return AppLocalization.formatted(key, defaultValue: count == 1 ? "%lld transaction" : "%lld transactions", Int64(count))
    }

    private func delete(_ category: Category) {
        do {
            try CategoryService(context: modelContext).delete(category)
            if selectedCategory?.id == category.id {
                selectedCategory = nil
            }
            deleteCandidate = nil
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private enum EditorMode: Identifiable {
        case create
        case edit(Category)

        var id: String {
            switch self {
            case .create:
                return "create"
            case .edit(let category):
                return category.id.uuidString
            }
        }

        var title: String {
            switch self {
            case .create:
                return AppLocalization.string("category.new", defaultValue: "New Category")
            case .edit:
                return AppLocalization.string("category.edit", defaultValue: "Edit Category")
            }
        }

        var initialDraft: IconColorItemDraft {
            switch self {
            case .create:
                return .empty
            case .edit(let category):
                return IconColorItemDraft(
                    name: category.displayName,
                    icon: category.icon,
                    colorHex: category.colorHex
                )
            }
        }
    }
}

private struct CategoryGridItem: View {
    let category: Category
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        IconTitleGridItem(
            title: category.displayName,
            tintColor: category.color,
            isSelected: isSelected
        ) {
            CategoryIcon(category: category, size: .medium)
        } onSelect: {
            onSelect()
        }
    }
}

private struct CategoryPlaceholderGridItem: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        IconTitleGridItem(
            title: title,
            tintColor: .secondary,
            isSelected: isSelected
        ) {
            IconColorCircle(icon: icon, color: .secondary, size: .medium)
        } onSelect: {
            onSelect()
        }
    }
}

struct InlineCategoryPicker: View {
    @Binding var selectedCategory: Category?
    let transactionType: TransactionType
    
    @Query(sort: \Category.sortOrder) private var allCategories: [Category]
    
    private var categories: [Category] {
        allCategories.filter { $0.type == transactionType }
    }
    
    init(selectedCategory: Binding<Category?>, transactionType: TransactionType) {
        self._selectedCategory = selectedCategory
        self.transactionType = transactionType
    }
    
    var body: some View {
        let selection = Binding<Category?>(
            get: { selectedCategory ?? categories.first },
            set: { selectedCategory = $0 }
        )

        Picker(AppLocalization.string("category.label", defaultValue: "Category"), selection: selection) {
            ForEach(categories) { category in
                HStack {
                    Image(systemName: category.icon)
                        .foregroundStyle(category.color)
                    Text(category.displayName)
                }
                .tag(category as Category?)
            }
        }
    }
}

#Preview("Category Picker") {
    struct PreviewWrapper: View {
        @State private var selectedCategory: Category?
        
        var body: some View {
            ZStack {
                Color.blue.opacity(0.2).ignoresSafeArea()
                
                VStack(spacing: 24) {
                    CategoryPickerView(
                        selectedCategory: $selectedCategory,
                        transactionType: .expense
                    )
                    
                    if let category = selectedCategory {
                        Text("Selected: \(category.displayName)")
                    } else {
                        Text("No category selected")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
        }
    }
    
    return PreviewWrapper()
}
