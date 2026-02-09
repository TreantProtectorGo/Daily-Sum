import Foundation
import SwiftData

/// Generates transaction instances from recurring templates
@MainActor
struct RecurringTransactionGenerator {
    private let context: ModelContext
    private let transactionService: TransactionService
    
    /// Number of days ahead to generate recurring transactions
    var lookAheadDays: Int = 30
    
    init(context: ModelContext) {
        self.context = context
        self.transactionService = TransactionService(context: context)
    }
    
    /// Generates all pending recurring transactions up to the look-ahead date
    @discardableResult
    func generatePendingTransactions() throws -> [Transaction] {
        let templates = try transactionService.fetchRecurringTemplates()
        let cutoffDate = Calendar.current.date(
            byAdding: .day,
            value: lookAheadDays,
            to: Date.now
        )!
        
        var generatedTransactions: [Transaction] = []
        
        for template in templates {
            let generated = try generateTransactions(
                from: template,
                upTo: cutoffDate
            )
            generatedTransactions.append(contentsOf: generated)
        }
        
        if !generatedTransactions.isEmpty {
            try context.save()
        }
        
        return generatedTransactions
    }
    
    /// Generates transactions from a single template up to a cutoff date
    func generateTransactions(
        from template: Transaction,
        upTo cutoffDate: Date
    ) throws -> [Transaction] {
        guard template.isRecurringTemplate,
              let rule = template.recurrenceRule else {
            return []
        }
        
        // Find the last generated transaction for this template
        let lastGenerated = try findLastGeneratedTransaction(for: template)
        
        // Determine the start date for generation
        let startDate: Date
        if let last = lastGenerated {
            startDate = rule.nextDate(from: last.date)
        } else {
            // First generation - start from template date
            startDate = template.date
        }
        
        // Generate transactions
        var generated: [Transaction] = []
        var currentDate = startDate
        
        while currentDate <= cutoffDate {
            // Check if already generated for this date
            let alreadyExists = try checkIfExists(
                templateId: template.id,
                date: currentDate
            )
            
            if !alreadyExists {
                let transaction = Transaction.fromTemplate(template, forDate: currentDate)
                context.insert(transaction)
                generated.append(transaction)
            }
            
            currentDate = rule.nextDate(from: currentDate)
        }
        
        return generated
    }
    
    /// Finds the most recent generated transaction for a template
    private func findLastGeneratedTransaction(for template: Transaction) throws -> Transaction? {
        let templateId = template.id
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.recurringTemplateId == templateId },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        var limitedDescriptor = descriptor
        limitedDescriptor.fetchLimit = 1
        
        return try context.fetch(limitedDescriptor).first
    }
    
    /// Checks if a transaction was already generated for a specific date
    private func checkIfExists(templateId: UUID, date: Date) throws -> Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate {
                $0.recurringTemplateId == templateId &&
                $0.date >= startOfDay &&
                $0.date < endOfDay
            }
        )
        
        return try context.fetchCount(descriptor) > 0
    }
    
    /// Deletes all generated transactions for a template (when template is modified/deleted)
    func deleteFutureGeneratedTransactions(for template: Transaction) throws {
        let templateId = template.id
        let now = Date.now
        
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate {
                $0.recurringTemplateId == templateId && $0.date > now
            }
        )
        
        let futureTransactions = try context.fetch(descriptor)
        for transaction in futureTransactions {
            context.delete(transaction)
        }
        
        try context.save()
    }
}
