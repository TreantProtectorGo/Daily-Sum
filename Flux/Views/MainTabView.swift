import SwiftUI
import SwiftData

struct MainTabView: View {
    @State private var selectedTab: AppTab = .dashboard
    
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(
                String(localized: "tab.dashboard", defaultValue: "Dashboard"),
                systemImage: "house.fill",
                value: .dashboard
            ) {
                DashboardView()
            }
            
            Tab(
                String(localized: "tab.transactions", defaultValue: "Transactions"),
                systemImage: "list.bullet.rectangle",
                value: .transactions
            ) {
                NavigationStack {
                    TransactionListView()
                }
            }
            
            Tab(
                String(localized: "tab.reports", defaultValue: "Reports"),
                systemImage: "chart.bar.fill",
                value: .reports
            ) {
                ReportsView()
            }
            
            Tab(
                String(localized: "tab.settings", defaultValue: "Settings"),
                systemImage: "gearshape.fill",
                value: .settings
            ) {
                SettingsView()
            }
        }
        .tint(AppColors.primary)
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard
    case transactions
    case reports
    case settings
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .dashboard:
            String(localized: "tab.dashboard", defaultValue: "Dashboard")
        case .transactions:
            String(localized: "tab.transactions", defaultValue: "Transactions")
        case .reports:
            String(localized: "tab.reports", defaultValue: "Reports")
        case .settings:
            String(localized: "tab.settings", defaultValue: "Settings")
        }
    }
    
    var icon: String {
        switch self {
        case .dashboard: "house.fill"
        case .transactions: "list.bullet.rectangle"
        case .reports: "chart.bar.fill"
        case .settings: "gearshape.fill"
        }
    }
}

#Preview("Main Tab View") {
    MainTabView()
}
