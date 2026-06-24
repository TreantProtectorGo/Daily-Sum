import SwiftUI
import SwiftData

// MARK: - Budget Progress View

struct BudgetProgressView: View {
    let budget: Budget
    let status: BudgetService.BudgetStatus?
    let showsCategoryHeader: Bool
    let isCompact: Bool
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.regionalSettings) private var regionalSettings

    init(
        budget: Budget,
        status: BudgetService.BudgetStatus? = nil,
        showsCategoryHeader: Bool = true,
        isCompact: Bool = false
    ) {
        self.budget = budget
        self.status = status
        self.showsCategoryHeader = showsCategoryHeader
        self.isCompact = isCompact
    }
    
    private var spentAmount: Decimal {
        status?.spent ?? budget.spentAmount(in: modelContext)
    }
    
    private var progress: Double {
        NSDecimalNumber(decimal: status?.percentage ?? budget.usagePercentage(in: modelContext)).doubleValue
    }
    
    private var remainingAmount: Decimal {
        status?.remaining ?? budget.remainingAmount(in: modelContext)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 6 : 8) {
            // Header with amounts
            HStack {
                if showsCategoryHeader {
                    if let category = budget.category {
                        CategoryIcon(category: category, size: .small)
                        Text(category.displayName)
                            .font(.headline)
                    } else {
                        BudgetAllCategoriesIcon(size: .small)
                        Text(AppLocalization.string("budget.allCategories", defaultValue: "All Categories"))
                            .font(.headline)
                    }
                }
                
                Spacer()
                
                // Spent / Budget
                HStack(spacing: 4) {
                    Text(CurrencyFormatter.shared.format(spentAmount, currencyCode: budget.currencyCode))
                        .foregroundStyle(progressColor)
                    Text("/")
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.shared.format(budget.limitAmount, currencyCode: budget.currencyCode))
                        .foregroundStyle(.secondary)
                }
                .font(isCompact ? .footnote : .subheadline)
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressColor)
                        .frame(width: min(geometry.size.width * CGFloat(progress), geometry.size.width))
                }
            }
            .frame(height: isCompact ? 6 : 8)
            
            // Status text
            HStack {
                Text(statusText)
                    .font(isCompact ? .caption2 : .caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(AppLocalization.string("budget.remaining", defaultValue: "Remaining: ") + 
                     CurrencyFormatter.shared.format(remainingAmount, currencyCode: budget.currencyCode))
                    .font(isCompact ? .caption2 : .caption)
                    .foregroundStyle(remainingAmount >= 0 ? .secondary : regionalSettings.lossColor)
            }
        }
    }
    
    private var progressColor: Color {
        AppColors.Budget.progressColor(for: progress)
    }
    
    private var statusText: String {
        let percentage = Int(progress * 100)
        if progress >= 1.0 {
            return AppLocalization.formatted(
                "budget.status.overBudget",
                defaultValue: "%lld%% - Over Budget!",
                Int64(percentage)
            )
        } else if progress >= 0.8 {
            return AppLocalization.formatted(
                "budget.status.nearLimit",
                defaultValue: "%lld%% - Near Limit",
                Int64(percentage)
            )
        } else {
            return AppLocalization.formatted(
                "budget.status.onTrack",
                defaultValue: "%lld%% - On Track",
                Int64(percentage)
            )
        }
    }
}

// MARK: - Compact Budget Progress

/// A compact version of the budget progress for list display
struct CompactBudgetProgress: View {
    let spent: Decimal
    let total: Decimal
    let currencyCode: String
    
    var progress: Double {
        guard total > 0 else { return 0 }
        return NSDecimalNumber(decimal: spent / total).doubleValue
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Mini progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColors.Budget.progressColor(for: progress))
                        .frame(width: min(geometry.size.width * CGFloat(progress), geometry.size.width))
                }
            }
            .frame(width: 60, height: 4)
            
            // Percentage
            Text("\(Int(progress * 100))%")
                .font(.caption)
                .foregroundStyle(AppColors.Budget.progressColor(for: progress))
                .frame(width: 40, alignment: .trailing)
        }
    }
}

// MARK: - Budget Card

/// A glass card displaying budget information
struct BudgetCard: View {
    let budget: Budget
    let onTap: (() -> Void)?
    
    init(budget: Budget, onTap: (() -> Void)? = nil) {
        self.budget = budget
        self.onTap = onTap
    }
    
    var body: some View {
        Button {
            onTap?()
        } label: {
            BudgetProgressView(budget: budget)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassBackground(cornerRadius: 16, isInteractive: true, style: .row)
        .glassSurfaceHierarchy(style: .row, cornerRadius: 16)
    }
}

// MARK: - Preview

#Preview("Compact Budget Progress") {
    VStack(spacing: 16) {
        HStack {
            Text("Food & Dining")
            Spacer()
            CompactBudgetProgress(spent: 450, total: 600, currencyCode: "USD")
        }
        
        HStack {
            Text("Transport")
            Spacer()
            CompactBudgetProgress(spent: 180, total: 200, currencyCode: "USD")
        }
        
        HStack {
            Text("Entertainment")
            Spacer()
            CompactBudgetProgress(spent: 50, total: 300, currencyCode: "USD")
        }
    }
    .padding()
}
