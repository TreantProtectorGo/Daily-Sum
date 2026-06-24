import SwiftUI

// MARK: - App Colors

/// Centralized color definitions for the Flux app.
///
/// Token rules:
/// - `Brand` is for product identity only.
/// - `UI` is for reusable interface roles such as navigation, links, sections, and surfaces.
/// - `Finance` is for money movement semantics: income, expense, transfer.
/// - `Budget` is for budget health/status only.
/// - `Account` and `Category` are domain identity colors, not status colors.
enum AppColors {
    // MARK: - Brand Tokens

    enum Brand {
        /// Primary Flux brand color, backed by the AccentColor asset for platform tinting.
        static let primary = Color.accentColor

        /// Foreground color for text and icons placed on top of the primary brand color.
        static var onPrimary: Color {
            #if os(iOS)
            Color(UIColor { traits in
                if traits.userInterfaceStyle == .dark {
                    UIColor.black
                } else {
                    UIColor.white
                }
            })
            #else
            Color.white
            #endif
        }

        /// Secondary teal brand accent. Use through a UI/domain role when possible.
        static let teal = Color(red: 0.0, green: 0.58, blue: 0.52)

        /// Warm counterpoint to the teal brand color. Use through a UI/domain role when possible.
        static let coral = Color(red: 0.93, green: 0.33, blue: 0.26)

        /// Quiet brand-tinted surface for non-critical highlighted UI.
        static let surfaceTint = Color.accentColor.opacity(0.08)
    }

    // MARK: - UI Role Tokens

    enum UI {
        /// Accent for section markers and informational section icons.
        static let sectionAccent = Brand.teal

        /// Default link and picker value color.
        static var interactiveText: Color {
            warmInteractive
        }

        /// Selected tab/navigation color; intentionally quieter than primary actions.
        static var selectedNavigation: Color {
            warmInteractive
        }

        /// Informational icons that should not read as primary actions or budget status.
        static var dataIcon: Color {
            #if os(iOS)
            Color(UIColor { traits in
                if traits.userInterfaceStyle == .dark {
                    UIColor(red: 0.79, green: 0.48, blue: 0.36, alpha: 1.0)
                } else {
                    UIColor(red: 0.56, green: 0.25, blue: 0.16, alpha: 1.0)
                }
            })
            #else
            Brand.primary
            #endif
        }

        /// Background color for main content areas.
        static var background: Color {
            #if os(iOS)
            Color(UIColor.systemBackground)
            #else
            Color.clear
            #endif
        }

        /// Secondary background for grouped content.
        static var secondaryBackground: Color {
            #if os(iOS)
            Color(UIColor.secondarySystemBackground)
            #else
            Color.gray.opacity(0.1)
            #endif
        }

        /// Tertiary background for nested content.
        static var tertiaryBackground: Color {
            #if os(iOS)
            Color(UIColor.tertiarySystemBackground)
            #else
            Color.gray.opacity(0.2)
            #endif
        }

        /// Tint color for glass effects.
        static let glassTint = Brand.surfaceTint

        /// Border color for glass cards.
        static let glassBorder = Color.accentColor.opacity(0.18)

        private static var warmInteractive: Color {
            #if os(iOS)
            Color(UIColor { traits in
                if traits.userInterfaceStyle == .dark {
                    UIColor(red: 0.85, green: 0.51, blue: 0.38, alpha: 1.0)
                } else {
                    UIColor(red: 0.66, green: 0.30, blue: 0.19, alpha: 1.0)
                }
            })
            #else
            Brand.primary
            #endif
        }
    }

    // MARK: - Finance Tokens

    enum Finance {
        /// Positive money movement.
        static let income = Color.green

        /// Negative money movement.
        static let expense = Color.red

        /// Neutral money movement between accounts.
        static let transfer = Brand.teal
    }

    // MARK: - Budget Status Tokens

    enum Budget {
        /// Budget usage under 50%.
        static let safe = Color.green

        /// Budget usage from 50% up to 80%.
        static let moderate = Color.yellow

        /// Budget usage from 80% up to 100%.
        static let warning = Color.orange

        /// Budget usage at or over 100%.
        static let danger = Color.red

        static func progressColor(for progress: Double) -> Color {
            switch progress {
            case ..<0.5:
                return safe
            case 0.5..<0.8:
                return moderate
            case 0.8..<1.0:
                return warning
            default:
                return danger
            }
        }
    }

    // MARK: - Account Identity Tokens

    enum Account {
        static let cash = Color.green
        static let bank = Brand.primary
        static let creditCard = Color.orange
        static let eWallet = Color.teal
        static let investment = Color.purple
        static let other = Color(red: 0.35, green: 0.42, blue: 0.45)
    }

    // MARK: - Category Identity Tokens

    enum Category {
        /// Default category colors available for selection.
        static let palette: [Color] = [
            Brand.coral,
            Color(red: 0.95, green: 0.58, blue: 0.16),
            Color(red: 0.86, green: 0.72, blue: 0.23),
            Color(red: 0.16, green: 0.65, blue: 0.39),
            Brand.teal,
            Color(red: 0.05, green: 0.50, blue: 0.66),
            Color(red: 0.18, green: 0.42, blue: 0.78),
            Color(red: 0.39, green: 0.36, blue: 0.78),
            Color(red: 0.62, green: 0.32, blue: 0.70),
            Color(red: 0.78, green: 0.29, blue: 0.49),
            Color(red: 0.55, green: 0.38, blue: 0.24),
            Account.other
        ]
    }

    // MARK: - Compatibility Aliases

    /// Prefer `AppColors.Brand.primary` in new code.
    /// Primary Flux brand color, backed by the AccentColor asset for platform tinting.
    static let primary = Brand.primary

    /// Prefer `AppColors.Brand.onPrimary` in new code.
    /// Foreground color for text and icons placed on top of the primary brand color.
    static let onPrimary = Brand.onPrimary

    /// Prefer a role token such as `AppColors.UI.sectionAccent` or `AppColors.Finance.transfer`.
    static let secondaryAccent = Brand.teal

    /// Prefer `AppColors.UI.sectionAccent` in new code.
    /// Accent for section markers and informational section icons.
    static let sectionAccent = UI.sectionAccent

    /// Prefer a role token such as `AppColors.Category.palette`.
    /// Warm counterpoint to the teal brand color for moments that need extra emphasis.
    static let brandCoral = Brand.coral

    /// Prefer `AppColors.UI.interactiveText` in new code.
    /// Quieter interactive color for default links, picker values, and selected navigation.
    static let interactiveText = UI.interactiveText

    /// Prefer `AppColors.UI.selectedNavigation` in new code.
    /// Selected tab color; intentionally quieter than primary actions.
    static let selectedNavigation = UI.selectedNavigation

    /// Prefer `AppColors.UI.dataIcon` in new code.
    static let mutedDataIcon = UI.dataIcon

    /// Prefer `AppColors.Brand.surfaceTint` or a UI role token in new code.
    /// Quiet brand-tinted surface for non-critical highlighted UI.
    static let brandSurfaceTint = Brand.surfaceTint
    
    /// Prefer `AppColors.UI.background` in new code.
    /// Background color for main content areas
    static let background = UI.background
    
    /// Prefer `AppColors.UI.secondaryBackground` in new code.
    /// Secondary background for grouped content
    static let secondaryBackground = UI.secondaryBackground
    
    /// Prefer `AppColors.UI.tertiaryBackground` in new code.
    /// Tertiary background for nested content
    static let tertiaryBackground = UI.tertiaryBackground
    
    // MARK: - Transaction Type Colors
    
    /// Prefer `AppColors.Finance.income` in new code.
    /// Color for income transactions
    static let income = Finance.income
    
    /// Prefer `AppColors.Finance.expense` in new code.
    /// Color for expense transactions
    static let expense = Finance.expense
    
    /// Prefer `AppColors.Finance.transfer` in new code.
    /// Color for transfer transactions
    static let transfer = Finance.transfer
    
    // MARK: - Category Colors
    
    /// Prefer `AppColors.Category.palette` in new code.
    /// Default category colors available for selection
    static let categoryColors = Category.palette
    
    // MARK: - Account Type Colors
    
    /// Prefer `AppColors.Account.cash` in new code.
    /// Color for cash accounts
    static let accountCash = Account.cash
    
    /// Prefer `AppColors.Account.bank` in new code.
    /// Color for bank accounts
    static let accountBank = Account.bank
    
    /// Prefer `AppColors.Account.creditCard` in new code.
    /// Color for credit card accounts
    static let accountCreditCard = Account.creditCard

    /// Prefer `AppColors.Account.eWallet` in new code.
    /// Color for e-wallet accounts
    static let accountEWallet = Account.eWallet
    
    /// Prefer `AppColors.Account.investment` in new code.
    /// Color for investment accounts
    static let accountInvestment = Account.investment
    
    /// Prefer `AppColors.Account.other` in new code.
    /// Color for other account types
    static let accountOther = Account.other
    
    // MARK: - UI Element Colors
    
    /// Prefer `AppColors.Budget.safe` in new code.
    /// Color for progress indicators under 50%
    static let progressLow = Budget.safe
    
    /// Prefer `AppColors.Budget.moderate` in new code.
    /// Color for progress indicators 50-80%
    static let progressMedium = Budget.moderate
    
    /// Prefer `AppColors.Budget.warning` in new code.
    /// Color for progress indicators over 80%
    static let progressHigh = Budget.warning
    
    /// Prefer `AppColors.Budget.danger` in new code.
    /// Color for over-budget indicators
    static let progressOverBudget = Budget.danger
    
    // MARK: - Glass Effect Colors
    
    /// Prefer `AppColors.UI.glassTint` in new code.
    /// Tint color for glass effects (subtle)
    static let glassTint = UI.glassTint
    
    /// Prefer `AppColors.UI.glassBorder` in new code.
    /// Border color for glass cards
    static let glassBorder = UI.glassBorder
}

// MARK: - Budget Progress Color

extension AppColors {
    static func budgetProgressColor(for progress: Double) -> Color {
        Budget.progressColor(for: progress)
    }
    
    static let budgetSafe = Budget.safe
    static let budgetWarning = Budget.warning
    static let budgetDanger = Budget.danger
}

// MARK: - Preview

#Preview("App Colors") {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            // Transaction Colors
            Section("Transaction Colors") {
                HStack(spacing: 12) {
                    colorSwatch(AppColors.Finance.income, label: "Income")
                    colorSwatch(AppColors.Finance.expense, label: "Expense")
                    colorSwatch(AppColors.Finance.transfer, label: "Transfer")
                }
            }
            
            // Category Colors
            Section("Category Colors") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 8) {
                    ForEach(AppColors.Category.palette, id: \.self) { color in
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
