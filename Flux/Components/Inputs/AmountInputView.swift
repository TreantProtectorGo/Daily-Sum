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
    @State private var inputBuffer = NumericExpressionBuffer(maxFractionDigits: 4)
    @State private var isNumberPadPresented = false
    @State private var shouldCommitDraftOnDismiss = false

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
        .background(preloadedNumberPad)
    }

    private var inputContent: some View {
        HStack(spacing: 8) {
            Text(currencySymbol)
                .font(.title2)
                .foregroundStyle(.secondary)

            Button(action: presentNumberPad) {
                Text(displayText)
                    .font(.largeTitle)
                    .bold()
                    .foregroundStyle(renderedDisplayText.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("amountInput.trigger")
            .accessibilityValue(displayText)
        }
        .onAppear {
            syncBufferFromAmount()
            if autoFocus && !hasAttemptedAutoFocus {
                hasAttemptedAutoFocus = true
                presentNumberPad()
            }
        }
        .onChange(of: amount) { _, _ in
            guard !isNumberPadPresented else { return }
            syncBufferFromAmount()
        }
        .sheet(isPresented: $isNumberPadPresented, onDismiss: handleNumberPadDismissed) {
            keypadSheetContent(
                decimalSeparator: localeDecimalSeparator,
                onAction: handleNumberPadAction
            )
            .presentationDetents([.height(CustomNumberPadLayout.sheetHeight)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color(uiColor: CustomNumberPadPalette.sheetSurface))
        }
    }

    private var renderedDisplayText: String {
        inputBuffer.displayText(locale: AppLocalization.locale)
    }

    private var displayText: String {
        renderedDisplayText.isEmpty ? placeholder : renderedDisplayText
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

    private var preloadedNumberPad: some View {
        CustomNumberPad(decimalSeparator: localeDecimalSeparator) { _ in
            .accepted
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func presentNumberPad() {
        guard !isNumberPadPresented else { return }
        syncBufferFromAmount()
        shouldCommitDraftOnDismiss = true
        setNumberPadPresented(true)
        onFocusChanged?(true)
    }

    private func setNumberPadPresented(_ presented: Bool) {
        var transaction = SwiftUI.Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isNumberPadPresented = presented
        }
    }

    private func handleNumberPadDismissed() {
        if shouldCommitDraftOnDismiss {
            _ = commitDraft()
        }
        shouldCommitDraftOnDismiss = false
        onFocusChanged?(false)
    }

    private func reportFirstUserInputIfNeeded() {
        guard !hasReportedFirstInput else { return }
        hasReportedFirstInput = true
        onFirstUserInput?()
    }

    private func syncBufferFromAmount() {
        inputBuffer = NumericExpressionBuffer(
            initialValue: amount,
            maxFractionDigits: 4,
            emptyWhenZero: amount == 0
        )
    }

    private func handleNumberPadAction(_ action: CustomNumberPadAction) -> CustomNumberPadActionResult {
        let result: CustomNumberPadActionResult

        switch action {
        case .digit(let value):
            result = CustomNumberPadActionResult(inputBuffer.appendDigit(Character("\(value)")))
        case .decimalSeparator:
            result = CustomNumberPadActionResult(inputBuffer.insertDecimalSeparator())
        case .backspace:
            result = CustomNumberPadActionResult(inputBuffer.backspace())
        case .operation(let operation):
            result = CustomNumberPadActionResult(inputBuffer.insertOperator(operation))
        case .confirm:
            _ = commitDraft()
            shouldCommitDraftOnDismiss = false
            setNumberPadPresented(false)
            return .accepted
        }

        if result != .ignored {
            reportFirstUserInputIfNeeded()
        }

        if let liveValue = inputBuffer.liveDecimalValue {
            amount = liveValue
        }

        return result
    }

    private func commitDraft() -> Decimal {
        guard inputBuffer.hasExpression || inputBuffer.hasContent || amount != 0 else {
            syncBufferFromAmount()
            return amount
        }

        let committed = inputBuffer.commit()
        amount = committed
        return committed
    }

    private func keypadSheetContent(
        decimalSeparator: String,
        onAction: @escaping (CustomNumberPadAction) -> CustomNumberPadActionResult
    ) -> some View {
        ZStack(alignment: .top) {
            Color(uiColor: CustomNumberPadPalette.sheetSurface)

            CustomNumberPad(
                decimalSeparator: decimalSeparator,
                onAction: onAction
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Compact Amount Input

/// A smaller amount input for forms
struct CompactAmountInput: View {
    @Binding var amount: Decimal
    let currencyCode: String
    let label: String
    let autoFocus: Bool

    @State private var hasAttemptedAutoFocus = false
    @State private var inputBuffer = NumericExpressionBuffer(maxFractionDigits: 4)
    @State private var isNumberPadPresented = false
    @State private var shouldCommitDraftOnDismiss = false

    init(
        amount: Binding<Decimal>,
        currencyCode: String,
        label: String,
        autoFocus: Bool = false
    ) {
        self._amount = amount
        self.currencyCode = currencyCode
        self.label = label
        self.autoFocus = autoFocus
    }

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)

            Spacer()

            Button(action: presentNumberPad) {
                HStack(spacing: 4) {
                    Text(currencySymbol)
                        .foregroundStyle(.secondary)

                    Text(compactDisplayText)
                        .foregroundStyle(renderedDisplayText.isEmpty ? .secondary : .primary)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .frame(width: 120, alignment: .trailing)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("amountInput.compactTrigger")
            .accessibilityValue(compactDisplayText)
        }
        .onAppear {
            syncBufferFromAmount()
            if autoFocus && !hasAttemptedAutoFocus {
                hasAttemptedAutoFocus = true
                presentNumberPad()
            }
        }
        .onChange(of: amount) { _, _ in
            guard !isNumberPadPresented else { return }
            syncBufferFromAmount()
        }
        .sheet(isPresented: $isNumberPadPresented, onDismiss: handleNumberPadDismissed) {
            keypadSheetContent(
                decimalSeparator: localeDecimalSeparator,
                onAction: handleNumberPadAction
            )
            .presentationDetents([.height(CustomNumberPadLayout.sheetHeight)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color(uiColor: CustomNumberPadPalette.sheetSurface))
        }
        .background(preloadedNumberPad)
    }

    private var renderedDisplayText: String {
        inputBuffer.displayText(locale: AppLocalization.locale)
    }

    private var compactDisplayText: String {
        renderedDisplayText.isEmpty ? "0" : renderedDisplayText
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

    private var preloadedNumberPad: some View {
        CustomNumberPad(decimalSeparator: localeDecimalSeparator) { _ in
            .accepted
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func presentNumberPad() {
        guard !isNumberPadPresented else { return }
        syncBufferFromAmount()
        shouldCommitDraftOnDismiss = true
        setNumberPadPresented(true)
    }

    private func setNumberPadPresented(_ presented: Bool) {
        var transaction = SwiftUI.Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isNumberPadPresented = presented
        }
    }

    private func handleNumberPadDismissed() {
        if shouldCommitDraftOnDismiss {
            _ = commitDraft()
        }
        shouldCommitDraftOnDismiss = false
    }

    private func syncBufferFromAmount() {
        inputBuffer = NumericExpressionBuffer(
            initialValue: amount,
            maxFractionDigits: 4,
            emptyWhenZero: amount == 0
        )
    }

    private func handleNumberPadAction(_ action: CustomNumberPadAction) -> CustomNumberPadActionResult {
        switch action {
        case .digit(let value):
            let result = CustomNumberPadActionResult(inputBuffer.appendDigit(Character("\(value)")))
            if let liveValue = inputBuffer.liveDecimalValue {
                amount = liveValue
            }
            return result
        case .decimalSeparator:
            let result = CustomNumberPadActionResult(inputBuffer.insertDecimalSeparator())
            if let liveValue = inputBuffer.liveDecimalValue {
                amount = liveValue
            }
            return result
        case .backspace:
            let result = CustomNumberPadActionResult(inputBuffer.backspace())
            if let liveValue = inputBuffer.liveDecimalValue {
                amount = liveValue
            }
            return result
        case .operation(let operation):
            return CustomNumberPadActionResult(inputBuffer.insertOperator(operation))
        case .confirm:
            _ = commitDraft()
            shouldCommitDraftOnDismiss = false
            setNumberPadPresented(false)
            return .accepted
        }
    }

    private func commitDraft() -> Decimal {
        guard inputBuffer.hasExpression || inputBuffer.hasContent || amount != 0 else {
            syncBufferFromAmount()
            return amount
        }

        let committed = inputBuffer.commit()
        amount = committed
        return committed
    }

    private func keypadSheetContent(
        decimalSeparator: String,
        onAction: @escaping (CustomNumberPadAction) -> CustomNumberPadActionResult
    ) -> some View {
        ZStack(alignment: .top) {
            Color(uiColor: CustomNumberPadPalette.sheetSurface)

            CustomNumberPad(
                decimalSeparator: decimalSeparator,
                onAction: onAction
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private extension CustomNumberPadActionResult {
    init(_ result: NumericExpressionMutationResult) {
        switch result {
        case .accepted:
            self = .accepted
        case .corrected:
            self = .corrected
        case .ignored:
            self = .ignored
        }
    }
}

// MARK: - Preview

#Preview("Amount Input") {
    struct PreviewWrapper: View {
        @State private var amount: Decimal = 0
        @State private var compactAmount: Decimal = 150.50

        var body: some View {
            VStack(spacing: 24) {
                ZStack {
                    Color.blue.opacity(0.3).ignoresSafeArea()

                    VStack(spacing: 16) {
                        AmountInputView(
                            amount: $amount,
                            currencyCode: "USD"
                        )

                        Text(verbatim: "Amount: \(amount)")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }
                .frame(height: 220)

                Divider()

                Form {
                    CompactAmountInput(
                        amount: $compactAmount,
                        currencyCode: "USD",
                        label: "Budget Amount",
                        autoFocus: false
                    )
                }
                .frame(height: 120)
            }
        }
    }

    return PreviewWrapper()
}
