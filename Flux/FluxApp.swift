//
//  FluxApp.swift
//  Flux
//
//  Created by Wing - on 9/2/2026.
//

import SwiftUI
import SwiftData

@main
struct FluxApp: App {
    @State private var container: ModelContainer?
    @State private var isLoading = true
    @State private var loadError: Error?
    
    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    ContentView()
                        .modelContainer(container)
                        .environment(\.regionalSettings, RegionalSettings.shared)
                } else if let error = loadError {
                    ErrorView(error: error)
                } else {
                    LoadingView()
                }
            }
            .task {
                await initializeApp()
            }
        }
    }
    
    /// Initializes the app's data layer
    private func initializeApp() async {
        do {
            // Create and seed the model container
            // TODO: Read CloudKit preference from UserDefaults
            let enableCloudKit = false
            container = try await ModelContainer.createAndSeed(enableCloudKit: enableCloudKit)
            
            // Generate any pending recurring transactions
            if let container {
                let generator = RecurringTransactionGenerator(context: container.mainContext)
                let _ = try generator.generatePendingTransactions()
            }
            
            isLoading = false
        } catch {
            loadError = error
            isLoading = false
        }
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Loading...")
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
            Text("Failed to Initialize")
                .font(.headline)
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}
