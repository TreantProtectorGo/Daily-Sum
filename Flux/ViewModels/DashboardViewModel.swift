import Foundation
import SwiftUI
import SwiftData

// MARK: - Dashboard View Model

/// ViewModel for the Dashboard screen - aggregates financial overview data
@Observable
@MainActor
final class DashboardViewModel {
    // MARK: - Properties
    
    private let modelContext: ModelContext
    private let conversionService: CurrencyConversionService
    private let budgetService: BudgetService
    private let conversionMode: ConversionMode
    private var loadGeneration = LatestLoadGeneration()

    var totalBalance: Decimal = 0
    var monthlyIncome: Decimal = 0
    var monthlyExpenses: Decimal = 0
    var recentTransactionRows: [TransactionRowSnapshot] = []
    var topBudgets: [Budget] = []
    var budgetStatusesByID: [UUID: BudgetService.BudgetStatus] = [:]
    var accounts: [Account] = []
    
    var isLoading = false
    var errorMessage: String?
    var hasLoadedSuccessfully = false
    
    // MARK: - Computed Properties
    
    var monthlyNet: Decimal {
        monthlyIncome - monthlyExpenses
    }
    
    var hasAccounts: Bool {
        !accounts.isEmpty
    }
    
    var hasTransactions: Bool {
        !recentTransactionRows.isEmpty
    }
    
    var hasBudgets: Bool {
        !topBudgets.isEmpty
    }
    
    var defaultCurrencyCode: String {
        UserCurrencyPreference.resolvedCurrencyCode
    }

    static func resolvedDisplayCurrencyCode(preferredCurrencyCode: String) -> String {
        UserCurrencyPreference.resolvedDisplayCurrencyCode(
            preferredCurrencyCode: preferredCurrencyCode
        )
    }
    
    // MARK: - Initialization
    
    init(
        modelContext: ModelContext,
        conversionService: CurrencyConversionService? = nil,
        conversionMode: ConversionMode = .defaultForDashboard
    ) {
        self.modelContext = modelContext
        let resolvedConversionService = conversionService ?? CurrencyConversionService(context: modelContext)
        self.conversionService = resolvedConversionService
        self.budgetService = BudgetService(
            context: modelContext,
            conversionService: resolvedConversionService
        )
        self.conversionMode = conversionMode
    }
    
    // MARK: - Data Loading
    
    func loadData() async {
        let generation = loadGeneration.begin()
        let displayCurrencyCode = defaultCurrencyCode
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch accounts
            let accountDescriptor = FetchDescriptor<Account>(
                sortBy: [SortDescriptor(\Account.createdAt, order: .reverse)]
            )
            let loadedAccounts = try modelContext.fetch(accountDescriptor)
            
            // Calculate total balance
            let loadedTotalBalance = try await convertedAccountTotal(
                loadedAccounts,
                displayCurrencyCode: displayCurrencyCode
            )
            
            // Fetch recent transactions (non-recurring templates, last 10)
            let currentDate = Date.now
            var transactionDescriptor = FetchDescriptor<Transaction>(
                predicate: #Predicate<Transaction> {
                    !$0.isRecurringTemplate && $0.date <= currentDate
                },
                sortBy: [SortDescriptor(\Transaction.date, order: .reverse)]
            )
            transactionDescriptor.fetchLimit = 10
            let recentTransactions = try modelContext.fetch(transactionDescriptor)
            let loadedRecentTransactionRows = recentTransactions.map(
                TransactionRowSnapshot.init(transaction:)
            )
            
            // Calculate monthly totals
            let calendar = Calendar.current
            let now = Date()
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            
            let monthlyTransactionDescriptor = FetchDescriptor<Transaction>(
                predicate: #Predicate<Transaction> { 
                    !$0.isRecurringTemplate && $0.date >= startOfMonth && $0.date <= now
                }
            )
            let monthlyTransactions = try modelContext.fetch(monthlyTransactionDescriptor)
            
            let incomeTransactions = monthlyTransactions.filter { $0.type == .income }
            let expenseTransactions = monthlyTransactions.filter { $0.type == .expense }

            let loadedMonthlyIncome = try await convertedTransactionTotal(
                incomeTransactions,
                displayCurrencyCode: displayCurrencyCode
            )
            let loadedMonthlyExpenses = try await convertedTransactionTotal(
                expenseTransactions,
                displayCurrencyCode: displayCurrencyCode
            )
            
            // Fetch budgets (top 3)
            var budgetDescriptor = FetchDescriptor<Budget>(
                sortBy: [SortDescriptor(\Budget.createdAt, order: .reverse)]
            )
            budgetDescriptor.fetchLimit = 3
            let loadedTopBudgets = try modelContext.fetch(budgetDescriptor)
            let loadedBudgetStatuses = try await budgetService.statuses(for: loadedTopBudgets)

            guard loadGeneration.isCurrent(generation) else { return }
            guard !Task.isCancelled else {
                isLoading = false
                return
            }
            accounts = loadedAccounts
            totalBalance = loadedTotalBalance
            recentTransactionRows = loadedRecentTransactionRows
            monthlyIncome = loadedMonthlyIncome
            monthlyExpenses = loadedMonthlyExpenses
            topBudgets = loadedTopBudgets
            budgetStatusesByID = loadedBudgetStatuses
            hasLoadedSuccessfully = true
        } catch {
            guard loadGeneration.isCurrent(generation) else { return }
            if !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
        }

        if loadGeneration.isCurrent(generation) {
            isLoading = false
        }
    }
    
    // MARK: - Actions
    
    func refresh() async {
        await loadData()
    }

    // MARK: - Conversion

    private func convertedAccountTotal(
        _ accounts: [Account],
        displayCurrencyCode: String
    ) async throws -> Decimal {
        var total: Decimal = 0

        for account in accounts where account.includeInTotal {
            let convertedBalance = try await conversionService.convert(
                account.currentBalance,
                from: account.currencyCode,
                to: displayCurrencyCode,
                on: .now,
                mode: conversionMode
            )
            total += convertedBalance
        }

        return total
    }

    private func convertedTransactionTotal(
        _ transactions: [Transaction],
        displayCurrencyCode: String
    ) async throws -> Decimal {
        var total: Decimal = 0

        for transaction in transactions {
            let convertedAmount = try await conversionService.convert(
                transaction.amount,
                from: transaction.currencyCode,
                to: displayCurrencyCode,
                on: transaction.date,
                mode: conversionMode
            )
            total += convertedAmount
        }

        return total
    }
}
