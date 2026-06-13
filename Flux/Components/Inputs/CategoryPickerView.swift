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

    var preferredCategoryOrder: [String] {
        switch self {
        case .transaction(.expense), .budgetExpense:
            return [
                "category.expense.food",
                "category.expense.groceries",
                "category.expense.dining",
                "category.expense.coffee",
                "category.expense.home",
                "category.expense.housing",
                "category.expense.bills",
                "category.expense.insurance",
                "category.expense.tax",
                "category.expense.transport",
                "category.expense.travel",
                "category.expense.health",
                "category.expense.personalCare",
                "category.expense.pet",
                "category.expense.education",
                "category.expense.upskilling",
                "category.expense.shopping",
                "category.expense.entertainment",
                "category.expense.subscriptions",
                "category.expense.gifts"
            ]
        case .transaction(.income):
            return [
                "category.income.salary",
                "category.income.bonus",
                "category.income.freelance",
                "category.income.secondHandSale",
                "category.income.interest",
                "category.income.investment",
                "category.income.governmentSubsidy",
                "category.income.gift",
                "category.income.refund"
            ]
        }
    }
}

struct CategoryPickerView: View {
    @Binding var selectedCategory: Category?
    let mode: CategoryPickerMode
    let presentationTrigger: Int
    let onSelectionCompleted: ((Category?) -> Void)?
    
    @Query(sort: \Category.nameKey) private var allCategories: [Category]
    @State private var showCategorySheet = false
    
    private var categories: [Category] {
        let filtered = allCategories.filter { $0.type == mode.categoryType }
        let order = Dictionary(uniqueKeysWithValues: mode.preferredCategoryOrder.enumerated().map { ($0.element, $0.offset) })
        return filtered.sorted { lhs, rhs in
            let lhsRank = order[lhs.nameKey] ?? Int.max
            let rhsRank = order[rhs.nameKey] ?? Int.max
            if lhsRank != rhsRank { return lhsRank < rhsRank }
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
                    Button("Manage") {
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

    @Query(sort: \Category.nameKey) private var allCategories: [Category]

    @State private var editorMode: EditorMode?
    @State private var deleteCandidate: Category?
    @State private var errorMessage = ""
    @State private var showError = false

    private var categories: [Category] {
        allCategories
            .filter { $0.type == mode.categoryType }
            .sorted {
                $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
            }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(categories) { category in
                    Button {
                        editorMode = .edit(category)
                    } label: {
                        HStack(spacing: 12) {
                            IconColorCircle(icon: category.icon, color: category.color, size: .small)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.displayName)
                                    .font(.body.weight(selectedCategory?.id == category.id ? .semibold : .regular))

                                Text(category.isSystemDefault ? "Default category" : "Custom category")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if selectedCategory?.id == category.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(AppColors.selectedNavigation)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button(role: .destructive) {
                            deleteCandidate = category
                        } label: {
                            Label(AppLocalization.string("action.delete", defaultValue: "Delete"), systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Manage Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppLocalization.string("action.done", defaultValue: "Done")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        editorMode = .create
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(AppLocalization.string("action.add", defaultValue: "Add"))
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
                "Delete Category?",
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

                    Button(AppLocalization.string("action.cancel", defaultValue: "Cancel"), role: .cancel) {
                        self.deleteCandidate = nil
                    }
                }
            } message: {
                Text("Transactions using this category will keep the transaction and clear the category.")
            }
            .alert(AppLocalization.string("error.title", defaultValue: "Error"), isPresented: $showError) {
                Button(AppLocalization.string("action.ok", defaultValue: "OK")) { }
            } message: {
                Text(errorMessage)
            }
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
                return "New Category"
            case .edit:
                return "Edit Category"
            }
        }

        var initialDraft: IconColorItemDraft {
            switch self {
            case .create:
                return IconColorItemDraft(
                    name: "",
                    icon: "tag",
                    colorHex: "#808080"
                )
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
        Button(action: onSelect) {
            VStack(spacing: 8) {
                CategoryIcon(category: category, size: .medium)
                    .overlay {
                        if isSelected {
                            Circle()
                                .stroke(category.color, lineWidth: 3)
                                .padding(-6)
                        }
                    }
                
                Text(category.displayName)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(minWidth: 70)
        }
        .buttonStyle(.plain)
    }
}

private struct CategoryPlaceholderGridItem: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                Circle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 34, height: 34)
                    .overlay {
                        Image(systemName: icon)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .overlay {
                        if isSelected {
                            Circle()
                                .stroke(Color.secondary, lineWidth: 2)
                                .padding(-6)
                        }
                    }

                Text(title)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(minWidth: 70)
        }
        .buttonStyle(.plain)
    }
}

struct InlineCategoryPicker: View {
    @Binding var selectedCategory: Category?
    let transactionType: TransactionType
    
    @Query(sort: \Category.nameKey) private var allCategories: [Category]
    
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
