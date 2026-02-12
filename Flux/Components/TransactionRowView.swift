import SwiftUI

// MARK: - Transaction Row View

/// A row displaying a single transaction in a list
struct TransactionRowView: View {
    let transaction: Transaction
    
    @Environment(\.regionalSettings) private var regionalSettings
    
    var body: some View {
        HStack(spacing: 12) {
            // Category Icon
            categoryIconView
            
            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.category?.displayName ?? String(localized: "transaction.uncategorized", defaultValue: "Uncategorized"))
                    .font(.headline)
                    .lineLimit(1)
                
                if let notes = transaction.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Amount and Date
            VStack(alignment: .trailing, spacing: 2) {
                AmountText(
                    transaction.signedAmount,
                    currencyCode: transaction.currencyCode,
                    showSign: true,
                    fontWeight: .semibold
                )
                
                Text(DateFormatterUtility.shared.formatTransactionDate(transaction.date))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var categoryIconView: some View {
        if let category = transaction.category {
            CategoryIcon(category: category)
        } else {
            PlaceholderCategoryIcon()
        }
    }
}

// MARK: - Transaction Row with Glass

/// A glass-styled transaction row for use outside of Lists
struct GlassTransactionRow: View {
    let transaction: Transaction
    let onTap: (() -> Void)?
    
    init(transaction: Transaction, onTap: (() -> Void)? = nil) {
        self.transaction = transaction
        self.onTap = onTap
    }
    
    var body: some View {
        Button {
            onTap?()
        } label: {
            TransactionRowView(transaction: transaction)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassBackground(cornerRadius: 12, isInteractive: true)
    }
}

// MARK: - Transaction Type Badge

/// A small badge indicating the transaction type
struct TransactionTypeBadge: View {
    let type: TransactionType
    
    var body: some View {
        Text(type.localizedName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(type.color.opacity(0.15))
            .foregroundStyle(type.color)
            .clipShape(Capsule())
    }
}

// MARK: - TransactionType Extension

extension TransactionType {
    var color: Color {
        switch self {
        case .income: AppColors.income
        case .expense: AppColors.expense
        }
    }
    
    var icon: String {
        switch self {
        case .income: "arrow.down.circle.fill"
        case .expense: "arrow.up.circle.fill"
        }
    }
}

// MARK: - Preview

#Preview("Transaction Row") {
    VStack(spacing: 12) {
        // Transaction type badges
        HStack(spacing: 8) {
            TransactionTypeBadge(type: .income)
            TransactionTypeBadge(type: .expense)
        }
        .padding()
    }
}
