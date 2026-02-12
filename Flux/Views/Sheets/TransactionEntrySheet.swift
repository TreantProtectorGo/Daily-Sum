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
    
    init(transaction: Transaction? = nil, onSave: @escaping () -> Void) {
        self.existingTransaction = transaction
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Amount
                amountSection
                
                // Grouped details
                detailsSection
                
                // Notes
                notesSection
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.black)
                    }
                    .accessibilityLabel(String(localized: "action.cancel", defaultValue: "Cancel"))
                }
                
                ToolbarItem(placement: .principal) {
                    transactionTypePicker
                        .frame(width: 220)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveTransaction()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel(String(localized: "action.save", defaultValue: "Save"))
                    .disabled(!isFormValid || isSaving)
                }
            }
            .onAppear {
                if existingTransaction != nil {
                    loadExistingTransaction()
                } else {
                    applyPreferredAccountIfNeeded()
                }
            }
            .onChange(of: accounts.count) { _, _ in
                applyPreferredAccountIfNeeded()
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
    
    private var transactionTypePicker: some View {
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
    
    private var amountSection: some View {
        Section(String(localized: "transaction.amount", defaultValue: "Amount")) {
            AmountInputView(
                amount: $amount,
                currencyCode: selectedAccount?.currencyCode ?? SupportedCurrency.defaultFromLocale.rawValue,
                autoFocus: true
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }
    
    private var detailsSection: some View {
        Section {
            CategoryPickerView(
                selectedCategory: $selectedCategory,
                transactionType: transactionType
            )

            if accounts.isEmpty {
                Text(String(localized: "transaction.noAccounts", defaultValue: "No accounts available. Please create an account first."))
                    .foregroundStyle(.secondary)
            } else {
                Picker(String(localized: "transaction.account", defaultValue: "Account"), selection: $selectedAccount) {
                    Text(String(localized: "transaction.selectAccount", defaultValue: "Select Account"))
                        .tag(nil as Account?)
                    
                    ForEach(accounts) { account in
                        HStack {
                            Image(systemName: account.type.icon)
                                .foregroundStyle(account.type.color)
                            Text(account.name)
                        }
                        .tag(account as Account?)
                    }
                }
            }

            DatePicker(
                String(localized: "transaction.date", defaultValue: "Date"),
                selection: $date,
                displayedComponents: .date
            )
        } header: {
            Text(String(localized: "transaction.details", defaultValue: "Details"))
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
    
    private func applyPreferredAccountIfNeeded() {
        guard existingTransaction == nil, selectedAccount == nil else { return }
        
        guard !accounts.isEmpty else { return }
        
        if TransactionAccountPreference.rememberLastUsedAccount,
           let lastUsedId = TransactionAccountPreference.lastUsedAccountId,
           let lastUsedAccount = accounts.first(where: { $0.id == lastUsedId }) {
            selectedAccount = lastUsedAccount
            return
        }
        
        if let defaultAccountId = TransactionAccountPreference.defaultAccountId,
           let defaultAccount = accounts.first(where: { $0.id == defaultAccountId }) {
            selectedAccount = defaultAccount
            return
        }
        
        if let cashAccount = accounts.first(where: { $0.type == .cash }) {
            selectedAccount = cashAccount
            return
        }
        
        selectedAccount = accounts.first
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
            if TransactionAccountPreference.rememberLastUsedAccount {
                TransactionAccountPreference.lastUsedAccountId = account.id
            }
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
