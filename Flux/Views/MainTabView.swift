import SwiftUI
import SwiftData

struct MainTabView: View {
    @SceneStorage("mainTab.selectedTab") private var selectedTabRawValue = AppTab.dashboard.rawValue
    @SceneStorage("mainTab.searchText") private var searchText = ""

    private var selectedTabBinding: Binding<AppTab> {
        Binding(
            get: { AppTab(rawValue: selectedTabRawValue) ?? .dashboard },
            set: { selectedTabRawValue = $0.rawValue }
        )
    }
    
    var body: some View {
        TabView(selection: selectedTabBinding) {
            Tab(
                AppLocalization.string("tab.dashboard", defaultValue: "Dashboard"),
                systemImage: "house.fill",
                value: .dashboard
            ) {
                DashboardView()
            }
            
            Tab(
                AppLocalization.string("tab.transactions", defaultValue: "Transactions"),
                systemImage: "list.bullet.rectangle",
                value: .transactions
            ) {
                NavigationStack {
                    TransactionListView()
                }
            }
            
            Tab(
                AppLocalization.string("tab.reports", defaultValue: "Reports"),
                systemImage: "chart.bar.fill",
                value: .reports
            ) {
                ReportsView(initialTab: .reports, showsTabPicker: false)
            }
            
            Tab(
                AppLocalization.string("reports.tab.budgets", defaultValue: "Budgets"),
                systemImage: "chart.pie.fill",
                value: .budgets
            ) {
                ReportsView(initialTab: .budgets, showsTabPicker: false)
            }
            
            // iOS 26 Global Search - pinned to trailing edge of tab bar
            Tab(value: .search, role: .search) {
                NavigationStack {
                    TransactionListView(searchText: $searchText)
                    .searchable(
                        text: $searchText,
                        prompt: AppLocalization.string("search.prompt", defaultValue: "Search accounts, transactions, budgets...")
                    )
                }
            }
        }
        .tabViewSearchActivation(.searchTabSelection)
        .tint(AppColors.primary)
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard
    case transactions
    case reports
    case budgets
    case search
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .dashboard:
            AppLocalization.string("tab.dashboard", defaultValue: "Dashboard")
        case .transactions:
            AppLocalization.string("tab.transactions", defaultValue: "Transactions")
        case .reports:
            AppLocalization.string("tab.reports", defaultValue: "Reports")
        case .budgets:
            AppLocalization.string("reports.tab.budgets", defaultValue: "Budgets")
        case .search:
            AppLocalization.string("tab.search", defaultValue: "Search")
        }
    }
    
    var icon: String {
        switch self {
        case .dashboard: "house.fill"
        case .transactions: "list.bullet.rectangle"
        case .reports: "chart.bar.fill"
        case .budgets: "chart.pie.fill"
        case .search: "magnifyingglass"
        }
    }
}

#Preview("Main Tab View") {
    MainTabView()
}
