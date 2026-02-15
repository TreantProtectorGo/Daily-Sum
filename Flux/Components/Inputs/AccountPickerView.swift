import SwiftUI
import SwiftData

struct AccountPickerView: View {
    @Binding var selectedAccount: Account?
    let showBalance: Bool
    
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @State private var isExpanded = false
    
    init(selectedAccount: Binding<Account?>, showBalance: Bool = true) {
        self._selectedAccount = selectedAccount
        self.showBalance = showBalance
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    if let account = selectedAccount {
                        AccountTypeIcon(accountType: account.type, size: .small)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.name)
                                .font(.headline)
                            if showBalance {
                                Text(CurrencyFormatter.shared.format(account.currentBalance, currencyCode: account.currencyCode))
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
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding()
                .glassBackground(cornerRadius: 12, isInteractive: true)
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                accountList
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    private var accountList: some View {
        VStack(spacing: 8) {
            ForEach(accounts) { account in
                AccountPickerRow(
                    account: account,
                    isSelected: selectedAccount?.id == account.id,
                    showBalance: showBalance
                ) {
                    selectedAccount = account
                    withAnimation(.spring(duration: 0.3)) {
                        isExpanded = false
                    }
                }
            }
        }
        .padding()
        .glassBackground(cornerRadius: 16)
    }
}

private struct AccountPickerRow: View {
    let account: Account
    let isSelected: Bool
    let showBalance: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                AccountTypeIcon(accountType: account.type, size: .small)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.name)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                    
                    Text(account.type.localizedName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if showBalance {
                    Text(CurrencyFormatter.shared.format(account.currentBalance, currencyCode: account.currencyCode))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
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
                    Image(systemName: account.type.defaultIcon)
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
