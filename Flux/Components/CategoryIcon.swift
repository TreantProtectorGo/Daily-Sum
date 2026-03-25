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
        Image(systemName: icon)
            .font(size.iconFont)
            .foregroundStyle(iconColor)
            .frame(width: size.dimension, height: size.dimension)
            .background(color.opacity(0.15))
            .overlay {
                Circle()
                    .stroke(iconColor.opacity(0.2), lineWidth: 1)
            }
            .clipShape(Circle())
    }

    private var iconColor: Color {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return color
        }

        let luminance = (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
        guard luminance > 0.7 else { return color }

        let factor: CGFloat = 0.55
        let darkened = UIColor(
            red: red * factor,
            green: green * factor,
            blue: blue * factor,
            alpha: alpha
        )
        return Color(uiColor: darkened)
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
        Image(systemName: accountType.icon)
            .font(size.iconFont)
            .foregroundStyle(accountType.color)
            .frame(width: size.dimension, height: size.dimension)
            .background(accountType.color.opacity(0.15))
            .clipShape(Circle())
    }
}

// MARK: - AccountType Extension

extension AccountType {
    var icon: String {
        switch self {
        case .cash: "banknote"
        case .bank: "building.columns"
        case .creditCard: "creditcard"
        case .investment: "chart.line.uptrend.xyaxis"
        }
    }
    
    var color: Color {
        switch self {
        case .cash: AppColors.accountCash
        case .bank: AppColors.accountBank
        case .creditCard: AppColors.accountCreditCard
        case .investment: AppColors.accountInvestment
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
            AccountTypeIcon(accountType: .investment)
        }
    }
    .padding()
}
