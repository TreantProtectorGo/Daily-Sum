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
    private let conversionMode: ConversionMode

    var totalBalance: Decimal = 0
    var monthlyIncome: Decimal = 0
    var monthlyExpenses: Decimal = 0
    var recentTransactions: [Transaction] = []
    var topBudgets: [Budget] = []
    var accounts: [Account] = []
    
    var isLoading = false
    var errorMessage: String?
    
    // MARK: - Computed Properties
    
    var monthlyNet: Decimal {
        monthlyIncome - monthlyExpenses
    }
    
    var hasAccounts: Bool {
        !accounts.isEmpty
    }
    
    var hasTransactions: Bool {
        !recentTransactions.isEmpty
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
        self.conversionService = conversionService ?? CurrencyConversionService(context: modelContext)
        self.conversionMode = conversionMode
    }
    
    // MARK: - Data Loading
    
    func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch accounts
            let accountDescriptor = FetchDescriptor<Account>(
                sortBy: [SortDescriptor(\Account.createdAt, order: .reverse)]
            )
            accounts = try modelContext.fetch(accountDescriptor)
            
            // Calculate total balance
            totalBalance = try await convertedAccountTotal(accounts)
            
            // Fetch recent transactions (non-recurring templates, last 10)
            var transactionDescriptor = FetchDescriptor<Transaction>(
                predicate: #Predicate<Transaction> { !$0.isRecurringTemplate },
                sortBy: [SortDescriptor(\Transaction.date, order: .reverse)]
            )
            transactionDescriptor.fetchLimit = 10
            recentTransactions = try modelContext.fetch(transactionDescriptor)
            
            // Calculate monthly totals
            let calendar = Calendar.current
            let now = Date()
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            
            var monthlyTransactionDescriptor = FetchDescriptor<Transaction>(
                predicate: #Predicate<Transaction> { 
                    !$0.isRecurringTemplate && $0.date >= startOfMonth && $0.date <= now
                }
            )
            let monthlyTransactions = try modelContext.fetch(monthlyTransactionDescriptor)
            
            let incomeTransactions = monthlyTransactions.filter { $0.type == .income }
            let expenseTransactions = monthlyTransactions.filter { $0.type == .expense }

            monthlyIncome = try await convertedTransactionTotal(incomeTransactions)
            monthlyExpenses = try await convertedTransactionTotal(expenseTransactions)
            
            // Fetch budgets (top 3)
            var budgetDescriptor = FetchDescriptor<Budget>(
                sortBy: [SortDescriptor(\Budget.createdAt, order: .reverse)]
            )
            budgetDescriptor.fetchLimit = 3
            topBudgets = try modelContext.fetch(budgetDescriptor)
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Actions
    
    func refresh() async {
        await loadData()
    }

    // MARK: - Conversion

    private func convertedAccountTotal(_ accounts: [Account]) async throws -> Decimal {
        var total: Decimal = 0

        for account in accounts where account.includeInTotal {
            let convertedBalance = try await conversionService.convert(
                account.currentBalance,
                from: account.currencyCode,
                to: defaultCurrencyCode,
                on: .now,
                mode: conversionMode
            )
            total += convertedBalance
        }

        return total
    }

    private func convertedTransactionTotal(_ transactions: [Transaction]) async throws -> Decimal {
        var total: Decimal = 0

        for transaction in transactions {
            let convertedAmount = try await conversionService.convert(
                transaction.amount,
                from: transaction.currencyCode,
                to: defaultCurrencyCode,
                on: transaction.date,
                mode: conversionMode
            )
            total += convertedAmount
        }

        return total
    }
}
