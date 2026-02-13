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
    @State private var currencyCode: String = UserCurrencyPreference.currencyCode
    @State private var alertThreshold: Decimal = 0.8
    @State private var alertsEnabled: Bool = true
    
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    @Query private var categories: [Category]
    
    private var expenseCategories: [Category] {
        categories.filter { $0.type == .expense }
    }
    
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
                ? String(localized: "budget.edit.title", defaultValue: "Edit Budget")
                : String(localized: "budget.add.title", defaultValue: "Create Budget"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(String(localized: "action.cancel", defaultValue: "Cancel"))
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveBudget()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel(String(localized: "action.save", defaultValue: "Save"))
                    .disabled(!isFormValid || isSaving)
                }
            }
            .onAppear {
                loadExistingBudget()
                applyDefaultCategoryIfNeeded()
            }
            .onChange(of: categories.count) { _ in
                applyDefaultCategoryIfNeeded()
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
    
    private var amountSection: some View {
        Section(String(localized: "budget.amount", defaultValue: "Amount & Period")) {
            Picker(String(localized: "budget.period", defaultValue: "Period"), selection: $period) {
                ForEach(BudgetPeriod.allCases, id: \.self) { period in
                    Text(period.localizedName)
                        .tag(period)
                }
            }
            
            HStack {
                Text(String(localized: "budget.limit", defaultValue: "Spending Limit"))
                Spacer()
                TextField("0", value: $limitAmount, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
            }
            
            Picker(String(localized: "budget.currency", defaultValue: "Currency"), selection: $currencyCode) {
                ForEach(currencyOptions, id: \.self) { currency in
                    Text("\(currency.symbol) \(currency.rawValue) - \(currency.displayName)")
                        .tag(currency.rawValue)
                }
            }
        }
    }
    
    private var categorySection: some View {
        Section {
            Picker(
                String(localized: "budget.category", defaultValue: "Category"),
                selection: $selectedCategory
            ) {
                ForEach(expenseCategories) { category in
                    HStack {
                        Image(systemName: category.icon)
                            .foregroundStyle(category.color)
                        Text(category.displayName)
                    }
                    .tag(category as Category?)
                }
            }
        } header: {
            Text(String(localized: "budget.category.section", defaultValue: "Category"))
        } footer: {
            Text(String(localized: "budget.category.footer", defaultValue: "Select a category for this budget."))
        }
    }
    
    private var statusSection: some View {
        Section {
            Toggle(
                String(localized: "budget.alertsEnabled", defaultValue: "Enable Alerts"),
                isOn: $alertsEnabled
            )
        }
    }
    
    // MARK: - Validation
    
    private var isFormValid: Bool {
        limitAmount > 0 && selectedCategory != nil
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

    private func applyDefaultCategoryIfNeeded() {
        guard selectedCategory == nil else { return }
        selectedCategory = expenseCategories.first
    }
    
    private func saveBudget() {
        guard isFormValid else { return }
        guard let selectedCategory else {
            errorMessage = String(localized: "budget.category.required", defaultValue: "Please select a category.")
            showError = true
            return
        }
        
        isSaving = true
        
        do {
            let budgetService = BudgetService(context: modelContext)

            if let existing = existingBudget {
                try budgetService.update(
                    existing,
                    limitAmount: limitAmount,
                    period: period,
                    category: selectedCategory,
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
