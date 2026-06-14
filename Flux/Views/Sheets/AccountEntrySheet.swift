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
    @State private var accountTypeDefinition: AccountTypeDefinition?
    @State private var selectedCurrency: SupportedCurrency = UserCurrencyPreference.supportedCurrency
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
                
                if isEditing {
                    deleteSection
                }
            }
            .navigationTitle(isEditing 
                ? AppLocalization.string("account.edit.title", defaultValue: "Edit Account")
                : AppLocalization.string("account.add.title", defaultValue: "Add Account"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveAccount()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel("Apply")
                    .disabled(!isFormValid || isSaving)
                }
            }
            .onAppear {
                loadExistingAccount()
            }
            .alert(
                AppLocalization.string("error.title", defaultValue: "Error"),
                isPresented: $showError
            ) {
                Button(AppLocalization.string("action.ok", defaultValue: "OK")) { }
            } message: {
                Text(errorMessage)
            }
        }
        .presentationDetents([.large])
        .alert(
            AppLocalization.string("account.delete.confirm.title", defaultValue: "Do you want to delete this Account?"),
            isPresented: $showDeleteConfirmation,
        ) {
            Button(AppLocalization.string("action.confirm", defaultValue: "Confirm"), role: .destructive) {
                deleteAccount()
            }
            Button("Keep Account", role: .cancel) { }
        } message: {
            Text(AppLocalization.string("account.delete.confirm.message", defaultValue: "You cannot undo this action."))
        }
    }
    
    // MARK: - Form Sections
    
    private var basicInfoSection: some View {
        Section(AppLocalization.string("account.info", defaultValue: "Account Info")) {
            TextField(
                AppLocalization.string("account.name", defaultValue: "Account Name"),
                text: $name
            )
            .textInputAutocapitalization(.words)

            AccountTypeSelectionBox(
                title: AppLocalization.string("account.type", defaultValue: "Account Type"),
                selection: $accountTypeDefinition
            )

            currencyPicker

            CompactAmountInput(
                amount: $initialBalance,
                currencyCode: selectedCurrency.rawValue,
                label: isEditing
                    ? AppLocalization.string("account.currentBalance", defaultValue: "Current Balance")
                    : AppLocalization.string("account.initialBalance", defaultValue: "Initial Balance"),
                autoFocus: !isEditing
            )
        }
    }
    
    @ViewBuilder
    private var currencyPicker: some View {
        Picker(AppLocalization.string("account.currency", defaultValue: "Currency"), selection: $selectedCurrency) {
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
                Text(AppLocalization.string("account.delete", defaultValue: "Delete Account Permanently"))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        } footer: {
            Text(AppLocalization.string("account.delete.footer", defaultValue: "Use this only if you are sure. Deleting an account removes all its transactions."))
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
        accountTypeDefinition = account.typeDefinition
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
                    type: accountTypeDefinition == nil ? accountType : nil,
                    typeDefinition: accountTypeDefinition,
                    currencyCode: selectedCurrency.rawValue
                )
                
                _ = try service.adjustCurrentBalance(
                    existing,
                    to: targetCurrentBalance,
                    note: AppLocalization.string("account.balanceAdjustment.note", defaultValue: "Manual balance adjustment")
                )
            } else {
                if let accountTypeDefinition {
                    try service.create(
                        name: name.trimmingCharacters(in: .whitespaces),
                        typeDefinition: accountTypeDefinition,
                        currencyCode: selectedCurrency.rawValue,
                        initialBalance: initialBalance
                    )
                } else {
                    try service.create(
                        name: name.trimmingCharacters(in: .whitespaces),
                        type: accountType,
                        currencyCode: selectedCurrency.rawValue,
                        initialBalance: initialBalance
                    )
                }
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
