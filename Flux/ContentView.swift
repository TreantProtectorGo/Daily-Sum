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
    
    var body: some View {
        MainTabView()
            .id("main-tab-\(appLanguageCode)")
            .sheet(item: $shortcutRouter.pendingTransactionEntry) { request in
                TransactionEntrySheet(initialType: request.type) { }
            }
            .onOpenURL { url in
                shortcutRouter.handle(url)
            }
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
