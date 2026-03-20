import SwiftUI
import SwiftData
import UIKit

// MARK: - Settings View

/// App settings including regional preferences and data management
struct SettingsView: View {
    private let autoPopWhenTabSwitch: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SettingsViewModel?
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    
    @State private var showClearDataConfirmation = false
    @State private var showExchangeCalculator = false
    @State private var showTravelCurrencySettings = false
    @State private var showError = false
    @State private var errorMessage = ""

    init(autoPopWhenTabSwitch: Bool = false) {
        self.autoPopWhenTabSwitch = autoPopWhenTabSwitch
    }
    
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
            .navigationTitle(AppLocalization.string("settings.title", defaultValue: "Settings"))
            .task {
                if viewModel == nil {
                    viewModel = SettingsViewModel(modelContext: modelContext)
                }
                await viewModel?.loadSettings()
            }
            .onDisappear {
                guard autoPopWhenTabSwitch else { return }
                DispatchQueue.main.async {
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private func settingsContent(viewModel: SettingsViewModel) -> some View {
        Form {
            // Currency Settings
            currencySection(viewModel: viewModel)
            exchangeRateSection(viewModel: viewModel)
            languageSection(viewModel: viewModel)
            transactionDefaultsSection(viewModel: viewModel)
            remindersSection(viewModel: viewModel)
            reportsSection(viewModel: viewModel)
            
            // Data Summary
            dataSummarySection(viewModel: viewModel)
            
            // Data Management
            dataManagementSection(viewModel: viewModel)
            
            // About
            aboutSection(viewModel: viewModel)
        }
        .alert(
            AppLocalization.string("settings.clearData.title", defaultValue: "Do you want to clear all data?"),
            isPresented: $showClearDataConfirmation,
        ) {
            Button(AppLocalization.string("action.confirm", defaultValue: "Confirm"), role: .destructive) {
                Task {
                    do {
                        try await viewModel.clearAllData()
                    } catch {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }
            Button(AppLocalization.string("action.cancel", defaultValue: "Cancel"), role: .cancel) { }
        } message: {
            Text(AppLocalization.string("settings.clearData.message", defaultValue: "You cannot undo this action."))
        }
        .alert(
            AppLocalization.string("error.title", defaultValue: "Error"),
            isPresented: $showError
        ) {
            Button(AppLocalization.string("action.ok", defaultValue: "OK")) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showExchangeCalculator) {
            ExchangeCalculatorSheet()
        }
        .sheet(isPresented: $showTravelCurrencySettings) {
            TravelCurrencySettingsSheet(viewModel: viewModel)
        }
        .onAppear {
            Task {
                await viewModel.refreshReminderAuthorizationStatus()
            }
        }
    }
    
    // MARK: - Transaction Defaults Section
    
    @ViewBuilder
    private func transactionDefaultsSection(viewModel: SettingsViewModel) -> some View {
        Section {
            Picker(
                AppLocalization.string("settings.defaultAccount", defaultValue: "Default Account"),
                selection: Binding(
                    get: { viewModel.defaultAccountId },
                    set: { viewModel.defaultAccountId = $0 }
                )
            ) {
                Text(AppLocalization.string("settings.defaultAccount.none", defaultValue: "None"))
                    .tag(nil as UUID?)
                
                ForEach(accounts) { account in
                    Text(account.name)
                        .tag(account.id as UUID?)
                }
            }
            
            Toggle(
                AppLocalization.string("settings.rememberLastAccount", defaultValue: "Remember Last Used Account"),
                isOn: Binding(
                    get: { viewModel.rememberLastUsedAccount },
                    set: { viewModel.rememberLastUsedAccount = $0 }
                )
            )
        } header: {
            Text(AppLocalization.string("settings.transactionDefaults", defaultValue: "Transaction Defaults"))
        } footer: {
            Text(AppLocalization.string("settings.rememberLastAccount.footer", defaultValue: "When enabled, Add Transaction opens with your last used account. Otherwise it uses Default Account."))
        }
    }

    @ViewBuilder
    private func reportsSection(viewModel: SettingsViewModel) -> some View {
        Section {
            Picker(
                AppLocalization.string(
                    "settings.reports.categoryRows",
                    defaultValue: "Category Rows"
                ),
                selection: Binding(
                    get: { viewModel.reportsCategoryRowLimit },
                    set: { viewModel.reportsCategoryRowLimit = $0 }
                )
            ) {
                ForEach(ReportsCategoryRowLimitPreference.supportedValues, id: \.self) { rowLimit in
                    Text("\(rowLimit)")
                        .tag(rowLimit)
                }
            }
        } header: {
            Text(AppLocalization.string("settings.reports", defaultValue: "Reports"))
        } footer: {
            Text(
                AppLocalization.string(
                    "settings.reports.categoryRows.footer",
                    defaultValue: "Controls how many category rows are shown by default in Reports before you tap Show more."
                )
            )
        }
    }

    @ViewBuilder
    private func remindersSection(viewModel: SettingsViewModel) -> some View {
        Section {
            HStack {
                Text(AppLocalization.string("settings.reminders.status", defaultValue: "Due Date Reminders"))
                Spacer()
                Text(viewModel.reminderStatusText)
                    .foregroundStyle(.secondary)
            }

            if viewModel.notificationAuthorizationStatus == .notDetermined {
                Button(AppLocalization.string("settings.reminders.enable", defaultValue: "Enable Notifications")) {
                    Task {
                        await viewModel.requestReminderAuthorization()
                    }
                }
            } else if viewModel.notificationAuthorizationStatus == .denied {
                Button(AppLocalization.string("settings.reminders.openSettings", defaultValue: "Open iOS Settings")) {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
            }
        } header: {
            Text(AppLocalization.string("settings.reminders", defaultValue: "Notifications"))
        }
    }
    
    // MARK: - Currency Section
    
    @ViewBuilder
    private func currencySection(viewModel: SettingsViewModel) -> some View {
        Section(AppLocalization.string("settings.currency", defaultValue: "Currency")) {
            Picker(
                AppLocalization.string("settings.defaultCurrency", defaultValue: "Default Currency"),
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

    @ViewBuilder
    private func exchangeRateSection(viewModel: SettingsViewModel) -> some View {
        Section {
            Button {
                showTravelCurrencySettings = true
            } label: {
                HStack {
                    Text(
                        AppLocalization.string(
                            "settings.exchangeRate.configuration",
                            defaultValue: "Travel Currency Mode"
                        )
                    )
                    Spacer()
                    Text(viewModel.travelCurrencySettingSummary)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }

            Button {
                showExchangeCalculator = true
            } label: {
                Text(
                        AppLocalization.string(
                            "settings.exchangeRate.openCalculator",
                            defaultValue: "Exchange Calculator"
                        )
                    )
            }
        } header: {
            Text(
                AppLocalization.string(
                    "settings.exchangeRate.travelSection",
                    defaultValue: "Travel Currency"
                )
            )
        }
    }

    // MARK: - Language Section

    @ViewBuilder
    private func languageSection(viewModel: SettingsViewModel) -> some View {
        Section {
            Picker(
                AppLocalization.string("settings.defaultLanguage", defaultValue: "App Language"),
                selection: Binding(
                    get: {
                        viewModel.appLanguage == .system
                            ? .traditionalChinese
                            : viewModel.appLanguage
                    },
                    set: { viewModel.appLanguage = $0 }
                )
            ) {
                ForEach(AppLanguage.allCases.filter { $0 != .system }) { language in
                    Text(language.displayName)
                        .tag(language)
                }
            }
        } header: {
            Text(AppLocalization.string("settings.language", defaultValue: "Language"))
        } footer: {
            Text(AppLocalization.string("settings.language.footer", defaultValue: "Choose the language used by the app interface."))
        }
    }

    // MARK: - Data Summary Section
    
    @ViewBuilder
    private func dataSummarySection(viewModel: SettingsViewModel) -> some View {
        Section(AppLocalization.string("settings.dataSummary", defaultValue: "Data Summary")) {
            dataRow(
                label: AppLocalization.string("settings.accounts", defaultValue: "Accounts"),
                value: "\(viewModel.accountCount)",
                systemImage: "building.columns"
            )
            
            dataRow(
                label: AppLocalization.string("settings.transactions", defaultValue: "Transactions"),
                value: "\(viewModel.transactionCount)",
                systemImage: "arrow.left.arrow.right"
            )
            
            dataRow(
                label: AppLocalization.string("settings.categories", defaultValue: "Categories"),
                value: "\(viewModel.categoryCount)",
                systemImage: "tag"
            )
            
            dataRow(
                label: AppLocalization.string("settings.budgets", defaultValue: "Budgets"),
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
        Section(AppLocalization.string("settings.dataManagement", defaultValue: "Data Management")) {
            // Clear all data
            Button(role: .destructive) {
                showClearDataConfirmation = true
            } label: {
                Text(AppLocalization.string("settings.clearData", defaultValue: "Clear All Data"))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
    
    // MARK: - About Section
    
    @ViewBuilder
    private func aboutSection(viewModel: SettingsViewModel) -> some View {
        Section(AppLocalization.string("settings.about", defaultValue: "About")) {
            HStack {
                Text(AppLocalization.string("settings.version", defaultValue: "Version"))
                Spacer()
                Text("\(viewModel.appVersion) (\(viewModel.buildNumber))")
                    .foregroundStyle(.secondary)
            }
            
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppLocalization.string("settings.privacy.title", defaultValue: "Privacy First"))
                        .font(.subheadline)
                    Text(AppLocalization.string("settings.privacy.message", defaultValue: "All data stored locally on device. iCloud Sync and premium features coming soon."))
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

private struct TravelCurrencySettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(
                        AppLocalization.string(
                            "settings.exchangeRate.configuration",
                            defaultValue: "Travel Currency Mode"
                        ),
                        selection: Binding(
                            get: { viewModel.travelCurrencySource },
                            set: { newSource in
                                Task {
                                    await viewModel.setTravelCurrencySource(newSource)
                                }
                            }
                        )
                    ) {
                        Text(
                            AppLocalization.string(
                                "settings.exchangeRate.configuration.automatic",
                                defaultValue: "Automatic"
                            )
                        )
                        .tag(TravelCurrencySource.automatic)

                        Text(
                            AppLocalization.string(
                                "settings.exchangeRate.configuration.manual",
                                defaultValue: "Manual"
                            )
                        )
                        .tag(TravelCurrencySource.manual)
                    }

                    HStack {
                        Text(
                            AppLocalization.string(
                                "settings.exchangeRate.detectedCurrency",
                                defaultValue: "Detected Currency"
                            )
                        )
                        Spacer()
                        Text(
                            viewModel.detectedLocationCurrencyCode
                                ?? AppLocalization.string(
                                    "settings.exchangeRate.detectedCurrency.none",
                                    defaultValue: "Not Detected"
                                )
                        )
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text(
                            AppLocalization.string(
                                "settings.exchangeRate.currentTravelCurrency",
                                defaultValue: "Current Travel Currency"
                            )
                        )
                        Spacer()
                        Text(
                            viewModel.currentTravelCurrencyCode
                                ?? AppLocalization.string(
                                    "settings.exchangeRate.currentTravelCurrency.none",
                                    defaultValue: "Inactive"
                                )
                        )
                            .foregroundStyle(.secondary)
                    }

                    if viewModel.travelCurrencySource == .manual {
                        Picker(
                            AppLocalization.string(
                                "settings.exchangeRate.manualTravelCurrency",
                                defaultValue: "Selected Travel Currency"
                            ),
                            selection: Binding(
                                get: { viewModel.manualTravelCurrencyCode },
                                set: { viewModel.setManualTravelCurrencyCode($0) }
                            )
                        ) {
                            Text(
                                AppLocalization.string(
                                    "settings.exchangeRate.manualTravelCurrency.placeholder",
                                    defaultValue: "Select Currency"
                                )
                            )
                            .tag(String?.none)

                            ForEach(viewModel.availableTravelCurrencies, id: \.self) { currency in
                                Text("\(currency.symbol) \(currency.rawValue) - \(currency.localizedName)")
                                    .tag(Optional(currency.rawValue))
                            }
                        }
                    }
                } footer: {
                    Text(
                        AppLocalization.string(
                            "settings.exchangeRate.configuration.footer",
                            defaultValue: "Automatic mode follows your current location. Manual mode stays active until you switch back."
                        )
                    )
                }
            }
            .navigationTitle(
                AppLocalization.string(
                    "settings.exchangeRate.configuration",
                    defaultValue: "Travel Currency Mode"
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                }
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
