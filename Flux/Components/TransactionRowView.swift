import Foundation
import SwiftUI

// MARK: - Transaction Row View

/// Immutable row data used by transaction list UIs to avoid rendering detached SwiftData models.
struct TransactionRowSnapshot: Identifiable {
    let id: UUID
    let categoryDisplayName: String
    let categoryIcon: String?
    let categoryColor: Color?
    let notes: String?
    let signedAmount: Decimal
    let currencyCode: String
    let travelAmount: Decimal?
    let travelCurrencyCode: String?
    let date: Date
    let createdAt: Date
    let isTravelTransaction: Bool
    let isGeneratedFromRecurring: Bool
    let isUpcoming: Bool

    var isFutureCalendarDay: Bool {
        let calendar = Calendar.current
        return calendar.startOfDay(for: date) > calendar.startOfDay(for: .now)
    }

    var shouldPromptScheduledDelete: Bool {
        isGeneratedFromRecurring && isFutureCalendarDay
    }

    init(transaction: Transaction) {
        id = transaction.id
        categoryDisplayName = transaction.category?.displayName
            ?? AppLocalization.string("transaction.uncategorized", defaultValue: "Uncategorized")
        categoryIcon = transaction.category?.icon
        categoryColor = transaction.category?.color
        notes = transaction.notes
        signedAmount = transaction.signedAmount
        currencyCode = transaction.currencyCode
        travelAmount = transaction.resolvedTravelSnapshot?.travelAmount
        travelCurrencyCode = transaction.resolvedTravelSnapshot?.travelCurrencyCode
        date = transaction.date
        createdAt = transaction.createdAt
        isTravelTransaction = transaction.isTravelTransaction ?? false
        isGeneratedFromRecurring = transaction.isGeneratedFromRecurring
        isUpcoming = transaction.isUpcoming
    }

    var primarySignedAmount: Decimal {
        if let travelAmount, isTravelTransaction {
            return signedAmount < 0 ? -travelAmount : travelAmount
        }
        return signedAmount
    }

    var primaryCurrencyCode: String {
        if let travelCurrencyCode, isTravelTransaction {
            return travelCurrencyCode
        }
        return currencyCode
    }

    var chargedAmountText: String? {
        guard isTravelTransaction,
              let travelCurrencyCode,
              travelCurrencyCode != currencyCode else {
            return nil
        }

        let chargedPrefix = AppLocalization.string(
            "transaction.travel.chargedAs",
            defaultValue: "Charged as"
        )
        let formatted = CurrencyFormatter.shared.format(abs(signedAmount), currencyCode: currencyCode)
        return "\(chargedPrefix) \(formatted)"
    }

    var trailingSecondaryText: String {
        let dateText = DateFormatterUtility.shared.formatTransactionDate(date)
        guard let chargedAmountText else {
            return dateText
        }
        return "\(chargedAmountText) • \(dateText)"
    }
}

/// A row displaying a single transaction in a list
struct TransactionRowView: View {
    let snapshot: TransactionRowSnapshot

    init(snapshot: TransactionRowSnapshot) {
        self.snapshot = snapshot
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Category Icon
            categoryIconView
            
            // Details
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(snapshot.categoryDisplayName)
                        .font(.headline)
                        .lineLimit(1)
                        .layoutPriority(1)

                    if snapshot.isTravelTransaction {
                        TravelTransactionBadge()
                            .fixedSize()
                    }
                }

                if let scheduleDetail = scheduleDetailText {
                    Text(scheduleDetail)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                }
                
                if let notes = snapshot.notes, !notes.isEmpty {
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
                    snapshot.primarySignedAmount,
                    currencyCode: snapshot.primaryCurrencyCode,
                    showSign: true,
                    fontWeight: .semibold
                )
                
                Text(snapshot.trailingSecondaryText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private var scheduleDetailText: String? {
        guard snapshot.isGeneratedFromRecurring else {
            return nil
        }

        var parts: [String] = []
        if snapshot.isUpcoming {
            parts.append(
                AppLocalization.string("transaction.schedule.upcoming", defaultValue: "Upcoming")
            )
        }

        if parts.isEmpty {
            return nil
        }
        return parts.joined(separator: " • ")
    }
    
    @ViewBuilder
    private var categoryIconView: some View {
        if let icon = snapshot.categoryIcon, let color = snapshot.categoryColor {
            CategoryIcon(icon: icon, color: color)
        } else {
            PlaceholderCategoryIcon()
        }
    }
}

private struct TravelTransactionBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "airplane")
                .font(.system(size: 9, weight: .semibold))

            Text(AppLocalization.string("transaction.travel.badge", defaultValue: "Travel"))
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.blue.opacity(0.08), in: Capsule())
        .foregroundStyle(.blue)
    }
}

// MARK: - Transaction Row with Glass

/// A glass-styled transaction row for use outside of Lists
struct GlassTransactionRow: View {
    let snapshot: TransactionRowSnapshot
    let onTap: (() -> Void)?

    init(snapshot: TransactionRowSnapshot, onTap: (() -> Void)? = nil) {
        self.snapshot = snapshot
        self.onTap = onTap
    }
    
    var body: some View {
        Button {
            onTap?()
        } label: {
            TransactionRowView(snapshot: snapshot)
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
