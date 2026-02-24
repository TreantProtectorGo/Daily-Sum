import Foundation
import SwiftUI
import SwiftData

enum TransactionListPreference {
    static let showUpcomingScheduledStorageKey = "flux.showUpcomingScheduledTransactions"

    static var showUpcomingScheduled: Bool {
        get {
            UserDefaults.standard.object(forKey: showUpcomingScheduledStorageKey) as? Bool ?? false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: showUpcomingScheduledStorageKey)
        }
    }
}

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
    var showUpcomingScheduled: Bool {
        didSet {
            TransactionListPreference.showUpcomingScheduled = showUpcomingScheduled
        }
    }
    
    var isLoading = false
    var errorMessage: String?
    
    // MARK: - Computed Properties
    
    var hasFilters: Bool {
        selectedType != nil || 
        selectedCategory != nil || 
        selectedAccount != nil ||
        startDate != nil ||
        endDate != nil ||
        !searchText.isEmpty ||
        showUpcomingScheduled
    }

    var upcomingScheduledTransactionsInWindow: [Transaction] {
        let now = Date.now
        guard let cutoff = Calendar.current.date(
            byAdding: .day,
            value: RecurringTransactionGenerator.defaultLookAheadDays,
            to: now
        ) else {
            return []
        }

        return transactions
            .filter { transaction in
                transaction.isGeneratedFromRecurring &&
                transaction.date > now &&
                transaction.date <= cutoff
            }
            .sorted { $0.date < $1.date }
    }

    var hiddenUpcomingScheduledTransactions: [Transaction] {
        upcomingScheduledTransactionsInWindow
    }

    var hiddenUpcomingScheduledCount: Int {
        hiddenUpcomingScheduledTransactions.count
    }

    var nextUpcomingScheduledDate: Date? {
        hiddenUpcomingScheduledTransactions.first?.date
    }

    var shouldShowUpcomingHintBar: Bool {
        !hasActiveContentFilters &&
        hiddenUpcomingScheduledCount > 0
    }

    @available(*, deprecated, renamed: "shouldShowUpcomingHintBar")
    var shouldShowUpcomingHint: Bool {
        shouldShowUpcomingHintBar
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
        self.showUpcomingScheduled = TransactionListPreference.showUpcomingScheduled
    }
    
    // MARK: - Data Loading
    
    func loadTransactions() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let descriptor = FetchDescriptor<Transaction>(
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

        if !showUpcomingScheduled {
            let now = Date.now
            result = result.filter { transaction in
                !(transaction.isGeneratedFromRecurring && transaction.date > now)
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
        showUpcomingScheduled = false
        applyFilters()
    }

    func revealUpcomingScheduled() {
        showUpcomingScheduled = true
        applyFilters()
    }

    func hideUpcomingScheduled() {
        showUpcomingScheduled = false
        applyFilters()
    }
    
    // MARK: - CRUD Operations
    
    func deleteTransaction(_ transaction: Transaction) async throws {
        try transactionService.delete(transaction)
        await loadTransactions()
    }

    func handleFutureGeneratedDeletion(
        _ transaction: Transaction,
        action: ScheduledFutureDeleteAction
    ) async throws {
        try await transactionService.handleFutureGeneratedDeletion(transaction, action: action)
        await loadTransactions()
    }
    
    func deleteTransactions(at offsets: IndexSet, in section: (date: Date, transactions: [Transaction])) async throws {
        for index in offsets {
            let transaction = section.transactions[index]
            try transactionService.delete(transaction)
        }
        await loadTransactions()
    }

    private var hasActiveContentFilters: Bool {
        selectedType != nil ||
        selectedCategory != nil ||
        selectedAccount != nil ||
        startDate != nil ||
        endDate != nil ||
        !searchText.isEmpty
    }
}
