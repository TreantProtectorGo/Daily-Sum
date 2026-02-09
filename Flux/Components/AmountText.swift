import SwiftUI

// MARK: - Amount Text

/// A text view that displays a formatted currency amount with regional coloring
struct AmountText: View {
    let amount: Decimal
    let currencyCode: String
    let showSign: Bool
    let font: Font
    let fontWeight: Font.Weight?
    
    @Environment(\.regionalSettings) private var regionalSettings
    
    init(
        _ amount: Decimal,
        currencyCode: String,
        showSign: Bool = false,
        font: Font = .body,
        fontWeight: Font.Weight? = nil
    ) {
        self.amount = amount
        self.currencyCode = currencyCode
        self.showSign = showSign
        self.font = font
        self.fontWeight = fontWeight
    }
    
    var body: some View {
        Text(currency: amount, code: currencyCode, showSign: showSign)
            .font(font)
            .fontWeight(fontWeight)
            .foregroundStyle(regionalSettings.color(for: amount))
    }
}

// MARK: - Large Amount Display

/// A prominent amount display for dashboard summaries
struct LargeAmountDisplay: View {
    let title: String
    let amount: Decimal
    let currencyCode: String
    let showSign: Bool
    
    @Environment(\.regionalSettings) private var regionalSettings
    
    init(
        title: String,
        amount: Decimal,
        currencyCode: String,
        showSign: Bool = false
    ) {
        self.title = title
        self.amount = amount
        self.currencyCode = currencyCode
        self.showSign = showSign
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text(currency: amount, code: currencyCode, showSign: showSign)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(showSign ? regionalSettings.color(for: amount) : .primary)
        }
    }
}

// MARK: - Compact Amount

/// A compact amount display for list rows
struct CompactAmount: View {
    let amount: Decimal
    let currencyCode: String
    let showSign: Bool
    
    @Environment(\.regionalSettings) private var regionalSettings
    
    var body: some View {
        Text(CurrencyFormatter.shared.formatCompact(amount, currencyCode: currencyCode))
            .foregroundStyle(showSign ? regionalSettings.color(for: amount) : .primary)
    }
}

// MARK: - Preview

#Preview("Amount Text") {
    VStack(alignment: .leading, spacing: 20) {
        // Basic amounts
        Group {
            AmountText(1234.56, currencyCode: "USD")
            AmountText(-567.89, currencyCode: "USD", showSign: true)
            AmountText(1000, currencyCode: "TWD", showSign: true)
        }
        
        Divider()
        
        // Large display
        LargeAmountDisplay(
            title: "Total Balance",
            amount: 12345.67,
            currencyCode: "USD"
        )
        
        LargeAmountDisplay(
            title: "This Month",
            amount: -2345.00,
            currencyCode: "USD",
            showSign: true
        )
        
        Divider()
        
        // Styled amounts
        AmountText(
            9999.99,
            currencyCode: "USD",
            font: .headline,
            fontWeight: .semibold
        )
    }
    .padding()
}
