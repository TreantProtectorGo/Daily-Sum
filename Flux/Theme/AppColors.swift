import SwiftUI

// MARK: - App Colors

/// Centralized color definitions for the Flux app
enum AppColors {
    // MARK: - Semantic Colors
    
    /// Primary Flux brand color, backed by the AccentColor asset for platform tinting.
    static let primary = Color.accentColor

    /// Secondary brand accent for selected states, chart emphasis, and subtle highlights.
    static let secondaryAccent = Color(red: 0.0, green: 0.58, blue: 0.52)

    /// Warm counterpoint to the teal brand color for moments that need extra emphasis.
    static let brandCoral = Color(red: 0.93, green: 0.33, blue: 0.26)

    /// Quieter interactive color for default links, picker values, and selected navigation.
    static var interactiveText: Color {
        #if os(iOS)
        Color(UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                UIColor(red: 0.23, green: 0.62, blue: 0.60, alpha: 1.0)
            } else {
                UIColor(red: 0.00, green: 0.40, blue: 0.38, alpha: 1.0)
            }
        })
        #else
        secondaryAccent
        #endif
    }

    /// Selected tab color; intentionally quieter than primary actions.
    static var selectedNavigation: Color {
        #if os(iOS)
        Color(UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                UIColor(red: 0.25, green: 0.70, blue: 0.66, alpha: 1.0)
            } else {
                UIColor(red: 0.00, green: 0.45, blue: 0.43, alpha: 1.0)
            }
        })
        #else
        secondaryAccent
        #endif
    }

    /// Muted teal for informational icons that should not read as primary actions.
    static var mutedDataIcon: Color {
        #if os(iOS)
        Color(UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                UIColor(red: 0.22, green: 0.53, blue: 0.51, alpha: 1.0)
            } else {
                UIColor(red: 0.00, green: 0.42, blue: 0.39, alpha: 1.0)
            }
        })
        #else
        secondaryAccent
        #endif
    }

    /// Quiet brand-tinted surface for non-critical highlighted UI.
    static let brandSurfaceTint = Color.accentColor.opacity(0.08)
    
    /// Background color for main content areas
    static var background: Color {
        #if os(iOS)
        Color(UIColor.systemBackground)
        #else
        Color.clear
        #endif
    }
    
    /// Secondary background for grouped content
    static var secondaryBackground: Color {
        #if os(iOS)
        Color(UIColor.secondarySystemBackground)
        #else
        Color.gray.opacity(0.1)
        #endif
    }
    
    /// Tertiary background for nested content
    static var tertiaryBackground: Color {
        #if os(iOS)
        Color(UIColor.tertiarySystemBackground)
        #else
        Color.gray.opacity(0.2)
        #endif
    }
    
    // MARK: - Transaction Type Colors
    
    /// Color for income transactions
    static let income = Color.green
    
    /// Color for expense transactions
    static let expense = Color.red
    
    /// Color for transfer transactions
    static let transfer = secondaryAccent
    
    // MARK: - Category Colors
    
    /// Default category colors available for selection
    static let categoryColors: [Color] = [
        Color(red: 0.93, green: 0.33, blue: 0.26),
        Color(red: 0.95, green: 0.58, blue: 0.16),
        Color(red: 0.86, green: 0.72, blue: 0.23),
        Color(red: 0.16, green: 0.65, blue: 0.39),
        Color(red: 0.0, green: 0.58, blue: 0.52),
        Color(red: 0.05, green: 0.50, blue: 0.66),
        Color(red: 0.18, green: 0.42, blue: 0.78),
        Color(red: 0.39, green: 0.36, blue: 0.78),
        Color(red: 0.62, green: 0.32, blue: 0.70),
        Color(red: 0.78, green: 0.29, blue: 0.49),
        Color(red: 0.55, green: 0.38, blue: 0.24),
        Color(red: 0.35, green: 0.42, blue: 0.45)
    ]
    
    // MARK: - Account Type Colors
    
    /// Color for cash accounts
    static let accountCash = Color.green
    
    /// Color for bank accounts
    static let accountBank = primary
    
    /// Color for credit card accounts
    static let accountCreditCard = Color.orange
    
    /// Color for investment accounts
    static let accountInvestment = Color.purple
    
    /// Color for other account types
    static let accountOther = Color(red: 0.35, green: 0.42, blue: 0.45)
    
    // MARK: - UI Element Colors
    
    /// Color for progress indicators under 50%
    static let progressLow = Color.green
    
    /// Color for progress indicators 50-80%
    static let progressMedium = Color.yellow
    
    /// Color for progress indicators over 80%
    static let progressHigh = Color.orange
    
    /// Color for over-budget indicators
    static let progressOverBudget = Color.red
    
    // MARK: - Glass Effect Colors
    
    /// Tint color for glass effects (subtle)
    static let glassTint = brandSurfaceTint
    
    /// Border color for glass cards
    static let glassBorder = Color.accentColor.opacity(0.18)
}

// MARK: - Budget Progress Color

extension AppColors {
    static func budgetProgressColor(for progress: Double) -> Color {
        switch progress {
        case ..<0.5:
            return progressLow
        case 0.5..<0.8:
            return progressMedium
        case 0.8..<1.0:
            return progressHigh
        default:
            return progressOverBudget
        }
    }
    
    static let budgetSafe = progressLow
    static let budgetWarning = progressHigh
    static let budgetDanger = progressOverBudget
}

// MARK: - Preview

#Preview("App Colors") {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            // Transaction Colors
            Section("Transaction Colors") {
                HStack(spacing: 12) {
                    colorSwatch(AppColors.income, label: "Income")
                    colorSwatch(AppColors.expense, label: "Expense")
                    colorSwatch(AppColors.transfer, label: "Transfer")
                }
            }
            
            // Category Colors
            Section("Category Colors") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 8) {
                    ForEach(AppColors.categoryColors, id: \.self) { color in
                        Circle()
                            .fill(color)
                            .frame(width: 40, height: 40)
                    }
                }
            }
            
            // Progress Colors
            Section("Budget Progress") {
                HStack(spacing: 12) {
                    colorSwatch(AppColors.progressLow, label: "<50%")
                    colorSwatch(AppColors.progressMedium, label: "50-80%")
                    colorSwatch(AppColors.progressHigh, label: ">80%")
                    colorSwatch(AppColors.progressOverBudget, label: "Over")
                }
            }
        }
        .padding()
    }
}

@ViewBuilder
private func colorSwatch(_ color: Color, label: String) -> some View {
    VStack(spacing: 4) {
        RoundedRectangle(cornerRadius: 8)
            .fill(color)
            .frame(width: 50, height: 50)
        Text(label)
            .font(.caption2)
    }
}
