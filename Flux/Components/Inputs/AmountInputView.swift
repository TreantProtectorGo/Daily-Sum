import SwiftUI
import Observation

// MARK: - Amount Input View

@MainActor
@Observable
final class AmountInputSession {
    struct Mutation: Equatable {
        let result: CustomNumberPadActionResult
        let amount: Decimal
        let didAcceptFirstInput: Bool
        let didConfirm: Bool
    }

    struct Dismissal: Equatable {
        let amount: Decimal
        let didConfirm: Bool
    }

    private(set) var inputBuffer = NumericExpressionBuffer(maxFractionDigits: 4)
    private(set) var isPresented = false
    private var shouldCommitDraftOnDismiss = false
    private var hasReportedFirstInput = false

    func present(currentAmount: Decimal) {
        guard !isPresented else { return }
        sync(from: currentAmount)
        shouldCommitDraftOnDismiss = true
        isPresented = true
    }

    func collapse(currentAmount: Decimal) -> Dismissal {
        isPresented = false
        return finishDismissal(currentAmount: currentAmount)
    }

    func finishDismissal(currentAmount: Decimal) -> Dismissal {
        let committedAmount = shouldCommitDraftOnDismiss
            ? commit(currentAmount: currentAmount)
            : currentAmount
        shouldCommitDraftOnDismiss = false
        isPresented = false
        return Dismissal(amount: committedAmount, didConfirm: false)
    }

    func perform(
        _ action: CustomNumberPadAction,
        currentAmount: Decimal
    ) -> Mutation {
        let result: CustomNumberPadActionResult
        var nextAmount = currentAmount

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
            nextAmount = commit(currentAmount: currentAmount)
            shouldCommitDraftOnDismiss = false
            isPresented = false
            return Mutation(
                result: .accepted,
                amount: nextAmount,
                didAcceptFirstInput: false,
                didConfirm: true
            )
        }

        let didAcceptFirstInput = result != .ignored && !hasReportedFirstInput
        if didAcceptFirstInput {
            hasReportedFirstInput = true
        }

        if let liveValue = inputBuffer.liveDecimalValue {
            nextAmount = liveValue
        }

        return Mutation(
            result: result,
            amount: nextAmount,
            didAcceptFirstInput: didAcceptFirstInput,
            didConfirm: false
        )
    }

    func displayText(locale: Locale) -> String {
        inputBuffer.displayText(locale: locale)
    }

    func sync(from amount: Decimal) {
        inputBuffer = NumericExpressionBuffer(
            initialValue: amount,
            maxFractionDigits: 4,
            emptyWhenZero: amount == 0
        )
    }

    private func commit(currentAmount: Decimal) -> Decimal {
        guard inputBuffer.hasExpression || inputBuffer.hasContent || currentAmount != 0 else {
            sync(from: currentAmount)
            return currentAmount
        }

        return inputBuffer.commit()
    }
}

/// A text field for entering currency amounts with formatting
struct AmountInputView: View {
    @Binding var amount: Decimal
    let currencyCode: String
    let placeholder: String
    let autoFocus: Bool
    let useGlassBackground: Bool
    let useOuterPadding: Bool
    let session: AmountInputSession
    let onFocusChanged: ((Bool) -> Void)?

    @State private var hasAttemptedAutoFocus = false

    init(
        amount: Binding<Decimal>,
        currencyCode: String,
        placeholder: String = "0.00",
        autoFocus: Bool = false,
        useGlassBackground: Bool = true,
        useOuterPadding: Bool = true,
        session: AmountInputSession,
        onFocusChanged: ((Bool) -> Void)? = nil
    ) {
        self._amount = amount
        self.currencyCode = currencyCode
        self.placeholder = placeholder
        self.autoFocus = autoFocus
        self.useGlassBackground = useGlassBackground
        self.useOuterPadding = useOuterPadding
        self.session = session
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
            guard !session.isPresented else { return }
            session.sync(from: amount)
        }
    }

    private var renderedDisplayText: String {
        session.displayText(locale: AppLocalization.locale)
    }

    private var displayText: String {
        renderedDisplayText.isEmpty ? placeholder : renderedDisplayText
    }

    private var currencySymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.currencySymbol ?? "$"
    }

    private func presentNumberPad() {
        guard !session.isPresented else { return }
        session.present(currentAmount: amount)
        onFocusChanged?(true)
    }

    private func syncBufferFromAmount() {
        session.sync(from: amount)
    }
}

enum DockedAmountNumberPadLayout {
    static let collapsedHeight: CGFloat = 0
}

struct DockedAmountNumberPad: View {
    let session: AmountInputSession
    @Binding var amount: Decimal
    let onFirstUserInput: (() -> Void)?
    let onFocusChanged: ((Bool) -> Void)?
    let onConfirm: (() -> Void)?

    var body: some View {
        Group {
            if session.isPresented {
                CustomNumberPad(
                    decimalSeparator: localeDecimalSeparator,
                    onAction: handleNumberPadAction
                )
                .frame(height: CustomNumberPadLayout.sheetHeight)
                .accessibilityIdentifier("numberPad.docked")
                .simultaneousGesture(collapseGesture)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(minHeight: session.isPresented ? nil : DockedAmountNumberPadLayout.collapsedHeight)
        .background(
            Color(uiColor: CustomNumberPadPalette.sheetSurface)
                .ignoresSafeArea(edges: .bottom)
        )
        .animation(.snappy(duration: 0.22), value: session.isPresented)
    }

    private var collapseGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                guard value.translation.height > 48 else { return }
                guard abs(value.translation.width) < value.translation.height else { return }
                collapse()
        }
    }

    private var localeDecimalSeparator: String {
        let formatter = NumberFormatter()
        formatter.locale = AppLocalization.locale
        return formatter.decimalSeparator ?? "."
    }

    private func collapse() {
        let dismissal = session.collapse(currentAmount: amount)
        amount = dismissal.amount
        onFocusChanged?(false)
    }

    private func handleNumberPadAction(_ action: CustomNumberPadAction) -> CustomNumberPadActionResult {
        let mutation = session.perform(action, currentAmount: amount)
        amount = mutation.amount

        if mutation.didAcceptFirstInput {
            onFirstUserInput?()
        }

        if mutation.didConfirm {
            onFocusChanged?(false)
            onConfirm?()
        }

        return mutation.result
    }
}

extension View {
    func dockedAmountNumberPad(
        session: AmountInputSession,
        amount: Binding<Decimal>,
        onFirstUserInput: (() -> Void)? = nil,
        onFocusChanged: ((Bool) -> Void)? = nil,
        onConfirm: (() -> Void)? = nil
    ) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            DockedAmountNumberPad(
                session: session,
                amount: amount,
                onFirstUserInput: onFirstUserInput,
                onFocusChanged: onFocusChanged,
                onConfirm: onConfirm
            )
        }
    }
}

// MARK: - Compact Amount Input

/// A smaller amount input for forms
struct CompactAmountInput: View {
    @Binding var amount: Decimal
    let currencyCode: String
    let label: String
    let autoFocus: Bool
    let session: AmountInputSession

    @State private var hasAttemptedAutoFocus = false

    init(
        amount: Binding<Decimal>,
        currencyCode: String,
        label: String,
        autoFocus: Bool = false,
        session: AmountInputSession
    ) {
        self._amount = amount
        self.currencyCode = currencyCode
        self.label = label
        self.autoFocus = autoFocus
        self.session = session
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
            guard !session.isPresented else { return }
            syncBufferFromAmount()
        }
    }

    private var renderedDisplayText: String {
        session.displayText(locale: AppLocalization.locale)
    }

    private var compactDisplayText: String {
        renderedDisplayText.isEmpty ? "0" : renderedDisplayText
    }

    private var currencySymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.currencySymbol ?? "$"
    }

    private func presentNumberPad() {
        guard !session.isPresented else { return }
        syncBufferFromAmount()
        session.present(currentAmount: amount)
    }

    private func syncBufferFromAmount() {
        session.sync(from: amount)
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
        @State private var amountInputSession = AmountInputSession()
        @State private var compactInputSession = AmountInputSession()

        var body: some View {
            VStack(spacing: 24) {
                ZStack {
                    Color.blue.opacity(0.3).ignoresSafeArea()

                    VStack(spacing: 16) {
                        AmountInputView(
                            amount: $amount,
                            currencyCode: "USD",
                            session: amountInputSession
                        )

                        Text(verbatim: "Amount: \(amount)")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }
                .frame(height: 220)
                .dockedAmountNumberPad(
                    session: amountInputSession,
                    amount: $amount
                )

                Divider()

                Form {
                    CompactAmountInput(
                        amount: $compactAmount,
                        currencyCode: "USD",
                        label: "Budget Amount",
                        autoFocus: false,
                        session: compactInputSession
                    )
                }
                .frame(height: 120)
                .dockedAmountNumberPad(
                    session: compactInputSession,
                    amount: $compactAmount
                )
            }
        }
    }

    return PreviewWrapper()
}
