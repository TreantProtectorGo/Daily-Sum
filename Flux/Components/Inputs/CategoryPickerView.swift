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
