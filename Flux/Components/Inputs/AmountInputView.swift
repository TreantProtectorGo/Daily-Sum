import SwiftUI
import Observation

// MARK: - Amount Input View

enum AmountNumberPadPresentation {
    case sheet
    case docked
}

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

    func requestDismissal() {
        isPresented = false
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
    let numberPadPresentation: AmountNumberPadPresentation
    let sharedSession: AmountInputSession?
    let onFirstUserInput: (() -> Void)?
    let onFocusChanged: ((Bool) -> Void)?
    let onConfirm: (() -> Void)?

    @State private var hasAttemptedAutoFocus = false
    @State private var ownedSession = AmountInputSession()
    @State private var shouldRunConfirmActionOnDismiss = false

    init(
        amount: Binding<Decimal>,
        currencyCode: String,
        placeholder: String = "0.00",
        autoFocus: Bool = false,
        useGlassBackground: Bool = true,
        useOuterPadding: Bool = true,
        numberPadPresentation: AmountNumberPadPresentation = .sheet,
        session: AmountInputSession? = nil,
        onFirstUserInput: (() -> Void)? = nil,
        onFocusChanged: ((Bool) -> Void)? = nil,
        onConfirm: (() -> Void)? = nil
    ) {
        self._amount = amount
        self.currencyCode = currencyCode
        self.placeholder = placeholder
        self.autoFocus = autoFocus
        self.useGlassBackground = useGlassBackground
        self.useOuterPadding = useOuterPadding
        self.numberPadPresentation = numberPadPresentation
        self.sharedSession = session
        self.onFirstUserInput = onFirstUserInput
        self.onFocusChanged = onFocusChanged
        self.onConfirm = onConfirm
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
        .background {
            if numberPadPresentation == .sheet {
                preloadedNumberPad
            }
        }
        .sheet(isPresented: sheetPresentationBinding, onDismiss: handleNumberPadDismissed) {
            keypadSheetContent(
                decimalSeparator: localeDecimalSeparator,
                onAction: handleNumberPadAction
            )
            .presentationDetents([.height(CustomNumberPadLayout.sheetHeight)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color(uiColor: CustomNumberPadPalette.sheetSurface))
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

    private var sheetPresentationBinding: Binding<Bool> {
        Binding(
            get: {
                numberPadPresentation == .sheet && session.isPresented
            },
            set: { isPresented in
                guard numberPadPresentation == .sheet else { return }
                if isPresented {
                    presentNumberPad()
                } else {
                    session.requestDismissal()
                }
            }
        )
    }

    private var session: AmountInputSession {
        sharedSession ?? ownedSession
    }

    private var renderedDisplayText: String {
        session.displayText(locale: AppLocalization.locale)
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
        guard !session.isPresented else { return }
        session.present(currentAmount: amount)
        onFocusChanged?(true)
    }

    private func handleNumberPadDismissed() {
        let dismissal = session.finishDismissal(currentAmount: amount)
        amount = dismissal.amount
        onFocusChanged?(false)
        if shouldRunConfirmActionOnDismiss {
            shouldRunConfirmActionOnDismiss = false
            onConfirm?()
        }
    }

    private func syncBufferFromAmount() {
        session.sync(from: amount)
    }

    private func handleNumberPadAction(_ action: CustomNumberPadAction) -> CustomNumberPadActionResult {
        let mutation = session.perform(action, currentAmount: amount)
        amount = mutation.amount

        if mutation.didAcceptFirstInput {
            onFirstUserInput?()
        }

        if mutation.didConfirm {
            shouldRunConfirmActionOnDismiss = true
        }

        return mutation.result
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

struct DockedAmountNumberPad: View {
    let session: AmountInputSession
    @Binding var amount: Decimal
    let onFirstUserInput: (() -> Void)?
    let onFocusChanged: ((Bool) -> Void)?
    let onConfirm: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            grabber

            if session.isPresented {
                CustomNumberPad(
                    decimalSeparator: localeDecimalSeparator,
                    onAction: handleNumberPadAction
                )
                .frame(height: CustomNumberPadLayout.sheetHeight)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityIdentifier("numberPad.docked")
            }
        }
        .background(
            Color(uiColor: CustomNumberPadPalette.sheetSurface)
                .ignoresSafeArea(edges: .bottom)
        )
        .animation(.snappy(duration: 0.22), value: session.isPresented)
    }

    private var grabber: some View {
        Button(action: togglePresentation) {
            Capsule()
                .fill(.secondary.opacity(0.42))
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("numberPad.grabber")
        .accessibilityLabel(
            session.isPresented
                ? "Collapse keypad"
                : "Expand keypad"
        )
        .highPriorityGesture(
            DragGesture(minimumDistance: 10)
                .onEnded { value in
                    guard value.translation.height > 24 else { return }
                    collapse()
                }
        )
    }

    private var localeDecimalSeparator: String {
        let formatter = NumberFormatter()
        formatter.locale = AppLocalization.locale
        return formatter.decimalSeparator ?? "."
    }

    private func togglePresentation() {
        if session.isPresented {
            collapse()
        } else {
            session.present(currentAmount: amount)
            onFocusChanged?(true)
        }
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

// MARK: - Compact Amount Input

/// A smaller amount input for forms
struct CompactAmountInput: View {
    @Binding var amount: Decimal
    let currencyCode: String
    let label: String
    let autoFocus: Bool
    let onConfirm: (() -> Void)?

    @State private var hasAttemptedAutoFocus = false
    @State private var inputBuffer = NumericExpressionBuffer(maxFractionDigits: 4)
    @State private var isNumberPadPresented = false
    @State private var shouldCommitDraftOnDismiss = false
    @State private var shouldRunConfirmActionOnDismiss = false

    init(
        amount: Binding<Decimal>,
        currencyCode: String,
        label: String,
        autoFocus: Bool = false,
        onConfirm: (() -> Void)? = nil
    ) {
        self._amount = amount
        self.currencyCode = currencyCode
        self.label = label
        self.autoFocus = autoFocus
        self.onConfirm = onConfirm
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
        if shouldRunConfirmActionOnDismiss {
            shouldRunConfirmActionOnDismiss = false
            onConfirm?()
        }
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
            shouldRunConfirmActionOnDismiss = true
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
