import SwiftUI

enum CustomNumberPadAction: Equatable {
    case digit(Int)
    case decimalSeparator
    case backspace
    case done
}

struct CustomNumberPad: View {
    let decimalSeparator: String
    let onAction: (CustomNumberPadAction) -> Void

    private let rows: [[CustomNumberPadAction]] = [
        [.digit(1), .digit(2), .digit(3)],
        [.digit(4), .digit(5), .digit(6)],
        [.digit(7), .digit(8), .digit(9)],
        [.decimalSeparator, .digit(0), .backspace]
    ]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 12) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, action in
                        button(for: action)
                    }
                }
            }

            Button {
                onAction(.done)
            } label: {
                Text(AppLocalization.string("action.done", defaultValue: "Done"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(AppLocalization.string("action.done", defaultValue: "Done"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func button(for action: CustomNumberPadAction) -> some View {
        Button {
            onAction(action)
        } label: {
            Group {
                switch action {
                case .digit(let value):
                    Text("\(value)")
                case .decimalSeparator:
                    Text(decimalSeparator)
                case .backspace:
                    Image(systemName: "delete.left")
                case .done:
                    EmptyView()
                }
            }
            .font(.title3.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: action))
    }

    private func accessibilityLabel(for action: CustomNumberPadAction) -> String {
        switch action {
        case .digit(let value):
            return "\(value)"
        case .decimalSeparator:
            return AppLocalization.string(
                "numberPad.decimalSeparator",
                defaultValue: "Decimal separator"
            )
        case .backspace:
            return AppLocalization.string("numberPad.backspace", defaultValue: "Delete")
        case .done:
            return AppLocalization.string("action.done", defaultValue: "Done")
        }
    }
}

#Preview("Custom Number Pad") {
    CustomNumberPad(decimalSeparator: ".") { _ in }
}
