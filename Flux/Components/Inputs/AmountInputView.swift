import SwiftUI

// MARK: - Amount Input View

/// A text field for entering currency amounts with formatting
struct AmountInputView: View {
    @Binding var amount: Decimal
    let currencyCode: String
    let placeholder: String
    
    @State private var textValue: String = ""
    @FocusState private var isFocused: Bool
    
    init(
        amount: Binding<Decimal>,
        currencyCode: String,
        placeholder: String = "0.00"
    ) {
        self._amount = amount
        self.currencyCode = currencyCode
        self.placeholder = placeholder
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Currency symbol
            Text(currencySymbol)
                .font(.title2)
                .foregroundStyle(.secondary)
            
            // Amount input
            TextField(placeholder, text: $textValue)
                .font(.largeTitle)
                .fontWeight(.bold)
                .keyboardType(.decimalPad)
                .focused($isFocused)
                .onChange(of: textValue) { _, newValue in
                    updateAmount(from: newValue)
                }
                .onAppear {
                    if amount != 0 {
                        textValue = formatForEditing(amount)
                    }
                }
        }
        .padding()
        .glassBackground(cornerRadius: 12, isInteractive: true)
    }
    
    private var currencySymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.currencySymbol ?? "$"
    }
    
    private func updateAmount(from text: String) {
        // Allow only valid decimal characters
        let filtered = text.filter { $0.isNumber || $0 == "." || $0 == "," }
        
        // Replace comma with period for parsing
        let normalized = filtered.replacingOccurrences(of: ",", with: ".")
        
        // Ensure only one decimal point
        let components = normalized.split(separator: ".", omittingEmptySubsequences: false)
        var cleanText = normalized
        if components.count > 2 {
            cleanText = String(components[0]) + "." + components.dropFirst().joined()
        }
        
        // Parse and update
        if let decimal = Decimal(string: cleanText) {
            amount = decimal
        } else if cleanText.isEmpty {
            amount = 0
        }
        
        // Update text if it was filtered
        if filtered != text {
            textValue = filtered
        }
    }
    
    private func formatForEditing(_ value: Decimal) -> String {
        let number = NSDecimalNumber(decimal: value)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: number) ?? "0"
    }
}

// MARK: - Compact Amount Input

/// A smaller amount input for forms
struct CompactAmountInput: View {
    @Binding var amount: Decimal
    let currencyCode: String
    let label: String
    
    @State private var textValue: String = ""
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            HStack(spacing: 4) {
                Text(currencySymbol)
                    .foregroundStyle(.secondary)
                
                TextField("0", text: $textValue)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                    .onChange(of: textValue) { _, newValue in
                        updateAmount(from: newValue)
                    }
                    .onAppear {
                        if amount != 0 {
                            textValue = formatForEditing(amount)
                        }
                    }
            }
        }
    }
    
    private var currencySymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.currencySymbol ?? "$"
    }
    
    private func updateAmount(from text: String) {
        let filtered = text.filter { $0.isNumber || $0 == "." || $0 == "," }
        let normalized = filtered.replacingOccurrences(of: ",", with: ".")
        
        if let decimal = Decimal(string: normalized) {
            amount = decimal
        } else if normalized.isEmpty {
            amount = 0
        }
        
        if filtered != text {
            textValue = filtered
        }
    }
    
    private func formatForEditing(_ value: Decimal) -> String {
        let number = NSDecimalNumber(decimal: value)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: number) ?? "0"
    }
}

// MARK: - Preview

#Preview("Amount Input") {
    struct PreviewWrapper: View {
        @State private var amount: Decimal = 0
        @State private var compactAmount: Decimal = 150.50
        
        var body: some View {
            VStack(spacing: 24) {
                // Main amount input
                ZStack {
                    Color.blue.opacity(0.3).ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        AmountInputView(
                            amount: $amount,
                            currencyCode: "USD"
                        )
                        
                        Text("Amount: \(amount)")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }
                .frame(height: 200)
                
                Divider()
                
                // Compact input
                Form {
                    CompactAmountInput(
                        amount: $compactAmount,
                        currencyCode: "USD",
                        label: "Budget Amount"
                    )
                }
                .frame(height: 100)
            }
        }
    }
    
    return PreviewWrapper()
}
