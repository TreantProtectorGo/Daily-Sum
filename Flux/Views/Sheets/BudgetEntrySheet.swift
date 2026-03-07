import SwiftUI
import SwiftData

// MARK: - Budget Entry Sheet

struct BudgetEntrySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    private let existingBudget: Budget?
    private let onSave: () -> Void
    
    @State private var limitAmount: Decimal = 0
    @State private var period: BudgetPeriod = .monthly
    @State private var selectedCategory: Category?
    @State private var currencyCode: String = UserCurrencyPreference.resolvedCurrencyCode
    @State private var alertThreshold: Decimal = 0.8
    @State private var alertsEnabled: Bool = true
    
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var selectedDetent: PresentationDetent = .medium
    
    private var currencyOptions: [SupportedCurrency] {
        SupportedCurrency.allCases.map { $0 }
    }
    
    private var isEditing: Bool { existingBudget != nil }
    
    init(budget: Budget? = nil, onSave: @escaping () -> Void) {
        self.existingBudget = budget
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            Form {
                amountSection
                categorySection
                statusSection
            }
            .navigationTitle(isEditing 
                ? AppLocalization.string("budget.edit.title", defaultValue: "Edit Budget")
                : AppLocalization.string("budget.add.title", defaultValue: "Create Budget"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(AppLocalization.string("action.cancel", defaultValue: "Cancel"))
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveBudget()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel(AppLocalization.string("action.save", defaultValue: "Save"))
                    .disabled(!isFormValid || isSaving)
                }
            }
            .onAppear {
                selectedDetent = isEditing ? .medium : .large
                loadExistingBudget()
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
        .presentationDetents([.medium, .large], selection: $selectedDetent)
    }
    
    // MARK: - Form Sections
    
    private var amountSection: some View {
        Section(AppLocalization.string("budget.amount", defaultValue: "Amount & Period")) {
            Picker(AppLocalization.string("budget.period", defaultValue: "Period"), selection: $period) {
                ForEach(BudgetPeriod.allCases, id: \.self) { period in
                    Text(period.localizedName)
                        .tag(period)
                }
            }

            CompactAmountInput(
                amount: $limitAmount,
                currencyCode: currencyCode,
                label: AppLocalization.string("budget.limit", defaultValue: "Spending Limit"),
                autoFocus: !isEditing
            )
            
            Picker(AppLocalization.string("budget.currency", defaultValue: "Currency"), selection: $currencyCode) {
                ForEach(currencyOptions, id: \.self) { currency in
                    Text("\(currency.symbol) \(currency.rawValue) - \(currency.displayName)")
                        .tag(currency.rawValue)
                }
            }
        }
    }
    
    private var categorySection: some View {
        Section {
            CategoryPickerView(
                selectedCategory: $selectedCategory,
                mode: .budgetExpense
            )
        } header: {
            Text(AppLocalization.string("budget.category.section", defaultValue: "Category"))
        } footer: {
            if selectedCategory == nil {
                Text(AppLocalization.string("budget.category.footer.all", defaultValue: "This budget tracks all expense categories."))
            } else {
                Text(AppLocalization.string("budget.category.footer", defaultValue: "Select a category for this budget."))
            }
        }
    }
    
    private var statusSection: some View {
        Section {
            Toggle(
                AppLocalization.string("budget.alertsEnabled", defaultValue: "Enable Alerts"),
                isOn: $alertsEnabled
            )
        }
    }
    
    // MARK: - Validation
    
    private var isFormValid: Bool {
        limitAmount > 0
    }
    
    // MARK: - Actions
    
    private func loadExistingBudget() {
        guard let budget = existingBudget else { return }
        
        limitAmount = budget.limitAmount
        period = budget.period
        selectedCategory = budget.category
        currencyCode = budget.currencyCode
        alertThreshold = budget.alertThreshold
        alertsEnabled = budget.alertsEnabled
    }
    
    private func saveBudget() {
        guard isFormValid else { return }
        
        isSaving = true
        
        do {
            let budgetService = BudgetService(context: modelContext)

            if let existing = existingBudget {
                try budgetService.update(
                    existing,
                    limitAmount: limitAmount,
                    period: period,
                    category: selectedCategory,
                    shouldUpdateCategory: true,
                    currencyCode: currencyCode,
                    isActive: true,
                    alertThreshold: alertThreshold,
                    alertsEnabled: alertsEnabled
                )
            } else {
                _ = try budgetService.create(
                    category: selectedCategory,
                    limitAmount: limitAmount,
                    currencyCode: currencyCode,
                    period: period,
                    alertThreshold: alertThreshold,
                    alertsEnabled: alertsEnabled,
                    isActive: true
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

#Preview("Add Budget") {
    BudgetEntrySheet { }
        .modelContainer(for: [Budget.self, Category.self], inMemory: true)
}
