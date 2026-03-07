import Foundation
import SwiftUI
import SwiftData

enum TransactionListPreference {
    static let showUpcomingScheduledStorageKey = "flux.showUpcomingScheduledTransactions"
    static let showUpcomingScheduledMigrationKey =
        "flux.showUpcomingScheduledTransactions.defaultVisibleMigrationCompleted"

    static var showUpcomingScheduled: Bool {
        get {
            let migrationCompleted = UserDefaults.standard.object(
                forKey: showUpcomingScheduledMigrationKey
            ) as? Bool ?? false

            if !migrationCompleted {
                UserDefaults.standard.set(true, forKey: showUpcomingScheduledStorageKey)
                UserDefaults.standard.set(true, forKey: showUpcomingScheduledMigrationKey)
                return true
            }

            return UserDefaults.standard.object(
                forKey: showUpcomingScheduledStorageKey
            ) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: showUpcomingScheduledStorageKey)
            UserDefaults.standard.set(true, forKey: showUpcomingScheduledMigrationKey)
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
        !showUpcomingScheduled
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
    
    var groupedTransactionRows: [(date: Date, rows: [TransactionRowSnapshot])] {
        let calendar = Calendar.current
        let snapshots = timelineTransactions.map(TransactionRowSnapshot.init(transaction:))
        let grouped = Dictionary(grouping: snapshots) { row in
            calendar.startOfDay(for: row.date)
        }
        return grouped.sorted { $0.key > $1.key }
            .map { (date: $0.key, rows: $0.value) }
    }

    var visibleUpcomingScheduledRows: [TransactionRowSnapshot] {
        guard showUpcomingScheduled else { return [] }
        let now = Date.now
        return filteredTransactions
            .filter { transaction in
                transaction.isGeneratedFromRecurring && transaction.date > now
            }
            .sorted { $0.date < $1.date }
            .map(TransactionRowSnapshot.init(transaction:))
    }

    var hasVisibleTransactions: Bool {
        !visibleUpcomingScheduledRows.isEmpty || !groupedTransactionRows.isEmpty
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
        showUpcomingScheduled = true
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

    func transaction(byId transactionId: UUID) throws -> Transaction? {
        try transactionService.fetch(byId: transactionId)
    }

    func isSourceRecurringTransaction(transactionId: UUID) -> Bool {
        guard
            let transaction = try? transactionService.fetch(byId: transactionId),
            let templateId = transaction.recurringTemplateId,
            let template = try? transactionService.fetch(byId: templateId)
        else {
            return false
        }

        return Calendar.current.isDate(transaction.date, inSameDayAs: template.date)
    }
    
    func deleteTransaction(_ transaction: Transaction) async throws {
        pruneDeletedTransactionsLocally(
            transactionId: transaction.id,
            templateId: transaction.recurringTemplateId,
            action: nil
        )
        await Task.yield()

        do {
            try transactionService.delete(transaction)
            await loadTransactions()
        } catch {
            await loadTransactions()
            throw error
        }
    }

    func deleteTransaction(transactionId: UUID) async throws {
        guard let transaction = try transactionService.fetch(byId: transactionId) else {
            await loadTransactions()
            return
        }

        try await deleteTransaction(transaction)
    }

    func handleFutureGeneratedDeletion(
        _ transaction: Transaction,
        action: ScheduledFutureDeleteAction
    ) async throws {
        pruneDeletedTransactionsLocally(
            transactionId: transaction.id,
            templateId: transaction.recurringTemplateId,
            action: action
        )
        await Task.yield()

        do {
            try await transactionService.handleFutureGeneratedDeletion(transaction, action: action)
            await loadTransactions()
        } catch {
            await loadTransactions()
            throw error
        }
    }

    func handleFutureGeneratedDeletion(
        transactionId: UUID,
        action: ScheduledFutureDeleteAction
    ) async throws {
        guard let transaction = try transactionService.fetch(byId: transactionId) else {
            await loadTransactions()
            return
        }

        try await handleFutureGeneratedDeletion(transaction, action: action)
    }
    
    func deleteTransactions(at offsets: IndexSet, in section: (date: Date, transactions: [Transaction])) async throws {
        let selectedTransactions = offsets.map { section.transactions[$0] }
        for transaction in selectedTransactions {
            pruneDeletedTransactionsLocally(
                transactionId: transaction.id,
                templateId: transaction.recurringTemplateId,
                action: nil
            )
        }
        await Task.yield()

        do {
            for transaction in selectedTransactions {
                try transactionService.delete(transaction)
            }
            await loadTransactions()
        } catch {
            await loadTransactions()
            throw error
        }
    }

    private var hasActiveContentFilters: Bool {
        selectedType != nil ||
        selectedCategory != nil ||
        selectedAccount != nil ||
        startDate != nil ||
        endDate != nil ||
        !searchText.isEmpty
    }

    private var timelineTransactions: [Transaction] {
        guard showUpcomingScheduled else {
            return filteredTransactions
        }

        let now = Date.now
        return filteredTransactions.filter { transaction in
            !(transaction.isGeneratedFromRecurring && transaction.date > now)
        }
    }

    private func pruneDeletedTransactionsLocally(
        transactionId: UUID,
        templateId: UUID?,
        action: ScheduledFutureDeleteAction?
    ) {
        var idsToRemove: Set<UUID> = [transactionId]

        if action == .stopPlan,
           let templateId {
            let relatedGeneratedIds = transactions
                .filter { $0.recurringTemplateId == templateId }
                .map(\.id)
            idsToRemove.formUnion(relatedGeneratedIds)
        }

        transactions.removeAll { idsToRemove.contains($0.id) }
        filteredTransactions.removeAll { idsToRemove.contains($0.id) }
    }
}
