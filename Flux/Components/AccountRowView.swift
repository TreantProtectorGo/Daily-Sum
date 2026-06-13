import SwiftUI

struct AccountRowView: View {
    let account: Account
    
    @Environment(\.regionalSettings) private var regionalSettings
    
    var body: some View {
        HStack(spacing: 12) {
            AccountTypeDefinitionIcon(definition: account.typeDefinition, fallback: account.type)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(account.resolvedTypeName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyFormatter.shared.format(account.currentBalance, currencyCode: account.currencyCode))
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(account.currentBalance >= 0 ? .primary : regionalSettings.lossColor)
            }
        }
        .padding(.vertical, 4)
    }
}

struct GlassAccountRow: View {
    let account: Account
    let onTap: (() -> Void)?
    
    init(account: Account, onTap: (() -> Void)? = nil) {
        self.account = account
        self.onTap = onTap
    }
    
    var body: some View {
        Button {
            onTap?()
        } label: {
            AccountRowView(account: account)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassBackground(cornerRadius: 12, isInteractive: true, style: .row)
        .glassSurfaceHierarchy(style: .row, cornerRadius: 12)
    }
}

struct AccountSummaryCard: View {
    let account: Account
    let recentTransactionCount: Int
    let onTap: (() -> Void)?
    
    init(account: Account, recentTransactionCount: Int = 0, onTap: (() -> Void)? = nil) {
        self.account = account
        self.recentTransactionCount = recentTransactionCount
        self.onTap = onTap
    }
    
    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    AccountTypeDefinitionIcon(definition: account.typeDefinition, fallback: account.type, size: .small)
                    Text(account.name)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(AppLocalization.string("account.balance", defaultValue: "Balance"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.shared.format(account.currentBalance, currencyCode: account.currencyCode))
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                if recentTransactionCount > 0 {
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("\(recentTransactionCount) recent transactions")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
        .buttonStyle(.plain)
        .glassBackground(cornerRadius: 16, isInteractive: true, style: .section)
        .glassSurfaceHierarchy(style: .section, cornerRadius: 16)
    }
}

#Preview("Account Row") {
    VStack(spacing: 20) {
        List {
            AccountRowView(account: .previewCash)
            AccountRowView(account: .previewBank)
            AccountRowView(account: .previewCreditCard)
        }
        .listStyle(.plain)
        .frame(height: 200)
        
        Divider()
        
        ZStack {
            Color.purple.opacity(0.3).ignoresSafeArea()
            
            VStack(spacing: 12) {
                GlassAccountRow(account: .previewCash)
                
                AccountSummaryCard(
                    account: .previewBank,
                    recentTransactionCount: 5
                )
            }
            .padding()
        }
        .frame(height: 280)
    }
}

extension Account {
    static var previewCash: Account {
        Account(
            name: "Wallet",
            type: .cash,
            currencyCode: "USD",
            initialBalance: 500
        )
    }
    
    static var previewBank: Account {
        Account(
            name: "Checking Account",
            type: .bank,
            currencyCode: "USD",
            initialBalance: 5000
        )
    }
    
    static var previewCreditCard: Account {
        Account(
            name: "Visa Card",
            type: .creditCard,
            currencyCode: "USD",
            initialBalance: -1500
        )
    }
}
