import SwiftUI
import SwiftData

struct CategoryPickerView: View {
    @Binding var selectedCategory: Category?
    let transactionType: TransactionType
    
    @Query(sort: \Category.nameKey) private var allCategories: [Category]
    @State private var showCategorySheet = false
    
    private var categories: [Category] {
        allCategories.filter { $0.type == transactionType }
    }
    
    init(selectedCategory: Binding<Category?>, transactionType: TransactionType) {
        self._selectedCategory = selectedCategory
        self.transactionType = transactionType
    }
    
    var body: some View {
        Button {
            showCategorySheet = true
        } label: {
            HStack {
                if let category = selectedCategory {
                    CategoryIcon(category: category, size: .small)
                    Text(category.displayName)
                        .font(.headline)
                } else {
                    PlaceholderCategoryIcon(size: .small)
                    Text(String(localized: "category.select", defaultValue: "Select Category"))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .glassBackground(cornerRadius: 12, isInteractive: true)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("transaction.categoryPicker.trigger")
        .sheet(isPresented: $showCategorySheet) {
            CategorySelectionSheet(
                selectedCategory: $selectedCategory,
                categories: categories,
                transactionType: transactionType
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

private struct CategorySelectionSheet: View {
    @Binding var selectedCategory: Category?
    let categories: [Category]
    let transactionType: TransactionType
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 16) {
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
            .navigationTitle(transactionType == .expense
                ? String(localized: "category.select.expense", defaultValue: "Select Category")
                : String(localized: "category.select.income", defaultValue: "Select Category"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.black)
                    }
                    .accessibilityLabel(String(localized: "action.cancel", defaultValue: "Cancel"))
                }
                
                if selectedCategory != nil {
                    ToolbarItem(placement: .destructiveAction) {
                        Button(String(localized: "action.clear", defaultValue: "Clear")) {
                            selectedCategory = nil
                            dismiss()
                        }
                        .foregroundStyle(.red)
                    }
                }
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
