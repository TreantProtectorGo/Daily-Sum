import Foundation
import SwiftUI
import SwiftData

// MARK: - Transaction List View Model

/// ViewModel for the Transaction List screen
@Observable
@MainActor
final class TransactionListViewModel {
    // MARK: - Properties
    
    private let modelContext: ModelContext
    private let transactionService: TransactionService
    
    var transactions: [Transaction] = []
    var filteredTransactions: [Transaction] = []
    
    var searchText = ""
    var selectedType: TransactionType?
    var selectedCategory: Category?
    var selectedAccount: Account?
    var startDate: Date?
    var endDate: Date?
    
    var isLoading = false
    var errorMessage: String?
    
    // MARK: - Computed Properties
    
    var hasFilters: Bool {
        selectedType != nil || 
        selectedCategory != nil || 
        selectedAccount != nil ||
        startDate != nil ||
        endDate != nil ||
        !searchText.isEmpty
    }
    
    var groupedTransactions: [(date: Date, transactions: [Transaction])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredTransactions) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
        return grouped.sorted { $0.key > $1.key }
            .map { (date: $0.key, transactions: $0.value) }
    }
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.transactionService = TransactionService(context: modelContext)
    }
    
    // MARK: - Data Loading
    
    func loadTransactions() async {
        isLoading = true
        errorMessage = nil
        
        do {
            var descriptor = FetchDescriptor<Transaction>(
                predicate: #Predicate<Transaction> { !$0.isRecurringTemplate },
                sortBy: [SortDescriptor(\Transaction.date, order: .reverse)]
            )
            transactions = try modelContext.fetch(descriptor)
            applyFilters()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Filtering
    
    func applyFilters() {
        var result = transactions
        
        // Filter by type
        if let type = selectedType {
            result = result.filter { $0.type == type }
        }
        
        // Filter by category
        if let category = selectedCategory {
            result = result.filter { $0.category?.id == category.id }
        }
        
        // Filter by account
        if let account = selectedAccount {
            result = result.filter { $0.account?.id == account.id }
        }
        
        // Filter by date range
        if let start = startDate {
            result = result.filter { $0.date >= start }
        }
        if let end = endDate {
            result = result.filter { $0.date <= end }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter { transaction in
                transaction.notes?.localizedStandardContains(searchText) == true ||
                transaction.category?.displayName.localizedStandardContains(searchText) == true
            }
        }
        
        filteredTransactions = result
    }
    
    func clearFilters() {
        selectedType = nil
        selectedCategory = nil
        selectedAccount = nil
        startDate = nil
        endDate = nil
        searchText = ""
        applyFilters()
    }
    
    // MARK: - CRUD Operations
    
    func deleteTransaction(_ transaction: Transaction) async throws {
        try transactionService.delete(transaction)
        await loadTransactions()
    }
    
    func deleteTransactions(at offsets: IndexSet, in section: (date: Date, transactions: [Transaction])) async throws {
        for index in offsets {
            let transaction = section.transactions[index]
            try transactionService.delete(transaction)
        }
        await loadTransactions()
    }
}
