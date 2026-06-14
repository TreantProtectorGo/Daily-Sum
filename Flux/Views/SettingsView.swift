import SwiftUI
import SwiftData
import UIKit

// MARK: - Settings View

/// App settings including regional preferences and data management
struct SettingsView: View {
    private static let privacyPolicyURL = URL(string: "https://treantprotectorgo.github.io/flux-privacy-policy/")!

    private let autoPopWhenTabSwitch: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SettingsViewModel?
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    
    @State private var showClearDataConfirmation = false
    @State private var showExchangeCalculator = false
    @State private var showTravelCurrencySettings = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showBackupSheet = false

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
            optionsSection(viewModel: viewModel)
            themeSection(viewModel: viewModel)
            transactionDefaultsSection(viewModel: viewModel)
            
            // Data Summary
            dataSummarySection(viewModel: viewModel)

            // Sync, Backup, Restore
            dataContinuitySection(viewModel: viewModel)
            
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
            Button("Keep Data", role: .cancel) { }
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
        .sheet(isPresented: $showBackupSheet) {
            ManagedBackupSheet(viewModel: viewModel)
        }
        .onAppear {
            Task {
                await viewModel.refreshReminderAuthorizationStatus()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await viewModel.refreshReminderAuthorizationStatus()
                await viewModel.refreshTravelCurrencyState()
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
            .tint(AppColors.interactiveText)
            
            Toggle(
                AppLocalization.string("settings.rememberLastAccount", defaultValue: "Remember Last Used Account"),
                isOn: Binding(
                    get: { viewModel.rememberLastUsedAccount },
                    set: { viewModel.rememberLastUsedAccount = $0 }
                )
            )
            .tint(AppColors.interactiveText)

            Toggle(
                AppLocalization.string(
                    "settings.autoOpenAccountAfterCategory",
                    defaultValue: "Auto-Open Account After Category"
                ),
                isOn: Binding(
                    get: { viewModel.autoPresentAccountAfterCategorySelection },
                    set: { viewModel.autoPresentAccountAfterCategorySelection = $0 }
                )
            )
            .tint(AppColors.interactiveText)
        } header: {
            Text(AppLocalization.string("settings.transactionDefaults", defaultValue: "Transaction Defaults"))
        } footer: {
            Text(
                AppLocalization.string(
                    "settings.transactionDefaults.footer",
                    defaultValue: "Remember Last Used Account is on by default. Turn on Auto-Open Account After Category if you want the account picker to open immediately after choosing a category."
                )
            )
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
    
    // MARK: - Currency Section
    
    @ViewBuilder
    private func currencySection(viewModel: SettingsViewModel) -> some View {
        Section(AppLocalization.string("settings.currency", defaultValue: "Currency")) {
            defaultCurrencyMenu(viewModel: viewModel)
            Button {
                showTravelCurrencySettings = true
            } label: {
                HStack {
                    Text(
                        AppLocalization.string(
                            "settings.exchangeRate.configuration",
                            defaultValue: "Foreign Currency Mode"
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
            .foregroundStyle(AppColors.interactiveText)

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
            .foregroundStyle(AppColors.interactiveText)
        }
    }

    private func defaultCurrencyMenu(viewModel: SettingsViewModel) -> some View {
        HStack(spacing: 12) {
            Text(AppLocalization.string("settings.defaultCurrency.short", defaultValue: "Default"))
                .lineLimit(1)

            Spacer(minLength: 8)

            Menu {
                ForEach(viewModel.availableCurrencies, id: \.self) { currency in
                    Button {
                        viewModel.defaultCurrencyCode = currency.rawValue
                    } label: {
                        if currency.rawValue == viewModel.defaultCurrencyCode {
                            Label(currencyPickerTitle(currency), systemImage: "checkmark")
                        } else {
                            Text(currencyPickerTitle(currency))
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    if let selectedCurrency = SupportedCurrency(rawValue: viewModel.defaultCurrencyCode) {
                        currencyPickerLabel(selectedCurrency)
                    } else {
                        Text(viewModel.defaultCurrencyCode)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    Image(systemName: "chevron.up.chevron.down")
                        .imageScale(.small)
                }
                .foregroundStyle(AppColors.interactiveText)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .menuOrder(.fixed)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(AppLocalization.string("settings.defaultCurrency", defaultValue: "Default Currency"))
        .accessibilityValue(viewModel.defaultCurrencyCode)
    }

    // MARK: - Options Section

    @ViewBuilder
    private func optionsSection(viewModel: SettingsViewModel) -> some View {
        Section {
            appLanguagePicker(viewModel: viewModel)
            defaultLaunchPagePicker(viewModel: viewModel)
            allNotificationsToggle(viewModel: viewModel)
            categoryRowsPicker(viewModel: viewModel)
        } header: {
            Text(AppLocalization.string("settings.options", defaultValue: "Options"))
        }
    }

    @ViewBuilder
    private func themeSection(viewModel: SettingsViewModel) -> some View {
        Section {
            Picker(
                AppLocalization.string("settings.theme", defaultValue: "Appearance"),
                selection: Binding(
                    get: { viewModel.appTheme },
                    set: { viewModel.appTheme = $0 }
                )
            ) {
                ForEach(AppTheme.allCases) { theme in
                    Label(theme.displayName, systemImage: theme.systemImage)
                        .tag(theme)
                }
            }
            .pickerStyle(.segmented)
            .tint(AppColors.interactiveText)
            .accessibilityIdentifier("settings.theme.picker")
        } header: {
            Text(AppLocalization.string("settings.theme", defaultValue: "Appearance"))
        }
    }

    private func appLanguagePicker(viewModel: SettingsViewModel) -> some View {
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
        .tint(AppColors.interactiveText)
    }

    private func defaultLaunchPagePicker(viewModel: SettingsViewModel) -> some View {
        Picker(
            AppLocalization.string("settings.defaultLaunchPage", defaultValue: "Default Page"),
            selection: Binding(
                get: { viewModel.appLaunchTab },
                set: { viewModel.appLaunchTab = $0 }
            )
        ) {
            ForEach(viewModel.availableLaunchTabs) { tab in
                Label(tab.title, systemImage: tab.icon)
                    .tag(tab)
            }
        }
        .tint(AppColors.interactiveText)
        .accessibilityIdentifier("settings.defaultLaunchPage.picker")
    }

    private func allNotificationsToggle(viewModel: SettingsViewModel) -> some View {
        Toggle(
            AppLocalization.string("settings.reminders.status", defaultValue: "All Notifications"),
            isOn: Binding(
                get: { viewModel.allNotificationsEnabled },
                set: { isEnabled in
                    Task {
                        let action = await viewModel.setAllNotificationsEnabled(isEnabled)
                        if action == .openSystemSettings {
                            openSystemSettings()
                        }
                    }
                }
            )
        )
        .tint(AppColors.interactiveText)
    }

    private func categoryRowsPicker(viewModel: SettingsViewModel) -> some View {
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
        .tint(AppColors.interactiveText)
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
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(AppColors.mutedDataIcon)
                    .frame(width: 20, alignment: .center)

                Text(label)
            }
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Data Management Section

    @ViewBuilder
    private func dataContinuitySection(viewModel: SettingsViewModel) -> some View {
        let cloudSyncRequiresAttention = viewModel.cloudSyncRequiresAttention

        Section(AppLocalization.string("settings.dataContinuity", defaultValue: "Sync & Backup")) {
            Toggle(
                AppLocalization.string(
                    "settings.cloudSync.enable",
                    defaultValue: "Enable iCloud Sync"
                ),
                isOn: Binding(
                    get: { viewModel.isCloudSyncEnabled },
                    set: { viewModel.isCloudSyncEnabled = $0 }
                )
            )
            .tint(AppColors.interactiveText)
            .disabled(cloudSyncRequiresAttention)
            .opacity(cloudSyncRequiresAttention ? 0.5 : 1)
            .saturation(cloudSyncRequiresAttention ? 0 : 1)
            .accessibilityIdentifier("settings.cloudSync.toggle")

            Text(viewModel.cloudSyncStatusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("settings.cloudSync.message")

            Picker(
                AppLocalization.string(
                    "settings.backup.automatic",
                    defaultValue: "Automatic Backup"
                ),
                selection: Binding(
                    get: { viewModel.automaticBackupFrequency },
                    set: { viewModel.automaticBackupFrequency = $0 }
                )
            ) {
                ForEach(AutomaticBackupFrequency.allCases) { frequency in
                    Text(frequency.localizedTitle)
                        .tag(frequency)
                }
            }
            .tint(AppColors.interactiveText)
            .accessibilityIdentifier("settings.backup.automatic.picker")

            Picker(
                AppLocalization.string(
                    "settings.backup.retention",
                    defaultValue: "Keep Backups"
                ),
                selection: Binding(
                    get: { viewModel.backupRetentionLimit },
                    set: { viewModel.backupRetentionLimit = $0 }
                )
            ) {
                ForEach(BackupRetentionLimit.allCases) { limit in
                    Text(limit.localizedTitle)
                        .tag(limit)
                }
            }
            .tint(AppColors.interactiveText)
            .accessibilityIdentifier("settings.backup.retention.picker")

            Button {
                showBackupSheet = true
            } label: {
                Text(
                    AppLocalization.string(
                        "settings.backup.action",
                        defaultValue: "Backup"
                    )
                )
            }
            .foregroundStyle(AppColors.interactiveText)
            .accessibilityIdentifier("settings.backup.sheet.button")

            Text(
                AppLocalization.string(
                    "settings.backup.restore.behavior",
                    defaultValue: "Create iCloud Drive backups or restore from an existing backup. Restore replaces current financial data and restores all included preferences."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("settings.backup.restore.behavior")
        }
    }

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

            Link(destination: Self.privacyPolicyURL) {
                HStack {
                    Text(
                        AppLocalization.string(
                            "settings.privacyPolicy.title",
                            defaultValue: "Privacy Policy"
                        )
                    )
                    Spacer()
                    Image(systemName: "arrow.up.forward")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .foregroundStyle(AppColors.interactiveText)
            .accessibilityIdentifier("settings.privacyPolicy.link")
        }
    }

}

private struct ManagedBackupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: SettingsViewModel
    @State private var showRestoreConfirmation = false
    @State private var restoreErrorMessage: String?
    @State private var showRestoreError = false
    @State private var isBackupButtonCoolingDown = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        createManagedBackup()
                    } label: {
                        Text(
                            AppLocalization.string(
                                "settings.backup.export",
                                defaultValue: "Back Up Now"
                            )
                        )
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isBackupButtonDisabled ? Color.secondary : AppColors.primary)
                    .disabled(isBackupButtonDisabled)
                    .accessibilityIdentifier("settings.backup.export.button")

                    if viewModel.isPreparingBackupExport {
                        ProgressView()
                    }

                    if let error = viewModel.backupExportErrorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("settings.backup.export.error")
                    }
                } footer: {
                    Text(
                        AppLocalization.string(
                            "settings.backup.footer",
                            defaultValue: "Backups are saved to iCloud Drive when available, otherwise to this device."
                        )
                    )
                }

                Section(
                    AppLocalization.string(
                        "settings.backup.list.title",
                        defaultValue: "Backups"
                    )
                ) {
                    if viewModel.isLoadingBackupFiles {
                        ProgressView()
                    } else if let error = viewModel.backupFileListErrorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("settings.backup.list.error")
                    } else if viewModel.backupFiles.isEmpty {
                        Text(
                            AppLocalization.string(
                                "settings.backup.list.empty.message",
                                defaultValue: "Tap Back Up Now to create your first backup."
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("settings.backup.list.empty.message")
                    } else {
                        ForEach(viewModel.backupFiles) { backup in
                            Button {
                                prepareRestoreConfirmation(for: backup)
                            } label: {
                                BackupFileRow(backup: backup)
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.isPreparingBackupRestorePreview || viewModel.isApplyingBackupRestore)
                            .accessibilityIdentifier("settings.backup.list.row")
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    viewModel.deleteManagedBackup(backup)
                                } label: {
                                    Label(
                                        AppLocalization.string("action.delete", defaultValue: "Delete"),
                                        systemImage: "trash"
                                    )
                                }
                                .accessibilityIdentifier("settings.backup.delete.button")
                                .tint(.red)
                            }
                        }
                    }
                }

                if viewModel.isPreparingBackupRestorePreview {
                    Section {
                        ProgressView()
                    }
                }

                if let summary = viewModel.appliedBackupImportSummaryText {
                    Section(
                        AppLocalization.string(
                            "settings.backup.restore.result",
                            defaultValue: "Restore Result"
                        )
                    ) {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("settings.backup.import.summary")
                    }
                }
            }
            .navigationTitle(
                AppLocalization.string(
                    "settings.backup.title",
                    defaultValue: "Backup"
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    IconToolbarButton(systemName: "xmark", accessibilityLabel: AppLocalization.string("action.close", defaultValue: "Close")) {
                        dismiss()
                    }
                    .accessibilityIdentifier("settings.backup.close.button")
                }
            }
            .task {
                viewModel.loadBackupFiles()
            }
            .alert(
                AppLocalization.string(
                    "settings.backup.restore.confirm.title",
                    defaultValue: "Restore Backup?"
                ),
                isPresented: $showRestoreConfirmation,
            ) {
                Button("Keep Current Data", role: .cancel) { }

                Button(
                    AppLocalization.string(
                        "settings.backup.restore.confirm",
                        defaultValue: "Confirm Restore"
                    ),
                    role: .destructive
                ) {
                    applyPreparedRestore()
                }
                .accessibilityIdentifier("settings.backup.restore.confirm.button")
            } message: {
                Text(
                    AppLocalization.string(
                        "settings.backup.restore.confirm.message",
                        defaultValue: "Restore replaces current financial data and restores the preferences included in this backup."
                    )
                )
            }
            .alert(
                AppLocalization.string("error.title", defaultValue: "Error"),
                isPresented: $showRestoreError
            ) {
                Button(AppLocalization.string("action.ok", defaultValue: "OK")) { }
            } message: {
                Text(restoreErrorMessage ?? "")
            }
        }
    }

    private func createManagedBackup() {
        guard !isBackupButtonCoolingDown else { return }

        isBackupButtonCoolingDown = true
        viewModel.createManagedBackup()

        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                isBackupButtonCoolingDown = false
            }
        }
    }

    private var isBackupButtonDisabled: Bool {
        viewModel.isPreparingBackupExport || isBackupButtonCoolingDown
    }

    private func prepareRestoreConfirmation(for backup: BackupFileSummary) {
        guard viewModel.prepareManagedBackupRestoreConfirmation(from: backup) else {
            restoreErrorMessage = viewModel.backupRestorePreviewErrorMessage
            showRestoreError = restoreErrorMessage != nil
            return
        }

        showRestoreConfirmation = true
    }

    private func applyPreparedRestore() {
        viewModel.applyPreparedManagedBackupRestore()

        guard let error = viewModel.backupRestoreApplyErrorMessage else { return }
        restoreErrorMessage = error
        showRestoreError = true
    }
}

private struct BackupFileRow: View {
    let backup: BackupFileSummary

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(displayTitle)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(displaySubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityIdentifier("settings.backup.list.row.disclosure")
        }
        .padding(.vertical, 4)
    }

    private var displayTitle: String {
        displayFormatter.title(for: backup)
    }

    private var displaySubtitle: String {
        displayFormatter.subtitle(for: backup)
    }

    private var displayFormatter: BackupFileDisplayFormatter {
        BackupFileDisplayFormatter()
    }
}

private func currencyPickerTitle(_ currency: SupportedCurrency) -> String {
    "\(currency.symbol) \(currency.rawValue) - \(currency.localizedName)"
}

private func currencyPickerLabel(_ currency: SupportedCurrency) -> some View {
    Text(currencyPickerTitle(currency))
        .lineLimit(1)
        .truncationMode(.tail)
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
                            defaultValue: "Foreign Currency Mode"
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
                    .tint(AppColors.interactiveText)

                    HStack {
                        Text(
                            AppLocalization.string(
                                "settings.exchangeRate.detectedCurrency",
                                defaultValue: "Detected Currency"
                            )
                        )
                        Spacer()
                        Text(viewModel.detectedLocationCurrencyDisplayText)
                            .foregroundStyle(.secondary)
                    }

                    if viewModel.travelCurrencySource == .automatic {
                        Button {
                            Task {
                                await viewModel.requestTravelCurrencyLocationUpdate()
                            }
                        } label: {
                            Text(
                                AppLocalization.string(
                                    "settings.exchangeRate.refreshLocation",
                                    defaultValue: "Use Location to Update"
                                )
                            )
                        }
                        .foregroundStyle(AppColors.interactiveText)
                    }

                    HStack {
                        Text(
                            AppLocalization.string(
                                "settings.exchangeRate.currentTravelCurrency",
                                defaultValue: "Current Foreign Currency"
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
                                defaultValue: "Selected Foreign Currency"
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
                                currencyPickerLabel(currency)
                                    .tag(Optional(currency.rawValue))
                            }
                        }
                        .tint(AppColors.interactiveText)
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
                    defaultValue: "Foreign Currency Mode"
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    IconToolbarButton(systemName: "checkmark", accessibilityLabel: "Finish") {
                        dismiss()
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
