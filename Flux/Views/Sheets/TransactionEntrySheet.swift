import SwiftUI
import SwiftData

// MARK: - Transaction Entry Sheet

/// Sheet for adding or editing a transaction
struct TransactionEntrySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    private let existingTransaction: Transaction?
    private let onSave: () -> Void
    
    // Form state
    @State private var transactionType: TransactionType = .expense
    @State private var amount: Decimal = 0
    @State private var selectedCategory: Category?
    @State private var selectedAccount: Account?
    @State private var date: Date = Date()
    @State private var notes: String = ""
    
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    @Query private var accounts: [Account]
    
    private var isEditing: Bool { existingTransaction != nil }
    
    init(transaction: Transaction? = nil, onSave: @escaping () -> Void) {
        self.existingTransaction = transaction
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Transaction Type
                transactionTypeSection
                
                // Amount
                amountSection
                
                // Category
                categorySection
                
                // Account
                accountSection
                
                // Date
                dateSection
                
                // Notes
                notesSection
            }
            .navigationTitle(isEditing 
                ? String(localized: "transaction.edit.title", defaultValue: "Edit Transaction")
                : String(localized: "transaction.add.title", defaultValue: "Add Transaction"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel", defaultValue: "Cancel")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.save", defaultValue: "Save")) {
                        saveTransaction()
                    }
                    .disabled(!isFormValid || isSaving)
                }
            }
            .onAppear {
                loadExistingTransaction()
            }
            .alert(
                String(localized: "error.title", defaultValue: "Error"),
                isPresented: $showError
            ) {
                Button(String(localized: "action.ok", defaultValue: "OK")) { }
            } message: {
                Text(errorMessage)
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    // MARK: - Form Sections
    
    private var transactionTypeSection: some View {
        Section {
            Picker(String(localized: "transaction.type", defaultValue: "Type"), selection: $transactionType) {
                ForEach(TransactionType.allCases, id: \.self) { type in
                    Text(type.localizedName)
                        .tag(type)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: transactionType) { _, _ in
                // Reset category when type changes
                selectedCategory = nil
            }
        }
    }
    
    private var amountSection: some View {
        Section(String(localized: "transaction.amount", defaultValue: "Amount")) {
            AmountInputView(
                amount: $amount,
                currencyCode: selectedAccount?.currencyCode ?? SupportedCurrency.defaultFromLocale.rawValue
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }
    
    private var categorySection: some View {
        Section(String(localized: "transaction.category", defaultValue: "Category")) {
            CategoryPickerView(
                selectedCategory: $selectedCategory,
                transactionType: transactionType
            )
            .id(transactionType) // Force view recreation when type changes to refresh @Query
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
        }
    }
    
    private var accountSection: some View {
        Section(String(localized: "transaction.account", defaultValue: "Account")) {
            if accounts.isEmpty {
                Text(String(localized: "transaction.noAccounts", defaultValue: "No accounts available. Please create an account first."))
                    .foregroundStyle(.secondary)
            } else {
                Picker(String(localized: "transaction.account", defaultValue: "Account"), selection: $selectedAccount) {
                    Text(String(localized: "transaction.selectAccount", defaultValue: "Select Account"))
                        .tag(nil as Account?)
                    
                    ForEach(accounts.filter { !$0.isArchived }) { account in
                        HStack {
                            Image(systemName: account.type.icon)
                                .foregroundStyle(account.type.color)
                            Text(account.name)
                        }
                        .tag(account as Account?)
                    }
                }
            }
        }
    }
    
    private var dateSection: some View {
        Section(String(localized: "transaction.date", defaultValue: "Date")) {
            DatePicker(
                String(localized: "transaction.date", defaultValue: "Date"),
                selection: $date,
                displayedComponents: [.date, .hourAndMinute]
            )
        }
    }
    
    private var notesSection: some View {
        Section(String(localized: "transaction.notes", defaultValue: "Notes")) {
            TextField(
                String(localized: "transaction.notes.placeholder", defaultValue: "Add notes..."),
                text: $notes,
                axis: .vertical
            )
            .lineLimit(3...6)
        }
    }
    
    // MARK: - Validation
    
    private var isFormValid: Bool {
        amount > 0 && selectedAccount != nil
    }
    
    // MARK: - Actions
    
    private func loadExistingTransaction() {
        guard let transaction = existingTransaction else { return }
        
        transactionType = transaction.type
        amount = transaction.amount
        selectedCategory = transaction.category
        selectedAccount = transaction.account
        date = transaction.date
        notes = transaction.notes ?? ""
    }
    
    private func saveTransaction() {
        guard isFormValid, let account = selectedAccount else { return }
        
        isSaving = true
        
        do {
            let service = TransactionService(context: modelContext)
            
            if let existing = existingTransaction {
                // Update existing
                existing.type = transactionType
                existing.amount = amount
                existing.category = selectedCategory
                existing.account = account
                existing.date = date
                existing.notes = notes.isEmpty ? nil : notes
                existing.currencyCode = account.currencyCode
                
                try modelContext.save()
            } else {
                try service.create(
                    amount: amount,
                    type: transactionType,
                    date: date,
                    notes: notes.isEmpty ? nil : notes,
                    account: account,
                    category: selectedCategory
                )
            }
            
            onSave()
            dismiss()
            
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isSaving = false
    }
}

// MARK: - Preview

#Preview("Add Transaction") {
    TransactionEntrySheet { }
        .modelContainer(for: [Transaction.self, Account.self, Category.self], inMemory: true)
}
