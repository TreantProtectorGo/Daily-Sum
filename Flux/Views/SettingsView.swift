import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

// MARK: - Settings View

/// App settings including regional preferences and data management
struct SettingsView: View {
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
    @State private var showBackupExporter = false
    @State private var backupArchiveDocument: BackupArchiveDocument?
    @State private var showRestoreImporter = false
    @State private var pendingBackupRestoreData: Data?

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
        .fileExporter(
            isPresented: $showBackupExporter,
            document: backupArchiveDocument,
            contentType: .json,
            defaultFilename: backupExportFilename(for: viewModel)
        ) { result in
            if case let .failure(error) = result {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
        .fileImporter(
            isPresented: $showRestoreImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleRestoreImport(result, viewModel: viewModel)
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
        } header: {
            Text(AppLocalization.string("settings.reminders", defaultValue: "Notifications"))
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
    private func dataContinuitySection(viewModel: SettingsViewModel) -> some View {
        Section(AppLocalization.string("settings.dataContinuity", defaultValue: "Sync & Backup")) {
            LabeledContent(
                AppLocalization.string("settings.cloudSync", defaultValue: "iCloud Sync")
            ) {
                Text(viewModel.cloudSyncStatusTitle)
                    .foregroundStyle(viewModel.cloudSyncRequiresAttention ? .orange : .secondary)
                    .accessibilityIdentifier("settings.cloudSync.status")
            }

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
            .disabled(viewModel.cloudSyncRequiresAttention)
            .accessibilityIdentifier("settings.cloudSync.toggle")

            Text(viewModel.cloudSyncStatusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                prepareBackupExport(viewModel: viewModel)
            } label: {
                Text(AppLocalization.string("settings.backup.export", defaultValue: "Back Up Now"))
            }
            .accessibilityIdentifier("settings.backup.export.button")

            if let summary = viewModel.backupExportSummaryText {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Menu {
                ForEach(BackupRestoreMode.allCases, id: \.self) { mode in
                    Button(backupRestoreModeTitle(mode)) {
                        viewModel.setBackupRestoreMode(mode)
                    }
                }
            } label: {
                settingsSelectionRow(
                    title: AppLocalization.string(
                        "settings.backup.restore.mode",
                        defaultValue: "Restore Mode"
                    ),
                    value: backupRestoreModeTitle(viewModel.selectedBackupRestoreMode)
                )
            }
            .accessibilityIdentifier("settings.backup.restore.mode")

            Menu {
                ForEach(BackupRestoreScope.allCases, id: \.self) { scope in
                    Button(backupRestoreScopeTitle(scope)) {
                        viewModel.setBackupRestoreScope(scope)
                    }
                }
            } label: {
                settingsSelectionRow(
                    title: AppLocalization.string(
                        "settings.backup.restore.scope",
                        defaultValue: "Restore Scope"
                    ),
                    value: backupRestoreScopeTitle(viewModel.selectedBackupRestoreScope)
                )
            }
            .accessibilityIdentifier("settings.backup.restore.scope")

            Button {
                showRestoreImporter = true
            } label: {
                Text(
                    AppLocalization.string(
                        "settings.backup.restore.action",
                        defaultValue: "Restore from Backup"
                    )
                )
            }
            .accessibilityIdentifier("settings.backup.restore.button")

            if let summary = viewModel.backupRestorePreviewSummaryText,
               pendingBackupRestoreData != nil {
                VStack(alignment: .leading, spacing: 6) {
                    Text(
                        AppLocalization.string(
                            "settings.backup.restore.preview",
                            defaultValue: "Restore Preview"
                        )
                    )
                    .font(.subheadline.weight(.semibold))

                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("settings.backup.preview.summary")

                    Button(
                        AppLocalization.string(
                            "settings.backup.restore.confirm",
                            defaultValue: "Confirm Restore"
                        )
                    ) {
                        applyPreparedRestore(viewModel: viewModel)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            if let summary = viewModel.appliedBackupImportSummaryText {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("settings.backup.import.summary")
            }
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
            
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppLocalization.string("settings.privacy.title", defaultValue: "Privacy First"))
                        .font(.subheadline)
                    Text(AppLocalization.string("settings.privacy.message", defaultValue: "Data stays local-first, with optional iCloud sync and manual backup restore controls."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(.green)
            }
        }
    }

    private func settingsSelectionRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    private func backupRestoreModeTitle(_ mode: BackupRestoreMode) -> String {
        switch mode {
        case .replace:
            AppLocalization.string("settings.backup.restore.mode.replace", defaultValue: "Replace")
        case .merge:
            AppLocalization.string("settings.backup.restore.mode.merge", defaultValue: "Merge")
        }
    }

    private func backupRestoreScopeTitle(_ scope: BackupRestoreScope) -> String {
        switch scope {
        case .financialDataOnly:
            AppLocalization.string("settings.backup.restore.scope.financialOnly", defaultValue: "Financial Data Only")
        case .financialDataAndCrossDevicePreferences:
            AppLocalization.string(
                "settings.backup.restore.scope.crossDevice",
                defaultValue: "Financial Data + Cross-Device Preferences"
            )
        case .financialDataAndAllPreferences:
            AppLocalization.string(
                "settings.backup.restore.scope.allPreferences",
                defaultValue: "Financial Data + All Preferences"
            )
        }
    }

    private func prepareBackupExport(viewModel: SettingsViewModel) {
        viewModel.prepareBackupExport()

        if let error = viewModel.backupExportErrorMessage {
            errorMessage = error
            showError = true
            return
        }

        guard let archive = viewModel.preparedBackupArchive else {
            return
        }

        do {
            backupArchiveDocument = try BackupArchiveDocument(archive: archive)
            showBackupExporter = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func handleRestoreImport(
        _ result: Result<[URL], Error>,
        viewModel: SettingsViewModel
    ) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }
            let didAccessResource = url.startAccessingSecurityScopedResource()
            defer {
                if didAccessResource {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let data = try Data(contentsOf: url)
                pendingBackupRestoreData = data
                viewModel.prepareBackupRestorePreview(
                    from: data,
                    mode: viewModel.selectedBackupRestoreMode,
                    scope: viewModel.selectedBackupRestoreScope
                )

                if let error = viewModel.backupRestorePreviewErrorMessage {
                    pendingBackupRestoreData = nil
                    errorMessage = error
                    showError = true
                }
            } catch {
                pendingBackupRestoreData = nil
                errorMessage = error.localizedDescription
                showError = true
            }
        case let .failure(error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func applyPreparedRestore(viewModel: SettingsViewModel) {
        guard let pendingBackupRestoreData else { return }

        viewModel.applyBackupRestore(
            from: pendingBackupRestoreData,
            mode: viewModel.selectedBackupRestoreMode,
            scope: viewModel.selectedBackupRestoreScope
        )

        if let error = viewModel.backupRestoreApplyErrorMessage {
            errorMessage = error
            showError = true
            return
        }

        self.pendingBackupRestoreData = nil
    }

    private func backupExportFilename(for viewModel: SettingsViewModel) -> String {
        guard let archive = viewModel.preparedBackupArchive else {
            return "Flux-Backup"
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return "Flux-Backup-\(formatter.string(from: archive.exportedAt))"
    }

}

private struct BackupArchiveDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(archive: BackupArchive) throws {
        self.data = try BackupArchiveCodec.encode(archive)
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
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
