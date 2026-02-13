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
        accounts.first?.currencyCode ?? SupportedCurrency.defaultFromLocale.rawValue
    }
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
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
            totalBalance = accounts.reduce(Decimal.zero) { $0 + $1.currentBalance }
            
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
                    !$0.isRecurringTemplate && $0.date >= startOfMonth 
                }
            )
            let monthlyTransactions = try modelContext.fetch(monthlyTransactionDescriptor)
            
            monthlyIncome = monthlyTransactions
                .filter { $0.type == .income }
                .reduce(Decimal.zero) { $0 + $1.amount }
            
            monthlyExpenses = monthlyTransactions
                .filter { $0.type == .expense }
                .reduce(Decimal.zero) { $0 + $1.amount }
            
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
}
