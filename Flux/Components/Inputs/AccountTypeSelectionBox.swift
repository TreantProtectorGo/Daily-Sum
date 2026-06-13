import SwiftUI

struct AccountTypeSelectionBox: View {
    @Binding private var selection: AccountType

    private let title: String
    private let options: [AccountTypeSelectionOption]

    @State private var isExpanded = false

    init(
        title: String,
        selection: Binding<AccountType>,
        options: [AccountType] = AccountType.allCases
    ) {
        self.title = title
        self._selection = selection
        self.options = options.map(AccountTypeSelectionOption.init(type:))
    }

    var body: some View {
        VStack(spacing: 10) {
            Button {
                toggleExpansion()
            } label: {
                AccountTypeSelectionHeader(
                    title: title,
                    option: AccountTypeSelectionOption(type: selection),
                    isExpanded: isExpanded
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(selection.localizedName)
            .accessibilityHint(AppLocalization.string("account.type.change.hint", defaultValue: "Double tap to choose an account type."))

            if isExpanded {
                VStack(spacing: 4) {
                    ForEach(options) { option in
                        AccountTypeSelectionOptionRow(
                            option: option,
                            isSelected: option.type == selection,
                            action: { select(option.type) }
                        )
                    }
                }
                .padding(6)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppColors.glassBorder, lineWidth: 1)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.vertical, 4)
        .animation(.snappy(duration: 0.22), value: isExpanded)
    }

    private func toggleExpansion() {
        isExpanded.toggle()
    }

    private func select(_ type: AccountType) {
        guard selection != type else {
            isExpanded = false
            return
        }

        selection = type
        isExpanded = false
    }
}

private struct AccountTypeSelectionHeader: View {
    let title: String
    let option: AccountTypeSelectionOption
    let isExpanded: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer(minLength: 12)

            AccountTypeIcon(accountType: option.type, size: .small)

            Text(option.title)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Image(systemName: "chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
        .contentShape(.rect)
    }
}

private struct AccountTypeSelectionOptionRow: View {
    let option: AccountTypeSelectionOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                AccountTypeIcon(accountType: option.type, size: .small)

                Text(option.title)
                    .font(.body.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "checkmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.selectedNavigation)
                    .opacity(isSelected ? 1 : 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selectedBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var selectedBackground: Color {
        isSelected ? option.type.color.opacity(0.14) : .clear
    }
}

private struct AccountTypeSelectionOption: Identifiable, Hashable {
    let type: AccountType

    var id: AccountType { type }
    var title: String { type.localizedName }
}

#Preview("Account Type Selection Box") {
    @Previewable @State var accountType: AccountType = .bank

    Form {
        Section("Account Info") {
            AccountTypeSelectionBox(
                title: "Account Type",
                selection: $accountType
            )
        }
    }
}
