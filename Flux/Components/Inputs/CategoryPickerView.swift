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
                ? String(localized: "category.select.expense", defaultValue: "Select Category")
                : String(localized: "category.select.income", defaultValue: "Select Category")
        case .budgetExpense:
            return String(localized: "budget.category.select", defaultValue: "Select Budget Category")
        }
    }

    var placeholderTitle: String {
        switch self {
        case .transaction:
            return String(localized: "category.none", defaultValue: "No Category")
        case .budgetExpense:
            return String(localized: "budget.allCategories", defaultValue: "All Categories")
        }
    }

    var placeholderIcon: String {
        switch self {
        case .transaction:
            return "questionmark.circle"
        case .budgetExpense:
            return "square.grid.2x2.fill"
        }
    }
}

struct CategoryPickerView: View {
    @Binding var selectedCategory: Category?
    let mode: CategoryPickerMode
    
    @Query(sort: \Category.nameKey) private var allCategories: [Category]
    @State private var showCategorySheet = false
    
    private var categories: [Category] {
        allCategories.filter { $0.type == mode.categoryType }
    }
    
    init(selectedCategory: Binding<Category?>, transactionType: TransactionType) {
        self._selectedCategory = selectedCategory
        self.mode = .transaction(transactionType)
    }

    init(selectedCategory: Binding<Category?>, mode: CategoryPickerMode) {
        self._selectedCategory = selectedCategory
        self.mode = mode
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
                    PlaceholderCategoryIcon(size: .small)
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
        .sheet(isPresented: $showCategorySheet) {
            CategorySelectionSheet(
                selectedCategory: $selectedCategory,
                categories: categories,
                mode: mode
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
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 16) {
                    CategoryPlaceholderGridItem(
                        title: mode.placeholderTitle,
                        icon: mode.placeholderIcon,
                        isSelected: selectedCategory == nil
                    ) {
                        selectedCategory = nil
                        dismiss()
                    }

                    ForEach(categories) { category in
                        CategoryGridItem(
                            category: category,
                            isSelected: selectedCategory?.id == category.id
                        ) {
                            selectedCategory = category
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
        Picker(String(localized: "category.label", defaultValue: "Category"), selection: $selectedCategory) {
            Text(String(localized: "category.none", defaultValue: "None"))
                .tag(nil as Category?)
            
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
