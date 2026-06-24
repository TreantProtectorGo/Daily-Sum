//
//  ContentView.swift
//  Flux
//
//  Created by Wing - on 9/2/2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage(AppLanguagePreference.storageKey) private var appLanguageCode = AppLanguage.system.rawValue
    @State private var shortcutRouter = ActionButtonShortcutRouter.shared
    @State private var controlIntentRouter = DailySumControlIntentRouter.shared
    
    var body: some View {
        MainTabView()
            .id("main-tab-\(appLanguageCode)")
            .sheet(item: $shortcutRouter.pendingTransactionEntry) { request in
                TransactionEntrySheet(initialType: request.type) { }
            }
            .onOpenURL { url in
                shortcutRouter.handle(url)
            }
            .onAppear {
                consumePendingControlIntentDestination()
            }
            .onChange(of: controlIntentRouter.pendingDestination?.id) { _, _ in
                consumePendingControlIntentDestination()
            }
    }

    private func consumePendingControlIntentDestination() {
        guard let pendingDestination = controlIntentRouter.pendingDestination else { return }

        handleControlIntentDestination(pendingDestination.destination)
        controlIntentRouter.clearPendingDestination()
    }

    private func handleControlIntentDestination(_ destination: DailySumControlDestination) {
        shortcutRouter.handle(destination)
    }
}

// MARK: - Preview

#Preview {
    do {
        let container = try ModelContainerConfiguration.createPreviewContainer()
        return ContentView()
            .modelContainer(container)
    } catch {
        return Text("Preview Error: \(error.localizedDescription)")
    }
}
