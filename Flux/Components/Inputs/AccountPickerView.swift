import SwiftUI
import SwiftData

struct AccountPickerView: View {
    @Binding var selectedAccount: Account?
    let showBalance: Bool
    let expansionTrigger: Int
    let availableAccounts: [Account]?
    
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @State private var showAccountSheet = false
    
    init(
        selectedAccount: Binding<Account?>,
        showBalance: Bool = true,
        expansionTrigger: Int = 0,
        availableAccounts: [Account]? = nil
    ) {
        self._selectedAccount = selectedAccount
        self.showBalance = showBalance
        self.expansionTrigger = expansionTrigger
        self.availableAccounts = availableAccounts
    }

    private var resolvedAccounts: [Account] {
        availableAccounts ?? accounts
    }
    
    var body: some View {
        Button {
            showAccountSheet = true
        } label: {
            HStack {
                if let account = selectedAccount {
                    AccountTypeDefinitionIcon(definition: account.typeDefinition, fallback: account.type, size: .small)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.name)
                            .font(.body)
                        if showBalance {
                            Text(
                                CurrencyFormatter.shared.format(
                                    account.currentBalance,
                                    currencyCode: account.currencyCode
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Image(systemName: "building.columns")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                    Text(AppLocalization.string("account.select", defaultValue: "Select Account"))
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("transaction.accountPicker.trigger")
        .onChange(of: expansionTrigger) { _, _ in
            guard resolvedAccounts.count > 1 else { return }
            showAccountSheet = true
        }
        .sheet(isPresented: $showAccountSheet) {
            AccountSelectionSheet(
                selectedAccount: $selectedAccount,
                accounts: resolvedAccounts,
                showBalance: showBalance
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

private struct AccountSelectionSheet: View {
    @Binding var selectedAccount: Account?
    let accounts: [Account]
    let showBalance: Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 94))], spacing: 16) {
                    ForEach(accounts) { account in
                        AccountGridItem(
                            account: account,
                            isSelected: selectedAccount?.id == account.id,
                            showBalance: showBalance
                        ) {
                            selectedAccount = account
                            dismiss()
                        }
                    }
                }
                .padding()
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("transaction.accountPicker.sheet")
            .navigationTitle(AppLocalization.string("account.select", defaultValue: "Select Account"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct AccountGridItem: View {
    let account: Account
    let isSelected: Bool
    let showBalance: Bool
    let onSelect: () -> Void

    private var subtitle: String {
        guard showBalance else { return account.resolvedTypeName }
        return CurrencyFormatter.shared.format(
            account.currentBalance,
            currencyCode: account.currencyCode
        )
    }

    var body: some View {
        IconTitleGridItem(
            title: account.name,
            subtitle: subtitle,
            tintColor: account.resolvedTypeColor,
            isSelected: isSelected
        ) {
            AccountTypeDefinitionIcon(
                definition: account.typeDefinition,
                fallback: account.type,
                size: .medium
            )
        } onSelect: {
            onSelect()
        }
    }
}

struct InlineAccountPicker: View {
    @Binding var selectedAccount: Account?
    
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    
    var body: some View {
        Picker(AppLocalization.string("account.label", defaultValue: "Account"), selection: $selectedAccount) {
            Text(AppLocalization.string("account.none", defaultValue: "None"))
                .tag(nil as Account?)
            
            ForEach(accounts) { account in
                HStack {
                    Image(systemName: account.resolvedTypeIcon)
                    Text(account.name)
                }
                .tag(account as Account?)
            }
        }
    }
}

#Preview("Account Picker") {
    struct PreviewWrapper: View {
        @State private var selectedAccount: Account?
        
        var body: some View {
            ZStack {
                Color.purple.opacity(0.2).ignoresSafeArea()
                
                VStack(spacing: 24) {
                    AccountPickerView(
                        selectedAccount: $selectedAccount,
                        showBalance: true
                    )
                    
                    if let account = selectedAccount {
                        Text("Selected: \(account.name)")
                    } else {
                        Text("No account selected")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
        }
    }
    
    return PreviewWrapper()
}
