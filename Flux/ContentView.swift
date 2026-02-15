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
    
    var body: some View {
        MainTabView()
            .id("main-tab-\(appLanguageCode)")
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
