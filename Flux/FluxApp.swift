//
//  FluxApp.swift
//  Flux
//
//  Created by Wing - on 9/2/2026.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct FluxApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var container: ModelContainer?
    @State private var containerGeneration = 0
    @State private var isLoading = true
    @State private var loadError: Error?
    @State private var expenseCategoryMaintenanceTask: Task<Void, Never>?
    @AppStorage(AppLanguagePreference.storageKey) private var appLanguageCode = AppLanguage.system.rawValue
    @AppStorage(AppThemePreference.storageKey) private var appThemeCode = AppTheme.system.rawValue
    private let cloudSyncSettingsStore: any CloudSyncSettingsStoring
    private let activationMaintenancePolicy: AppActivationMaintenancePolicy

    init() {
        self.cloudSyncSettingsStore = CloudSyncSettingsStore()
        self.activationMaintenancePolicy = AppActivationMaintenancePolicy()
        UNUserNotificationCenter.current().delegate = ForegroundNotificationPresentationDelegate.shared
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    ContentView()
                        .id(containerGeneration)
                        .modelContainer(container)
                        .environment(\.regionalSettings, RegionalSettings.shared)
                        .environment(\.locale, appLocale)
                } else if let error = loadError {
                    ErrorView(error: error)
                } else {
                    LoadingView()
                }
            }
            .task {
                await initializeApp()
            }
            .onReceive(NotificationCenter.default.publisher(for: CloudSyncSettingsStore.didChangeNotification)) { _ in
                Task {
                    await reloadModelContainerForCloudSyncChange()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: AppModelReload.requestedNotification)) { _ in
                Task {
                    await initializeApp()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active, let container else { return }
                Task { @MainActor in
                    // CloudKit can deliver legacy categories or occurrences after startup. Their
                    // idempotent upgrades must not inherit the heavier 15-minute throttle.
                    maintainExpenseCategories(in: container)
                    await refreshTravelCurrencyPreferenceIfNeeded()
                    guard activationMaintenancePolicy.claimRun() else { return }
                    try? await activationMaintenancePolicy.waitForInteractionGracePeriod()
                    await refreshScheduledTransactionsAndReminders(in: container)
                    runAutomaticBackupIfNeeded(in: container)
                }
            }
            .preferredColorScheme(AppTheme.from(rawValue: appThemeCode).preferredColorScheme)
        }
    }

    private var appLocale: Locale {
        let selectedLanguage = AppLanguage.from(rawValue: appLanguageCode)
        if let localeIdentifier = selectedLanguage.localeIdentifier {
            return Locale(identifier: localeIdentifier)
        }
        return .autoupdatingCurrent
    }

    private var isRunningTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        if environment["XCTestConfigurationFilePath"] != nil { return true }
        if environment["XCInjectBundleInto"] != nil { return true }
        if environment["XCTestBundlePath"] != nil { return true }
        return NSClassFromString("XCTestCase") != nil
    }
    
    /// Initializes the app's data layer
    private func initializeApp() async {
        do {
            if let fixtureContainer = try UITestFixture.makeContainerIfRequested() {
                containerGeneration += 1
                container = fixtureContainer
                isLoading = false
                return
            }
        } catch {
            loadError = error
            isLoading = false
            return
        }

        if isRunningTests {
            isLoading = false
            return
        }

        let previousContainer = container
        expenseCategoryMaintenanceTask?.cancel()
        expenseCategoryMaintenanceTask = nil
        isLoading = true
        loadError = nil

        do {
            // Create and seed the model container
            let enableCloudKit = cloudSyncSettingsStore.status == .enabled
            let newContainer = try await ModelContainer.createAndSeed(enableCloudKit: enableCloudKit)
            _ = RestoreSessionStartupRecovery.consumeMarkerIfPresent()
            containerGeneration += 1
            container = newContainer

            isLoading = false
            maintainExpenseCategories(in: newContainer)
            scheduleExpenseCategoryMaintenanceRetries(in: newContainer)

            if let container {
                activationMaintenancePolicy.recordRun()
                Task { @MainActor in
                    await refreshTravelCurrencyPreferenceIfNeeded()
                    try? await activationMaintenancePolicy.waitForInteractionGracePeriod()
                    await requestNotificationAuthorizationIfNeeded(in: container)
                    await refreshScheduledTransactionsAndReminders(in: container)
                    await refreshExchangeRatesIfNeeded(in: container)
                    runAutomaticBackupIfNeeded(in: container)
                }
            }
            
        } catch {
            container = previousContainer
            loadError = previousContainer == nil ? error : nil
            isLoading = false
        }
    }

    private func reloadModelContainerForCloudSyncChange() async {
        await initializeApp()
    }

    @MainActor
    private func refreshTravelCurrencyPreferenceIfNeeded() async {
        let refresher = TravelCurrencyPreferenceRefresher()
        await refresher.refreshDetectedTravelCurrency()
    }

    @MainActor
    private func refreshExchangeRatesIfNeeded(in container: ModelContainer) async {
        let scheduler = ExchangeRateRefreshScheduler()
        do {
            _ = try await scheduler.refreshLatestRatesIfNeeded(
                context: container.mainContext,
                baseCurrencyCode: UserCurrencyPreference.resolvedCurrencyCode
            )
        } catch {
            // Keep startup resilient even when rate refresh fails (e.g. offline).
            print("Exchange rate refresh failed: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func runAutomaticBackupIfNeeded(in container: ModelContainer) {
        let scheduler = AutomaticBackupScheduler(context: container.mainContext)
        scheduler.runIfNeeded()
    }

    /// Idempotently handles legacy categories and occurrences that arrive after launch through
    /// CloudKit. Posting state is upgraded before any subsequent generation/reminder resync.
    @MainActor
    private func maintainExpenseCategories(in container: ModelContainer) {
        let maintenanceContext = ModelContext(container)
        maintenanceContext.autosaveEnabled = false
        do {
            let postingStatusChanged = try ScheduledPostingStatusMigration
                .runVersionedUpgradeIfNeeded(
                    in: maintenanceContext,
                    saveChanges: false
                )
            let expenseCategoriesChanged = try ExpenseCategoryMigration.normalizeLegacySystemCategories(
                in: maintenanceContext
            )
            if postingStatusChanged || expenseCategoriesChanged {
                try maintenanceContext.save()
            }
        } catch {
            maintenanceContext.rollback()
            print("Expense category maintenance failed: \(error.localizedDescription)")
        }
    }

    /// SwiftData does not expose an initial CloudKit-import completion signal through this
    /// repository's current data-layer abstraction. These bounded retries cover common late
    /// arrivals; subsequent foreground activations provide another idempotent opportunity.
    @MainActor
    private func scheduleExpenseCategoryMaintenanceRetries(in container: ModelContainer) {
        expenseCategoryMaintenanceTask?.cancel()
        expenseCategoryMaintenanceTask = Task { @MainActor in
            for delay in [Duration.seconds(2), .seconds(8), .seconds(20)] {
                do {
                    try await Task.sleep(for: delay)
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                maintainExpenseCategories(in: container)
                // A late CloudKit occurrence is upgraded above before generation inspects its
                // original slot and reminders are rebuilt.
                await refreshScheduledTransactionsAndReminders(in: container)
            }
        }
    }

    @MainActor
    private func requestNotificationAuthorizationIfNeeded(in container: ModelContainer) async {
        let status = await UNUserNotificationCenter.current().authorizationStatusValue()
        guard NotificationAuthorizationStartupPolicy.shouldRequestOnAppLaunch(for: status) else {
            return
        }

        let scheduler = TransactionReminderScheduler(context: container.mainContext)
        _ = try? await scheduler.requestAuthorizationIfNeeded()
    }

    @MainActor
    private func refreshScheduledTransactionsAndReminders(in container: ModelContainer) async {
        do {
            let service = TransactionService(context: container.mainContext)
            try await service.purgeAllInstallmentDataIfNeeded()
            // Upgrade legacy future occurrences before generation examines existing dates and
            // before reminder resync decides which transactions need confirmation notifications.
            try ScheduledPostingStatusMigration.runVersionedUpgradeIfNeeded(
                in: container.mainContext
            )
            let generator = RecurringTransactionGenerator(context: container.mainContext)
            _ = try generator.generatePendingTransactions()
            let reminderScheduler = TransactionReminderScheduler(context: container.mainContext)
            try await reminderScheduler.resyncAllPendingReminders()
            let budgetAlertScheduler = BudgetAlertScheduler(context: container.mainContext)
            try await budgetAlertScheduler.syncAlerts()
        } catch {
            print("Scheduled transaction refresh failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text(AppLocalization.string("app.loading", defaultValue: "Loading..."))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Error View

struct ErrorView: View {
    let error: Error
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.red)
            Text(AppLocalization.string("app.initializeFailed", defaultValue: "Failed to Initialize"))
                .font(.headline)
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}
