//
//  ContentView.swift
//  Flux
//
//  Created by Wing - on 9/2/2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        MainTabView()
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
