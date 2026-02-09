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
    @State private var isArchived: Bool = false
    
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
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
                    statusSection
                }
            }
            .navigationTitle(isEditing 
                ? String(localized: "account.edit.title", defaultValue: "Edit Account")
                : String(localized: "account.add.title", defaultValue: "Add Account"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel", defaultValue: "Cancel")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.save", defaultValue: "Save")) {
                        saveAccount()
                    }
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
    
    private var statusSection: some View {
        Section {
            Toggle(
                String(localized: "account.archived", defaultValue: "Archived"),
                isOn: $isArchived
            )
        } footer: {
            Text(String(localized: "account.archived.footer", defaultValue: "Archived accounts are hidden from the main list but preserve transaction history."))
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
        isArchived = account.isArchived
    }
    
    private func saveAccount() {
        guard isFormValid else { return }
        
        isSaving = true
        
        do {
            let service = AccountService(context: modelContext)
            
            if let existing = existingAccount {
                existing.name = name.trimmingCharacters(in: .whitespaces)
                existing.type = accountType
                existing.currencyCode = selectedCurrency.rawValue
                existing.isArchived = isArchived
                
                try modelContext.save()
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
}

// MARK: - Preview

#Preview("Add Account") {
    AccountEntrySheet { }
}
