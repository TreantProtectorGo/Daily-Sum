import SwiftUI
import SwiftData

// MARK: - Account Entry Sheet

struct AccountEntrySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    private let existingAccount: Account?
    private let onSave: () -> Void
    
    @State private var name: String = ""
    @State private var accountType: AccountType = .cash
    @State private var selectedCurrency: SupportedCurrency = .defaultFromLocale
    @State private var initialBalance: Decimal = 0
    
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showDeleteConfirmation = false
    
    private var isEditing: Bool { existingAccount != nil }
    
    init(account: Account? = nil, onSave: @escaping () -> Void) {
        self.existingAccount = account
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            Form {
                basicInfoSection
                accountTypeSection
                balanceSection
                
                if isEditing {
                    deleteSection
                }
            }
            .navigationTitle(isEditing 
                ? String(localized: "account.edit.title", defaultValue: "Edit Account")
                : String(localized: "account.add.title", defaultValue: "Add Account"))
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
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveAccount()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel(String(localized: "action.save", defaultValue: "Save"))
                    .disabled(!isFormValid || isSaving)
                }
            }
            .onAppear {
                loadExistingAccount()
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
        .confirmationDialog(
            String(localized: "account.delete.confirm.title", defaultValue: "Delete Account Permanently?"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "account.delete.confirm.action", defaultValue: "Delete Account"), role: .destructive) {
                deleteAccount()
            }
            Button(String(localized: "action.cancel", defaultValue: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "account.delete.confirm.message", defaultValue: "This permanently deletes the account and all related transactions. This action cannot be undone."))
        }
    }
    
    // MARK: - Form Sections
    
    private var basicInfoSection: some View {
        Section(String(localized: "account.info", defaultValue: "Account Info")) {
            TextField(
                String(localized: "account.name", defaultValue: "Account Name"),
                text: $name
            )
            .textInputAutocapitalization(.words)
        }
    }
    
    private var accountTypeSection: some View {
        Section(String(localized: "account.type", defaultValue: "Account Type")) {
            Picker(String(localized: "account.type", defaultValue: "Type"), selection: $accountType) {
                ForEach(AccountType.allCases, id: \.self) { type in
                    HStack {
                        Image(systemName: type.defaultIcon)
                        Text(type.localizedName)
                    }
                    .tag(type)
                }
            }
            .pickerStyle(.menu)
        }
    }
    
    private var balanceSection: some View {
        Section(String(localized: "account.balance", defaultValue: "Balance")) {
            currencyPicker
            
            HStack {
                Text(isEditing 
                    ? String(localized: "account.currentBalance", defaultValue: "Current Balance")
                    : String(localized: "account.initialBalance", defaultValue: "Initial Balance"))
                Spacer()
                TextField("0", value: $initialBalance, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
            }
        }
    }
    
    @ViewBuilder
    private var currencyPicker: some View {
        Picker(String(localized: "account.currency", defaultValue: "Currency"), selection: $selectedCurrency) {
            ForEach(SupportedCurrency.allCases, id: \.self) { (currency: SupportedCurrency) in
                Text("\(currency.symbol) \(currency.rawValue) - \(currency.displayName)")
                    .tag(currency)
            }
        }
    }
    
    @ViewBuilder
    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label(
                    String(localized: "account.delete", defaultValue: "Delete Account Permanently"),
                    systemImage: "trash"
                )
            }
        } footer: {
            Text(String(localized: "account.delete.footer", defaultValue: "Use this only if you are sure. Deleting an account removes all its transactions."))
        }
    }
    
    // MARK: - Validation
    
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    // MARK: - Actions
    
    private func loadExistingAccount() {
        guard let account = existingAccount else { return }
        
        name = account.name
        accountType = account.type
        if let currency = SupportedCurrency(rawValue: account.currencyCode) {
            selectedCurrency = currency
        }
        initialBalance = account.currentBalance
    }
    
    private func saveAccount() {
        guard isFormValid else { return }
        
        isSaving = true
        
        do {
            let service = AccountService(context: modelContext)
            
            if let existing = existingAccount {
                let targetCurrentBalance = initialBalance
                
                try service.update(
                    existing,
                    name: name.trimmingCharacters(in: .whitespaces),
                    type: accountType,
                    currencyCode: selectedCurrency.rawValue
                )
                
                _ = try service.adjustCurrentBalance(
                    existing,
                    to: targetCurrentBalance,
                    note: String(localized: "account.balanceAdjustment.note", defaultValue: "Manual balance adjustment")
                )
            } else {
                try service.create(
                    name: name.trimmingCharacters(in: .whitespaces),
                    type: accountType,
                    currencyCode: selectedCurrency.rawValue,
                    initialBalance: initialBalance
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
    
    private func deleteAccount() {
        guard let existing = existingAccount else { return }
        
        isSaving = true
        
        do {
            let service = AccountService(context: modelContext)
            try service.delete(existing)
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

#Preview("Add Account") {
    AccountEntrySheet { }
}
