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
                guard activationMaintenancePolicy.claimRun() else { return }
                Task { @MainActor in
                    try? await activationMaintenancePolicy.waitForInteractionGracePeriod()
                    await refreshTravelCurrencyPreferenceIfNeeded()
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

            if let container {
                activationMaintenancePolicy.recordRun()
                Task { @MainActor in
                    try? await activationMaintenancePolicy.waitForInteractionGracePeriod()
                    await requestNotificationAuthorizationIfNeeded(in: container)
                    await refreshTravelCurrencyPreferenceIfNeeded()
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
