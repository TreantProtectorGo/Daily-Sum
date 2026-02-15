import SwiftUI

// MARK: - Empty State View

/// A placeholder view for empty content states
struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        title: String,
        message: String,
        systemImage: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            // Text
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Action button
            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text(actionTitle)
                    }
                }
                .buttonStyle(.fluxGlassProminent)
                .padding(.top, 8)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Glass Empty State

/// A glass-styled empty state for dashboard sections
struct GlassEmptyState: View {
    let title: String
    let message: String
    let systemImage: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        title: String,
        message: String,
        systemImage: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        GlassCard {
            EmptyStateView(
                title: title,
                message: message,
                systemImage: systemImage,
                actionTitle: actionTitle,
                action: action
            )
        }
    }
}

// MARK: - Predefined Empty States

extension EmptyStateView {
    /// Empty state for no transactions
    static func noTransactions(action: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            title: AppLocalization.string("empty.transactions.title", defaultValue: "No Transactions"),
            message: AppLocalization.string("empty.transactions.message", defaultValue: "Start tracking your finances by adding your first transaction."),
            systemImage: "tray",
            actionTitle: AppLocalization.string("empty.transactions.action", defaultValue: "Add Transaction"),
            action: action
        )
    }
    
    /// Empty state for no accounts
    static func noAccounts(action: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            title: AppLocalization.string("empty.accounts.title", defaultValue: "No Accounts"),
            message: AppLocalization.string("empty.accounts.message", defaultValue: "Add your accounts to start managing your finances."),
            systemImage: "building.columns",
            actionTitle: AppLocalization.string("empty.accounts.action", defaultValue: "Add Account"),
            action: action
        )
    }
    
    /// Empty state for no budgets
    static func noBudgets(action: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            title: AppLocalization.string("empty.budgets.title", defaultValue: "No Budgets"),
            message: AppLocalization.string("empty.budgets.message", defaultValue: "Create budgets to track your spending goals."),
            systemImage: "chart.pie",
            actionTitle: AppLocalization.string("empty.budgets.action", defaultValue: "Create Budget"),
            action: action
        )
    }
    
    /// Empty state for no data in a time period
    static func noDataForPeriod() -> EmptyStateView {
        EmptyStateView(
            title: AppLocalization.string("empty.period.title", defaultValue: "No Data"),
            message: AppLocalization.string("empty.period.message", defaultValue: "There's no data for the selected time period."),
            systemImage: "calendar.badge.exclamationmark"
        )
    }
    
    /// Empty state for search results
    static func noSearchResults(query: String) -> EmptyStateView {
        EmptyStateView(
            title: AppLocalization.string("empty.search.title", defaultValue: "No Results"),
            message: AppLocalization.string("empty.search.message", defaultValue: "No results found for your search."),
            systemImage: "magnifyingglass"
        )
    }
}

// MARK: - Preview

#Preview("Empty States") {
    ScrollView {
        VStack(spacing: 24) {
            // Basic empty state
            EmptyStateView(
                title: "Nothing Here",
                message: "This section is empty",
                systemImage: "tray"
            )
            
            Divider()
            
            // With action
            EmptyStateView.noTransactions { }
            
            Divider()
            
            // Glass styled
            ZStack {
                Color.blue.opacity(0.3)
                GlassEmptyState(
                    title: "No Budgets",
                    message: "Create your first budget to start tracking expenses",
                    systemImage: "chart.pie",
                    actionTitle: "Create Budget"
                ) { }
                .padding()
            }
            .frame(height: 250)
            
            // Search results
            EmptyStateView.noSearchResults(query: "coffee")
        }
        .padding()
    }
}
