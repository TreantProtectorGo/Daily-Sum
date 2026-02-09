import SwiftUI
import SwiftData

// MARK: - Budget List View

/// Full budget list with progress tracking
struct BudgetListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: BudgetListViewModel?
    
    @State private var showAddBudget = false
    @State private var selectedBudget: Budget?
    
    var body: some View {
        Group {
            if let viewModel {
                budgetContent(viewModel: viewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(String(localized: "budgets.title", defaultValue: "Budgets"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddBudget = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = BudgetListViewModel(modelContext: modelContext)
            }
            await viewModel?.loadBudgets()
        }
        .refreshable {
            await viewModel?.loadBudgets()
        }
        .sheet(isPresented: $showAddBudget) {
            BudgetEntrySheet(onSave: {
                Task { await viewModel?.loadBudgets() }
            })
        }
        .sheet(item: $selectedBudget) { budget in
            BudgetEntrySheet(budget: budget, onSave: {
                Task { await viewModel?.loadBudgets() }
            })
        }
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private func budgetContent(viewModel: BudgetListViewModel) -> some View {
        if viewModel.budgets.isEmpty {
            emptyState
        } else {
            budgetList(viewModel: viewModel)
        }
    }
    
    @ViewBuilder
    private func budgetList(viewModel: BudgetListViewModel) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summary Card
                summaryCard(viewModel: viewModel)
                
                // Active Budgets Section
                if !viewModel.activeBudgets.isEmpty {
                    budgetSection(
                        title: String(localized: "budgets.active", defaultValue: "Active Budgets"),
                        budgets: viewModel.activeBudgets,
                        viewModel: viewModel
                    )
                }
                
                // Inactive Budgets Section
                if !viewModel.inactiveBudgets.isEmpty {
                    budgetSection(
                        title: String(localized: "budgets.inactive", defaultValue: "Inactive Budgets"),
                        budgets: viewModel.inactiveBudgets,
                        viewModel: viewModel
                    )
                }
            }
            .padding()
        }
    }
    
    // MARK: - Summary Card
    
    @ViewBuilder
    private func summaryCard(viewModel: BudgetListViewModel) -> some View {
        GlassCard(cornerRadius: 20, padding: 20) {
            VStack(spacing: 16) {
                // Overall progress
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "budgets.totalSpent", defaultValue: "Total Spent"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Text(CurrencyFormatter.shared.format(viewModel.totalSpent, currencyCode: SupportedCurrency.defaultFromLocale.rawValue))
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(String(localized: "budgets.totalBudget", defaultValue: "Total Budget"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Text(CurrencyFormatter.shared.format(viewModel.totalBudgeted, currencyCode: SupportedCurrency.defaultFromLocale.rawValue))
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                }
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.2))
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppColors.budgetProgressColor(for: viewModel.overallProgress))
                            .frame(width: min(geometry.size.width * CGFloat(viewModel.overallProgress), geometry.size.width))
                    }
                }
                .frame(height: 12)
                
                // Stats row
                HStack {
                    statBadge(
                        value: viewModel.budgetsOverLimit,
                        label: String(localized: "budgets.overLimit", defaultValue: "Over Limit"),
                        color: AppColors.budgetDanger
                    )
                    
                    Spacer()
                    
                    statBadge(
                        value: viewModel.budgetsNearLimit,
                        label: String(localized: "budgets.nearLimit", defaultValue: "Near Limit"),
                        color: AppColors.budgetWarning
                    )
                    
                    Spacer()
                    
                    statBadge(
                        value: viewModel.activeBudgets.count - viewModel.budgetsOverLimit - viewModel.budgetsNearLimit,
                        label: String(localized: "budgets.onTrack", defaultValue: "On Track"),
                        color: AppColors.budgetSafe
                    )
                }
            }
        }
    }
    
    private func statBadge(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Budget Section
    
    @ViewBuilder
    private func budgetSection(title: String, budgets: [Budget], viewModel: BudgetListViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            
            ForEach(budgets) { budget in
                BudgetRowCard(
                    budget: budget,
                    onTap: { selectedBudget = budget },
                    onToggleActive: {
                        Task { try? await viewModel.toggleBudgetActive(budget) }
                    },
                    onDelete: {
                        Task { try? await viewModel.deleteBudget(budget) }
                    }
                )
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label(
                String(localized: "empty.budgets.title", defaultValue: "No Budgets"),
                systemImage: "chart.pie"
            )
        } description: {
            Text(String(localized: "empty.budgets.message", defaultValue: "Create budgets to track your spending goals."))
        } actions: {
            Button(String(localized: "empty.budgets.action", defaultValue: "Create Budget")) {
                showAddBudget = true
            }
            .buttonStyle(.fluxGlassProminent)
        }
    }
}

// MARK: - Budget Row Card

struct BudgetRowCard: View {
    let budget: Budget
    let onTap: () -> Void
    let onToggleActive: () -> Void
    let onDelete: () -> Void
    
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    if let category = budget.category {
                        CategoryIcon(category: category, size: .small)
                        Text(category.displayName)
                            .font(.headline)
                    } else {
                        Image(systemName: "chart.pie.fill")
                            .foregroundStyle(.secondary)
                        Text(budget.category?.displayName ?? String(localized: "budget.unnamed", defaultValue: "Unnamed Budget"))
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    // Period badge
                    Text(budget.period.localizedName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                    
                    // Active indicator
                    if !budget.isActive {
                        Image(systemName: "pause.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Progress
                BudgetProgressView(budget: budget)
            }
            .padding(16)
        }
        .buttonStyle(.plain)
        .glassBackground(cornerRadius: 16, isInteractive: true)
        .contextMenu {
            Button {
                onTap()
            } label: {
                Label(
                    String(localized: "action.edit", defaultValue: "Edit"),
                    systemImage: "pencil"
                )
            }
            
            Button {
                onToggleActive()
            } label: {
                Label(
                    budget.isActive 
                        ? String(localized: "action.deactivate", defaultValue: "Deactivate")
                        : String(localized: "action.activate", defaultValue: "Activate"),
                    systemImage: budget.isActive ? "pause.circle" : "play.circle"
                )
            }
            
            Divider()
            
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label(
                    String(localized: "action.delete", defaultValue: "Delete"),
                    systemImage: "trash"
                )
            }
        }
        .confirmationDialog(
            String(localized: "budget.deleteConfirmation.title", defaultValue: "Delete Budget?"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "action.delete", defaultValue: "Delete"), role: .destructive) {
                onDelete()
            }
        } message: {
            Text(String(localized: "budget.deleteConfirmation.message", defaultValue: "This action cannot be undone."))
        }
    }
}

#Preview("Budget List") {
    NavigationStack {
        BudgetListView()
    }
    .modelContainer(for: [Budget.self, Category.self, Transaction.self], inMemory: true)
}
