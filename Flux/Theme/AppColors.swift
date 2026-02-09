import SwiftUI

// MARK: - App Colors

/// Centralized color definitions for the Flux app
enum AppColors {
    // MARK: - Semantic Colors
    
    /// Primary brand color
    static let primary = Color.accentColor
    
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
    static let transfer = Color.blue
    
    // MARK: - Category Colors
    
    /// Default category colors available for selection
    static let categoryColors: [Color] = [
        .red,
        .orange,
        .yellow,
        .green,
        .mint,
        .teal,
        .cyan,
        .blue,
        .indigo,
        .purple,
        .pink,
        .brown
    ]
    
    // MARK: - Account Type Colors
    
    /// Color for cash accounts
    static let accountCash = Color.green
    
    /// Color for bank accounts
    static let accountBank = Color.blue
    
    /// Color for credit card accounts
    static let accountCreditCard = Color.orange
    
    /// Color for investment accounts
    static let accountInvestment = Color.purple
    
    /// Color for other account types
    static let accountOther = Color.gray
    
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
    static let glassTint = Color.white.opacity(0.1)
    
    /// Border color for glass cards
    static let glassBorder = Color.white.opacity(0.2)
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
