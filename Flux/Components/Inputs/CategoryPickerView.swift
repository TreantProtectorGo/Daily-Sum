import SwiftUI
import SwiftData

struct CategoryPickerView: View {
    @Binding var selectedCategory: Category?
    let transactionType: TransactionType
    
    // Fetch ALL categories - filtering in predicate doesn't work with enum types
    @Query(sort: \Category.nameKey) private var allCategories: [Category]
    @State private var isExpanded = false
    
    // Filter categories by type in computed property (SwiftData workaround)
    private var categories: [Category] {
        allCategories.filter { $0.type == transactionType }
    }
    
    init(selectedCategory: Binding<Category?>, transactionType: TransactionType) {
        self._selectedCategory = selectedCategory
        self.transactionType = transactionType
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    isExpanded.toggle()
                }
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
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding()
                .glassBackground(cornerRadius: 12, isInteractive: true)
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                categoryGrid
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    private var categoryGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
            ForEach(categories) { category in
                CategoryGridItem(
                    category: category,
                    isSelected: selectedCategory?.id == category.id
                ) {
                    selectedCategory = category
                    withAnimation(.spring(duration: 0.3)) {
                        isExpanded = false
                    }
                }
            }
        }
        .padding()
        .glassBackground(cornerRadius: 16)
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
                                .stroke(category.color, lineWidth: 2)
                                .padding(-4)
                        }
                    }
                
                Text(category.displayName)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

struct InlineCategoryPicker: View {
    @Binding var selectedCategory: Category?
    let transactionType: TransactionType
    
    // Fetch ALL categories - filtering in predicate doesn't work with enum types
    @Query(sort: \Category.nameKey) private var allCategories: [Category]
    
    // Filter categories by type in computed property (SwiftData workaround)
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
