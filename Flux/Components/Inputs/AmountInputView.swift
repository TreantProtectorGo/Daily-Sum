import SwiftUI

// MARK: - Amount Input View

/// A text field for entering currency amounts with formatting
struct AmountInputView: View {
    @Binding var amount: Decimal
    let currencyCode: String
    let placeholder: String
    let autoFocus: Bool
    let useGlassBackground: Bool
    let useOuterPadding: Bool
    let onFirstUserInput: (() -> Void)?
    let onFocusChanged: ((Bool) -> Void)?
    
    @State private var hasAttemptedAutoFocus = false
    @State private var hasReportedFirstInput = false
    @State private var inputBuffer = NumericInputBuffer(maxFractionDigits: 4)
    @State private var isNumberPadPresented = false
    
    init(
        amount: Binding<Decimal>,
        currencyCode: String,
        placeholder: String = "0.00",
        autoFocus: Bool = false,
        useGlassBackground: Bool = true,
        useOuterPadding: Bool = true,
        onFirstUserInput: (() -> Void)? = nil,
        onFocusChanged: ((Bool) -> Void)? = nil
    ) {
        self._amount = amount
        self.currencyCode = currencyCode
        self.placeholder = placeholder
        self.autoFocus = autoFocus
        self.useGlassBackground = useGlassBackground
        self.useOuterPadding = useOuterPadding
        self.onFirstUserInput = onFirstUserInput
        self.onFocusChanged = onFocusChanged
    }
    
    var body: some View {
        Group {
            if useGlassBackground {
                inputContent
                    .padding(useOuterPadding ? 16 : 0)
                    .glassBackground(cornerRadius: 12, isInteractive: true)
            } else {
                inputContent
                    .padding(useOuterPadding ? 16 : 0)
            }
        }
    }

    private var inputContent: some View {
        HStack(spacing: 8) {
            // Currency symbol
            Text(currencySymbol)
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Text(displayText)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(inputBuffer.text.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { presentNumberPad() }
                .onAppear {
                    syncBufferFromAmount()
                    if autoFocus && !hasAttemptedAutoFocus {
                        hasAttemptedAutoFocus = true
                        DispatchQueue.main.async {
                            presentNumberPad()
                        }
                    }
                }
                .onChange(of: amount) { _, _ in
                    guard !isNumberPadPresented else { return }
                    syncBufferFromAmount()
                }
        }
        .sheet(isPresented: $isNumberPadPresented, onDismiss: dismissNumberPad) {
            CustomNumberPad(
                decimalSeparator: localeDecimalSeparator,
                onAction: handleNumberPadAction
            )
            .presentationDetents([.height(336)])
            .presentationDragIndicator(.visible)
        }
    }
    
    private var displayText: String {
        guard !inputBuffer.text.isEmpty else { return placeholder }
        return inputBuffer.text.replacingOccurrences(of: ".", with: localeDecimalSeparator)
    }

    private var localeDecimalSeparator: String {
        let formatter = NumberFormatter()
        formatter.locale = AppLocalization.locale
        return formatter.decimalSeparator ?? "."
    }

    private var currencySymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.currencySymbol ?? "$"
    }
    
    private func presentNumberPad() {
        guard !isNumberPadPresented else { return }
        isNumberPadPresented = true
        onFocusChanged?(true)
    }

    private func dismissNumberPad() {
        onFocusChanged?(false)
    }

    private func reportFirstUserInputIfNeeded(_ newValue: String) {
        guard !hasReportedFirstInput else { return }
        guard !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        hasReportedFirstInput = true
        onFirstUserInput?()
    }
    
    private func syncBufferFromAmount() {
        let formatted = amount == 0 ? "" : formatForEditing(amount)
        if formatted != inputBuffer.text {
            inputBuffer = NumericInputBuffer(initialText: formatted, maxFractionDigits: 4)
        }
    }

    private func handleNumberPadAction(_ action: CustomNumberPadAction) {
        let previousText = inputBuffer.text

        switch action {
        case .digit(let value):
            inputBuffer.appendCharacter(Character("\(value)"))
        case .decimalSeparator:
            inputBuffer.insertDecimalSeparator()
        case .backspace:
            inputBuffer.backspace()
        case .done:
            isNumberPadPresented = false
            return
        }

        amount = inputBuffer.decimalValue

        if inputBuffer.text != previousText {
            reportFirstUserInputIfNeeded(inputBuffer.text)
        }
    }

    private func formatForEditing(_ value: Decimal) -> String {
        let number = NSDecimalNumber(decimal: value)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 4
        formatter.decimalSeparator = "."
        return formatter.string(from: number) ?? ""
    }
}

// MARK: - Compact Amount Input

/// A smaller amount input for forms
struct CompactAmountInput: View {
    @Binding var amount: Decimal
    let currencyCode: String
    let label: String
    
    @State private var inputBuffer = NumericInputBuffer(maxFractionDigits: 4)
    @State private var isNumberPadPresented = false
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            HStack(spacing: 4) {
                Text(currencySymbol)
                    .foregroundStyle(.secondary)
                
                Text(compactDisplayText)
                    .foregroundStyle(inputBuffer.text.isEmpty ? .secondary : .primary)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100, alignment: .trailing)
                    .contentShape(Rectangle())
                    .onTapGesture { isNumberPadPresented = true }
                    .onAppear { syncBufferFromAmount() }
                    .onChange(of: amount) { _, _ in
                        guard !isNumberPadPresented else { return }
                        syncBufferFromAmount()
                    }
            }
        }
        .sheet(isPresented: $isNumberPadPresented) {
            CustomNumberPad(
                decimalSeparator: localeDecimalSeparator,
                onAction: handleNumberPadAction
            )
            .presentationDetents([.height(336)])
            .presentationDragIndicator(.visible)
        }
    }
    
    private var compactDisplayText: String {
        if inputBuffer.text.isEmpty {
            return "0"
        }
        return inputBuffer.text.replacingOccurrences(of: ".", with: localeDecimalSeparator)
    }

    private var localeDecimalSeparator: String {
        let formatter = NumberFormatter()
        formatter.locale = AppLocalization.locale
        return formatter.decimalSeparator ?? "."
    }

    private var currencySymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.currencySymbol ?? "$"
    }
    
    private func syncBufferFromAmount() {
        let formatted = amount == 0 ? "" : formatForEditing(amount)
        if formatted != inputBuffer.text {
            inputBuffer = NumericInputBuffer(initialText: formatted, maxFractionDigits: 4)
        }
    }

    private func handleNumberPadAction(_ action: CustomNumberPadAction) {
        switch action {
        case .digit(let value):
            inputBuffer.appendCharacter(Character("\(value)"))
        case .decimalSeparator:
            inputBuffer.insertDecimalSeparator()
        case .backspace:
            inputBuffer.backspace()
        case .done:
            isNumberPadPresented = false
            return
        }

        amount = inputBuffer.decimalValue
    }
    
    private func formatForEditing(_ value: Decimal) -> String {
        let number = NSDecimalNumber(decimal: value)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 4
        formatter.decimalSeparator = "."
        return formatter.string(from: number) ?? ""
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
