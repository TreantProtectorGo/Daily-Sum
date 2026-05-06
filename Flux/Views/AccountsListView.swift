import SwiftUI
import SwiftData

struct AccountsListView: View {
    @Query(sort: \Account.createdAt, order: .reverse) private var accounts: [Account]

    @State private var showAddAccount = false
    @State private var selectedAccount: Account?

    private let onAccountsChanged: () -> Void

    init(onAccountsChanged: @escaping () -> Void = {}) {
        self.onAccountsChanged = onAccountsChanged
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if accounts.isEmpty {
                    GlassEmptyState(
                        title: AppLocalization.string("empty.accounts.title", defaultValue: "No Accounts"),
                        message: AppLocalization.string("empty.accounts.message", defaultValue: "Add your accounts to start managing your finances."),
                        systemImage: "building.columns",
                        actionTitle: AppLocalization.string("empty.accounts.action", defaultValue: "Add Account")
                    ) {
                        showAddAccount = true
                    }
                    .accessibilityIdentifier("accounts.emptyState")
                } else {
                    ForEach(accounts) { account in
                        GlassAccountRow(account: account) {
                            selectedAccount = account
                        }
                        .accessibilityIdentifier("accounts.list.row")
                    }
                }
            }
            .padding()
            .padding(.bottom, 24)
        }
        .navigationTitle(AppLocalization.string("dashboard.accounts", defaultValue: "Accounts"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddAccount = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(AppLocalization.string("action.addAccount", defaultValue: "Add Account"))
                .accessibilityIdentifier("accounts.addButton")
            }
        }
        .sheet(isPresented: $showAddAccount) {
            AccountEntrySheet(onSave: onAccountsChanged)
        }
        .sheet(item: $selectedAccount) { account in
            AccountEntrySheet(account: account, onSave: onAccountsChanged)
        }
        .accessibilityIdentifier("accounts.list")
    }
}

#Preview("Accounts List") {
    do {
        let container = try ModelContainerConfiguration.createPreviewContainer()
        return NavigationStack {
            AccountsListView()
        }
        .modelContainer(container)
    } catch {
        return Text("Preview Error: \(error.localizedDescription)")
    }
}
