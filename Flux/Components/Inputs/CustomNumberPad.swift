import SwiftUI
import UIKit

enum CustomNumberPadSideColumnRow: Equatable {
    case single(CustomNumberPadAction)
    case pair(CustomNumberPadAction, CustomNumberPadAction)
}

enum CustomNumberPadLayout {
    static let numberGridRows: [[CustomNumberPadAction]] = [
        [.digit(1), .digit(2), .digit(3)],
        [.digit(4), .digit(5), .digit(6)],
        [.digit(7), .digit(8), .digit(9)],
        [.decimalSeparator, .digit(0), .backspace]
    ]

    static let sideColumnRows: [CustomNumberPadSideColumnRow] = [
        .single(.operation(.add)),
        .single(.operation(.subtract)),
        .pair(.operation(.multiply), .operation(.divide)),
        .single(.confirm)
    ]

    static let numberGridSpacing: CGFloat = 10
    static let sectionSpacing: CGFloat = 16
    static let outerHorizontalPadding: CGFloat = 16
    static let outerTopPadding: CGFloat = 16
    static let outerBottomPadding: CGFloat = 2
    static let sectionPadding: CGFloat = 0
    static let sectionPanelPadding: CGFloat = sectionPadding
    static let sectionCornerRadius: CGFloat = 22
    static let usesGroupedSectionPanels = false
    static let containerCornerRadius: CGFloat = 28
    static let numberKeyHeight: CGFloat = 64
    static let sideColumnRowHeight: CGFloat = 64
    static let sideColumnPairSpacing: CGFloat = 8
    static let sideColumnWidth: CGFloat = 90
    static let sheetHeight: CGFloat = 300
}

enum CustomNumberPadAction: Equatable {
    case digit(Int)
    case decimalSeparator
    case backspace
    case operation(NumericExpressionOperator)
    case confirm
}

enum CustomNumberPadActionResult: Equatable {
    case accepted
    case corrected
    case ignored
}

enum CustomNumberPadKeyRole: Equatable {
    case number
    case operation
    case confirm
}

enum CustomNumberPadKeyBackgroundStyle: Equatable {
    case elevatedSurface
    case accent
}

enum CustomNumberPadKeyForegroundStyle: Equatable {
    case primary
    case accent
    case inverse
}

struct CustomNumberPadKeyAppearance: Equatable {
    let backgroundStyle: CustomNumberPadKeyBackgroundStyle
    let foregroundStyle: CustomNumberPadKeyForegroundStyle
    let borderOpacity: Double
    let pressedOverlayOpacity: Double
}

enum CustomNumberPadHapticKind: Equatable {
    case lightImpact
    case warning
}

enum CustomNumberPadPalette {
    static func color(for style: CustomNumberPadKeyBackgroundStyle) -> UIColor {
        switch style {
        case .elevatedSurface:
            return UIColor { traits in
                if traits.userInterfaceStyle == .dark {
                    return .tertiarySystemBackground
                }

                return .systemBackground
            }
        case .accent:
            return .systemBlue
        }
    }

    static let groupSurface: UIColor = UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return .secondarySystemBackground
        }

        return .systemGray6
    }

    static let sheetSurface: UIColor = groupSurface
}

enum CustomNumberPadFeedback {
    static func appearance(
        for role: CustomNumberPadKeyRole,
        isPressed: Bool
    ) -> CustomNumberPadKeyAppearance {
        switch role {
        case .number:
            return CustomNumberPadKeyAppearance(
                backgroundStyle: .elevatedSurface,
                foregroundStyle: .primary,
                borderOpacity: 0,
                pressedOverlayOpacity: isPressed ? 0.14 : 0
            )
        case .operation:
            return CustomNumberPadKeyAppearance(
                backgroundStyle: .elevatedSurface,
                foregroundStyle: .accent,
                borderOpacity: 0.10,
                pressedOverlayOpacity: isPressed ? 0.16 : 0
            )
        case .confirm:
            return CustomNumberPadKeyAppearance(
                backgroundStyle: .accent,
                foregroundStyle: .inverse,
                borderOpacity: 0,
                pressedOverlayOpacity: isPressed ? 0.18 : 0
            )
        }
    }

    static func hapticKind(for result: CustomNumberPadActionResult) -> CustomNumberPadHapticKind {
        switch result {
        case .accepted, .corrected:
            return .lightImpact
        case .ignored:
            return .warning
        }
    }
}

@MainActor
final class CustomNumberPadHaptics {
    static let shared = CustomNumberPadHaptics()

    private let impactGenerator = UIImpactFeedbackGenerator(style: .light)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    private init() {
        prepare()
    }

    func prepare() {
        impactGenerator.prepare()
        notificationGenerator.prepare()
    }

    func play(_ kind: CustomNumberPadHapticKind) {
        switch kind {
        case .lightImpact:
            impactGenerator.impactOccurred(intensity: 0.85)
            impactGenerator.prepare()
        case .warning:
            notificationGenerator.notificationOccurred(.warning)
            notificationGenerator.prepare()
        }
    }
}

struct CustomNumberPad: View {
    let decimalSeparator: String
    let onAction: (CustomNumberPadAction) -> CustomNumberPadActionResult

    var body: some View {
        HStack(alignment: .top, spacing: CustomNumberPadLayout.sectionSpacing) {
            sectionSurface {
                VStack(spacing: CustomNumberPadLayout.numberGridSpacing) {
                    ForEach(Array(CustomNumberPadLayout.numberGridRows.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: CustomNumberPadLayout.numberGridSpacing) {
                            ForEach(Array(row.enumerated()), id: \.offset) { _, action in
                                keyButton(for: action)
                            }
                        }
                    }
                }
            }

            sectionSurface {
                VStack(spacing: CustomNumberPadLayout.numberGridSpacing) {
                    ForEach(Array(CustomNumberPadLayout.sideColumnRows.enumerated()), id: \.offset) { _, row in
                        sideColumnRow(row)
                    }
                }
                .frame(width: CustomNumberPadLayout.sideColumnWidth)
            }
        }
        .padding(.horizontal, CustomNumberPadLayout.outerHorizontalPadding)
        .padding(.top, CustomNumberPadLayout.outerTopPadding)
        .padding(.bottom, CustomNumberPadLayout.outerBottomPadding)
        .background {
            RoundedRectangle(
                cornerRadius: CustomNumberPadLayout.containerCornerRadius,
                style: .continuous
            )
            .fill(Color(uiColor: CustomNumberPadPalette.groupSurface))
        }
        .onAppear {
            CustomNumberPadHaptics.shared.prepare()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("numberPad.sheet")
    }

    @ViewBuilder
    private func keyButton(for action: CustomNumberPadAction) -> some View {
        let role = role(for: action)

        keypadTapTarget {
            perform(action)
        } label: { isPressed in
            let appearance = CustomNumberPadFeedback.appearance(for: role, isPressed: isPressed)

            keySurface(appearance: appearance, height: keyHeight(for: role)) {
                Group {
                    switch action {
                    case .digit(let value):
                        Text("\(value)")
                    case .decimalSeparator:
                        Text(decimalSeparator)
                    case .backspace:
                        Image(systemName: "delete.left.fill")
                            .imageScale(.medium)
                    case .operation(let operation):
                        Text(operation.symbol)
                    case .confirm:
                        Text(AppLocalization.string("action.confirm", defaultValue: "Confirm"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }
                .font(font(for: action))
            }
        }
        .accessibilityIdentifier(identifier(for: action))
        .accessibilityLabel(accessibilityLabel(for: action))
    }

    @ViewBuilder
    private func sideColumnRow(_ row: CustomNumberPadSideColumnRow) -> some View {
        switch row {
        case .single(let action):
            keyButton(for: action)
        case .pair(let left, let right):
            HStack(spacing: CustomNumberPadLayout.sideColumnPairSpacing) {
                keyButton(for: left)
                keyButton(for: right)
            }
        }
    }

    private func font(for action: CustomNumberPadAction) -> Font {
        switch action {
        case .confirm:
            return .callout.weight(.semibold)
        default:
            return .system(size: 28, weight: .medium, design: .rounded)
        }
    }

    private func keyHeight(for role: CustomNumberPadKeyRole) -> CGFloat {
        switch role {
        case .number:
            return CustomNumberPadLayout.numberKeyHeight
        case .operation, .confirm:
            return CustomNumberPadLayout.sideColumnRowHeight
        }
    }

    private func role(for action: CustomNumberPadAction) -> CustomNumberPadKeyRole {
        switch action {
        case .digit, .decimalSeparator, .backspace:
            return .number
        case .operation:
            return .operation
        case .confirm:
            return .confirm
        }
    }

    private func keySurface<Content: View>(
        appearance: CustomNumberPadKeyAppearance,
        height: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .foregroundStyle(foregroundColor(for: appearance.foregroundStyle))
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(backgroundColor(for: appearance.backgroundStyle))
                    .overlay {
                        if appearance.borderOpacity > 0 {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.accentColor.opacity(appearance.borderOpacity), lineWidth: 1)
                        }
                    }
                    .overlay {
                        if appearance.pressedOverlayOpacity > 0 {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.black.opacity(appearance.pressedOverlayOpacity))
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.black.opacity(0.035), lineWidth: 0.8)
                    }
                    .shadow(color: Color.black.opacity(0.035), radius: 1.5, x: 0, y: 1)
            }
            .clipShape(.rect(cornerRadius: 18))
            .transaction { transaction in
                transaction.animation = nil
            }
    }

    private func sectionSurface<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
    }

    private func keypadTapTarget<Label: View>(
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping (_ isPressed: Bool) -> Label
    ) -> some View {
        KeypadTapTarget(action: action, label: label)
    }

    private func perform(_ action: CustomNumberPadAction) {
        let result = onAction(action)
        CustomNumberPadHaptics.shared.play(CustomNumberPadFeedback.hapticKind(for: result))
    }

    private func backgroundColor(for style: CustomNumberPadKeyBackgroundStyle) -> Color {
        switch style {
        case .elevatedSurface:
            return Color(uiColor: CustomNumberPadPalette.color(for: .elevatedSurface))
        case .accent:
            return .accentColor
        }
    }

    private func foregroundColor(for style: CustomNumberPadKeyForegroundStyle) -> Color {
        switch style {
        case .primary:
            return .primary
        case .accent:
            return Color.accentColor.opacity(0.88)
        case .inverse:
            return AppColors.Brand.onPrimary
        }
    }

    private func accessibilityLabel(for action: CustomNumberPadAction) -> String {
        switch action {
        case .digit(let value):
            return "\(value)"
        case .decimalSeparator:
            return decimalSeparator
        case .backspace:
            return "⌫"
        case .operation(let operation):
            return operation.symbol
        case .confirm:
            return AppLocalization.string("action.confirm", defaultValue: "Confirm")
        }
    }

    private func identifier(for action: CustomNumberPadAction) -> String {
        switch action {
        case .digit(let value):
            return "numberPad.digit.\(value)"
        case .decimalSeparator:
            return "numberPad.decimal"
        case .backspace:
            return "numberPad.backspace"
        case .operation(let operation):
            return "numberPad.operation.\(operation.rawValue)"
        case .confirm:
            return "numberPad.confirm"
        }
    }
}

private struct KeypadTapTarget<Label: View>: View {
    let action: () -> Void
    let label: (_ isPressed: Bool) -> Label

    @GestureState private var isPressed = false

    var body: some View {
        label(isPressed)
            .contentShape(.rect(cornerRadius: 18))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, state, _ in
                        state = true
                    }
                    .onEnded { value in
                        guard abs(value.translation.width) < 22 else { return }
                        guard abs(value.translation.height) < 22 else { return }
                        action()
                    }
            )
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                action()
            }
            .transaction { transaction in
                transaction.animation = nil
            }
    }
}

#Preview("Custom Number Pad") {
    CustomNumberPad(decimalSeparator: ".") { _ in
        .accepted
    }
}
