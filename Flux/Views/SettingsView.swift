import SwiftUI
import SwiftData

// MARK: - Settings View

/// App settings including regional preferences and data management
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SettingsViewModel?
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    
    @State private var showClearDataConfirmation = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    settingsContent(viewModel: viewModel)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(String(localized: "settings.title", defaultValue: "Settings"))
            .task {
                if viewModel == nil {
                    viewModel = SettingsViewModel(modelContext: modelContext)
                }
                await viewModel?.loadSettings()
            }
        }
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private func settingsContent(viewModel: SettingsViewModel) -> some View {
        Form {
            // Currency Settings
            currencySection(viewModel: viewModel)
            transactionDefaultsSection(viewModel: viewModel)
            
            // Data Summary
            dataSummarySection(viewModel: viewModel)
            
            // Data Management
            dataManagementSection(viewModel: viewModel)
            
            // About
            aboutSection(viewModel: viewModel)
        }
        .confirmationDialog(
            String(localized: "settings.clearData.title", defaultValue: "Clear All Data?"),
            isPresented: $showClearDataConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "settings.clearData.confirm", defaultValue: "Clear All Data"), role: .destructive) {
                Task {
                    do {
                        try await viewModel.clearAllData()
                    } catch {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }
        } message: {
            Text(String(localized: "settings.clearData.message", defaultValue: "This will delete all your accounts, transactions, budgets, and categories. This action cannot be undone."))
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
    
    // MARK: - Transaction Defaults Section
    
    @ViewBuilder
    private func transactionDefaultsSection(viewModel: SettingsViewModel) -> some View {
        Section {
            Picker(
                String(localized: "settings.defaultAccount", defaultValue: "Default Account"),
                selection: Binding(
                    get: { viewModel.defaultAccountId },
                    set: { viewModel.defaultAccountId = $0 }
                )
            ) {
                Text(String(localized: "settings.defaultAccount.none", defaultValue: "None"))
                    .tag(nil as UUID?)
                
                ForEach(accounts.filter { !$0.isArchived }) { account in
                    Text(account.name)
                        .tag(account.id as UUID?)
                }
            }
            
            Toggle(
                String(localized: "settings.rememberLastAccount", defaultValue: "Remember Last Used Account"),
                isOn: Binding(
                    get: { viewModel.rememberLastUsedAccount },
                    set: { viewModel.rememberLastUsedAccount = $0 }
                )
            )
        } header: {
            Text(String(localized: "settings.transactionDefaults", defaultValue: "Transaction Defaults"))
        } footer: {
            Text(String(localized: "settings.rememberLastAccount.footer", defaultValue: "When enabled, Add Transaction opens with your last used account. Otherwise it uses Default Account."))
        }
    }
    
    // MARK: - Currency Section
    
    @ViewBuilder
    private func currencySection(viewModel: SettingsViewModel) -> some View {
        Section(String(localized: "settings.currency", defaultValue: "Currency")) {
            Picker(
                String(localized: "settings.defaultCurrency", defaultValue: "Default Currency"),
                selection: Binding(
                    get: { viewModel.defaultCurrencyCode },
                    set: { viewModel.defaultCurrencyCode = $0 }
                )
            ) {
                ForEach(viewModel.availableCurrencies, id: \.self) { currency in
                    Text("\(currency.symbol) \(currency.rawValue) - \(currency.localizedName)")
                        .tag(currency.rawValue)
                }
            }
        }
    }
    
    // MARK: - Data Summary Section
    
    @ViewBuilder
    private func dataSummarySection(viewModel: SettingsViewModel) -> some View {
        Section(String(localized: "settings.dataSummary", defaultValue: "Data Summary")) {
            dataRow(
                label: String(localized: "settings.accounts", defaultValue: "Accounts"),
                value: "\(viewModel.accountCount)",
                systemImage: "building.columns"
            )
            
            dataRow(
                label: String(localized: "settings.transactions", defaultValue: "Transactions"),
                value: "\(viewModel.transactionCount)",
                systemImage: "arrow.left.arrow.right"
            )
            
            dataRow(
                label: String(localized: "settings.categories", defaultValue: "Categories"),
                value: "\(viewModel.categoryCount)",
                systemImage: "tag"
            )
            
            dataRow(
                label: String(localized: "settings.budgets", defaultValue: "Budgets"),
                value: "\(viewModel.budgetCount)",
                systemImage: "chart.pie"
            )
        }
    }
    
    private func dataRow(label: String, value: String, systemImage: String) -> some View {
        HStack {
            Label(label, systemImage: systemImage)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Data Management Section
    
    @ViewBuilder
    private func dataManagementSection(viewModel: SettingsViewModel) -> some View {
        Section(String(localized: "settings.dataManagement", defaultValue: "Data Management")) {
            // Clear all data
            Button(role: .destructive) {
                showClearDataConfirmation = true
            } label: {
                Label(
                    String(localized: "settings.clearData", defaultValue: "Clear All Data"),
                    systemImage: "trash"
                )
            }
        }
    }
    
    // MARK: - About Section
    
    @ViewBuilder
    private func aboutSection(viewModel: SettingsViewModel) -> some View {
        Section(String(localized: "settings.about", defaultValue: "About")) {
            HStack {
                Text(String(localized: "settings.version", defaultValue: "Version"))
                Spacer()
                Text("\(viewModel.appVersion) (\(viewModel.buildNumber))")
                    .foregroundStyle(.secondary)
            }
            
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "settings.privacy.title", defaultValue: "Privacy First"))
                        .font(.subheadline)
                    Text(String(localized: "settings.privacy.message", defaultValue: "All data stored locally on device. iCloud Sync and premium features coming soon."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(.green)
            }
        }
    }
}

// MARK: - Preview

#Preview("Settings") {
    do {
        let container = try ModelContainerConfiguration.createPreviewContainer()
        return SettingsView()
            .modelContainer(container)
    } catch {
        return Text("Preview Error")
    }
}
