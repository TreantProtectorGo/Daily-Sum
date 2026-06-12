import SwiftUI
import SwiftData

struct MainTabView: View {
    @SceneStorage("mainTab.searchText") private var searchText = ""
    @State private var selectedTab: AppTab

    private var selectedTabBinding: Binding<AppTab> {
        Binding(
            get: { selectedTab },
            set: { selectedTab = $0 }
        )
    }

    init() {
        _selectedTab = State(initialValue: AppLaunchTabPreference.initialSelectedTab)
    }
    
    var body: some View {
        TabView(selection: selectedTabBinding) {
            Tab(
                AppLocalization.string("tab.dashboard", defaultValue: "主頁"),
                systemImage: "house.fill",
                value: .dashboard
            ) {
                DashboardView {
                    selectedTabBinding.wrappedValue = .transactions
                }
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
        .tint(AppColors.selectedNavigation)
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
            AppLocalization.string("tab.dashboard", defaultValue: "主頁")
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

enum AppLaunchTabPreference {
    static let storageKey = "flux.defaultLaunchTab"
    static let supportedTabs: [AppTab] = [.dashboard, .transactions, .reports, .budgets]

    static var initialSelectedTab: AppTab {
        defaultTab
    }

    static var defaultTab: AppTab {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: storageKey),
                  let tab = AppTab(rawValue: rawValue),
                  supportedTabs.contains(tab) else {
                return .dashboard
            }

            return tab
        }
        set {
            let normalizedTab = supportedTabs.contains(newValue) ? newValue : .dashboard
            UserDefaults.standard.set(normalizedTab.rawValue, forKey: storageKey)
        }
    }
}

#Preview("Main Tab View") {
    MainTabView()
}
