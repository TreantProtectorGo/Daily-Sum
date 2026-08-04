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

struct TransactionDateGroupSnapshot {
    let date: Date
    let rows: [TransactionRowSnapshot]
    let incomeTotal: Decimal
    let expenseTotal: Decimal
    let currencyCode: String?

    init(date: Date, rows: [TransactionRowSnapshot]) {
        self.date = date
        self.rows = rows
        let postedRows = rows.filter { !$0.isPendingScheduledOccurrence }

        incomeTotal = postedRows
            .filter { $0.signedAmount > 0 }
            .reduce(Decimal.zero) { $0 + $1.signedAmount }

        expenseTotal = postedRows
            .filter { $0.signedAmount < 0 }
            .reduce(Decimal.zero) { $0 + abs($1.signedAmount) }

        // Pending rows do not contribute to posted totals, so they must not make a valid
        // single-currency posted group look mixed. A pending-only day intentionally has no
        // currency summary, avoiding meaningless +0 / -0 values.
        let currencyCodes = Set(postedRows.map(\.currencyCode))
        currencyCode = currencyCodes.count == 1 ? currencyCodes.first : nil
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
    private var loadGeneration = LatestLoadGeneration()
    
    var transactions: [Transaction] = []
    var transactionRows: [TransactionRowSnapshot] = []
    var filteredTransactions: [Transaction] = []
    var filteredTransactionRows: [TransactionRowSnapshot] = []
    
    var searchText = ""
    var selectedType: TransactionType?
    var selectedCategory: Category?
    var selectedAccount: Account?
    var startDate: Date?
    var endDate: Date?
    var showTravelTransactionsOnly = false
    var showUpcomingScheduled: Bool {
        didSet {
            TransactionListPreference.showUpcomingScheduled = showUpcomingScheduled
        }
    }
    
    var isLoading = false
    var errorMessage: String?
    var hasLoadedSuccessfully = false
    
    // MARK: - Computed Properties
    
    var hasFilters: Bool {
        selectedType != nil || 
        selectedCategory != nil || 
        selectedAccount != nil ||
        startDate != nil ||
        endDate != nil ||
        showTravelTransactionsOnly ||
        !searchText.isEmpty ||
        !showUpcomingScheduled
    }

    var upcomingScheduledRowsInWindow: [TransactionRowSnapshot] {
        let now = Date.now
        guard let cutoff = Calendar.current.date(
            byAdding: .day,
            value: RecurringTransactionGenerator.defaultLookAheadDays,
            to: now
        ) else {
            return []
        }

        return transactionRows
            .filter { row in
                row.isGeneratedFromRecurring &&
                row.date > now &&
                row.date <= cutoff
            }
            .sorted { $0.date < $1.date }
    }

    var hiddenUpcomingScheduledRows: [TransactionRowSnapshot] {
        upcomingScheduledRowsInWindow
    }

    var hiddenUpcomingScheduledCount: Int {
        hiddenUpcomingScheduledRows.count
    }

    var nextUpcomingScheduledDate: Date? {
        hiddenUpcomingScheduledRows.first?.date
    }

    var shouldShowUpcomingHintBar: Bool {
        !hasActiveContentFilters &&
        hiddenUpcomingScheduledCount > 0
    }

    @available(*, deprecated, renamed: "shouldShowUpcomingHintBar")
    var shouldShowUpcomingHint: Bool {
        shouldShowUpcomingHintBar
    }
    
    var groupedTransactionRows: [TransactionDateGroupSnapshot] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: timelineTransactionRows) { row in
            calendar.startOfDay(for: row.date)
        }
        return grouped.sorted { $0.key > $1.key }
            .map {
                TransactionDateGroupSnapshot(
                    date: $0.key,
                    rows: Self.sortRowsForTimeline($0.value)
                )
            }
    }

    var visibleUpcomingScheduledRows: [TransactionRowSnapshot] {
        guard showUpcomingScheduled else { return [] }
        let now = Date.now
        return filteredTransactionRows
            .filter { row in
                row.isGeneratedFromRecurring && row.date > now
            }
            .sorted { $0.date < $1.date }
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
        let generation = loadGeneration.begin()
        isLoading = true
        errorMessage = nil
        
        do {
            let descriptor = FetchDescriptor<Transaction>(
                predicate: #Predicate<Transaction> { !$0.isRecurringTemplate },
                sortBy: Self.timelineSortDescriptors
            )
            let loadedTransactions = try modelContext.fetch(descriptor)
            guard loadGeneration.isCurrent(generation) else { return }
            guard !Task.isCancelled else {
                isLoading = false
                return
            }
            transactions = loadedTransactions
            transactionRows = loadedTransactions.map(TransactionRowSnapshot.init(transaction:))
            applyFilters()
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
            let calendar = Calendar.current
            let exclusiveEnd = calendar.date(
                byAdding: .day,
                value: 1,
                to: calendar.startOfDay(for: end)
            ) ?? end
            result = result.filter { $0.date < exclusiveEnd }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter { transaction in
                transaction.notes?.localizedStandardContains(searchText) == true ||
                transaction.category?.displayName.localizedStandardContains(searchText) == true
            }
        }

        if showTravelTransactionsOnly {
            result = result.filter { $0.isTravelTransaction == true }
        }

        if !showUpcomingScheduled {
            let now = Date.now
            result = result.filter { transaction in
                !(transaction.isGeneratedFromRecurring && transaction.date > now)
            }
        }
        
        filteredTransactions = Self.sortTransactionsForTimeline(result)
        filteredTransactionRows = filteredTransactions.map(TransactionRowSnapshot.init(transaction:))
    }
    
    func clearFilters() {
        selectedType = nil
        selectedCategory = nil
        selectedAccount = nil
        startDate = nil
        endDate = nil
        showTravelTransactionsOnly = false
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

    func confirmScheduledOccurrence(transactionId: UUID) async throws {
        guard let transaction = try transactionService.fetch(byId: transactionId) else {
            await loadTransactions()
            return
        }
        try transactionService.confirmScheduledOccurrence(transaction)
        if let templateID = transaction.recurringTemplateId {
            await TransactionReminderScheduler(context: modelContext).removeReminder(
                forTemplateId: templateID,
                dueDate: transaction.date
            )
        }
        TransactionDataChangeStore.shared.markChanged()
        await loadTransactions()
    }

    func reportOperationError(_ error: Error) {
        errorMessage = error.localizedDescription
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
        showTravelTransactionsOnly ||
        !searchText.isEmpty
    }

    private var timelineTransactionRows: [TransactionRowSnapshot] {
        guard showUpcomingScheduled else {
            return Self.sortRowsForTimeline(filteredTransactionRows)
        }

        let now = Date.now
        return Self.sortRowsForTimeline(filteredTransactionRows.filter { row in
            !(row.isGeneratedFromRecurring && row.date > now)
        })
    }

    private static var timelineSortDescriptors: [SortDescriptor<Transaction>] {
        [
            SortDescriptor(\Transaction.date, order: .reverse),
            SortDescriptor(\Transaction.createdAt, order: .reverse),
            SortDescriptor(\Transaction.id)
        ]
    }

    private static func sortTransactionsForTimeline(_ transactions: [Transaction]) -> [Transaction] {
        let calendar = Calendar.current
        return transactions.sorted {
            let lhsDay = calendar.startOfDay(for: $0.date)
            let rhsDay = calendar.startOfDay(for: $1.date)
            if lhsDay != rhsDay {
                return lhsDay > rhsDay
            }
            if $0.createdAt != $1.createdAt {
                return $0.createdAt > $1.createdAt
            }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    private static func sortRowsForTimeline(_ rows: [TransactionRowSnapshot]) -> [TransactionRowSnapshot] {
        let calendar = Calendar.current
        return rows.sorted {
            let lhsDay = calendar.startOfDay(for: $0.date)
            let rhsDay = calendar.startOfDay(for: $1.date)
            if lhsDay != rhsDay {
                return lhsDay > rhsDay
            }
            if $0.createdAt != $1.createdAt {
                return $0.createdAt > $1.createdAt
            }
            return $0.id.uuidString < $1.id.uuidString
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
                .filter {
                    $0.recurringTemplateId == templateId &&
                    $0.isPendingScheduledOccurrence
                }
                .map(\.id)
            idsToRemove.formUnion(relatedGeneratedIds)
        }

        transactions.removeAll { idsToRemove.contains($0.id) }
        transactionRows.removeAll { idsToRemove.contains($0.id) }
        filteredTransactions.removeAll { idsToRemove.contains($0.id) }
        filteredTransactionRows.removeAll { idsToRemove.contains($0.id) }
    }
}
