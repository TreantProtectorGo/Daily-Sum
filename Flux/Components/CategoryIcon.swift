import SwiftUI
import UIKit

// MARK: - Category Icon

/// A circular icon with background representing a transaction category
struct CategoryIcon: View {
    let icon: String
    let color: Color
    let size: Size
    
    enum Size {
        case small   // 32pt
        case medium  // 40pt
        case large   // 56pt
        
        var dimension: CGFloat {
            switch self {
            case .small: 32
            case .medium: 40
            case .large: 56
            }
        }
        
        var iconFont: Font {
            switch self {
            case .small: .subheadline
            case .medium: .title3
            case .large: .title
            }
        }
    }
    
    init(icon: String, color: Color, size: Size = .medium) {
        self.icon = icon
        self.color = color
        self.size = size
    }
    
    /// Convenience init from a Category model
    init(category: Category, size: Size = .medium) {
        self.icon = category.icon
        self.color = category.color
        self.size = size
    }
    
    var body: some View {
        Image(systemName: SFSymbolCatalog.filledVariant(icon))
            .font(size.iconFont)
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(IconColorCircleStyle.glyphColor(for: color))
            .frame(width: size.dimension, height: size.dimension)
            .background(color)
            .clipShape(Circle())
    }
}

// MARK: - Placeholder Category Icon

/// A placeholder icon for uncategorized transactions
struct PlaceholderCategoryIcon: View {
    let size: CategoryIcon.Size
    
    init(size: CategoryIcon.Size = .medium) {
        self.size = size
    }
    
    var body: some View {
        Image(systemName: "tag")
            .font(size.iconFont)
            .foregroundStyle(.secondary)
            .frame(width: size.dimension, height: size.dimension)
            .background(Color.secondary.opacity(0.15))
            .clipShape(Circle())
    }
}

enum BudgetAllCategoriesPresentation {
    static let icon = CategoryPickerMode.budgetExpense.placeholderIcon
}

struct BudgetAllCategoriesIcon: View {
    let size: CategoryIcon.Size

    init(size: CategoryIcon.Size = .medium) {
        self.size = size
    }

    var body: some View {
        Image(systemName: BudgetAllCategoriesPresentation.icon)
            .font(size.iconFont)
            .foregroundStyle(.secondary)
            .frame(width: size.dimension, height: size.dimension)
            .background(Color.secondary.opacity(0.15))
            .clipShape(Circle())
    }
}

// MARK: - Account Type Icon

/// An icon representing an account type
struct AccountTypeIcon: View {
    let accountType: AccountType
    let size: CategoryIcon.Size
    
    init(accountType: AccountType, size: CategoryIcon.Size = .medium) {
        self.accountType = accountType
        self.size = size
    }
    
    var body: some View {
        IconColorCircle(
            icon: accountType.icon,
            color: accountType.color,
            size: size
        )
    }
}

struct AccountTypeDefinitionIcon: View {
    let definition: AccountTypeDefinition?
    let fallback: AccountType
    let size: CategoryIcon.Size

    init(
        definition: AccountTypeDefinition?,
        fallback: AccountType,
        size: CategoryIcon.Size = .medium
    ) {
        self.definition = definition
        self.fallback = fallback
        self.size = size
    }

    var body: some View {
        IconColorCircle(
            icon: definition?.icon ?? fallback.icon,
            color: definition?.color ?? fallback.color,
            size: size
        )
    }
}

// MARK: - AccountType Extension

extension AccountType {
    var icon: String {
        switch self {
        case .cash: "banknote"
        case .bank: "building.columns"
        case .creditCard: "creditcard"
        case .eWallet: "wallet.bifold"
        case .investment: "chart.line.uptrend.xyaxis"
        }
    }
    
    var color: Color {
        switch self {
        case .cash: AppColors.Account.cash
        case .bank: AppColors.Account.bank
        case .creditCard: AppColors.Account.creditCard
        case .eWallet: AppColors.Account.eWallet
        case .investment: AppColors.Account.investment
        }
    }
}

// MARK: - Preview

#Preview("Category Icons") {
    VStack(spacing: 20) {
        // Different sizes
        HStack(spacing: 16) {
            CategoryIcon(icon: "cart.fill", color: .orange, size: .small)
            CategoryIcon(icon: "cart.fill", color: .orange, size: .medium)
            CategoryIcon(icon: "cart.fill", color: .orange, size: .large)
        }
        
        // Different categories
        HStack(spacing: 12) {
            CategoryIcon(icon: "fork.knife", color: .red)
            CategoryIcon(icon: "car.fill", color: .blue)
            CategoryIcon(icon: "house.fill", color: .green)
            CategoryIcon(icon: "gift.fill", color: .purple)
            PlaceholderCategoryIcon()
        }
        
        Divider()
        
        // Account types
        Text("Account Types")
            .font(.headline)
        
        HStack(spacing: 12) {
            AccountTypeIcon(accountType: .cash)
            AccountTypeIcon(accountType: .bank)
            AccountTypeIcon(accountType: .creditCard)
            AccountTypeIcon(accountType: .eWallet)
            AccountTypeIcon(accountType: .investment)
        }
    }
    .padding()
}
