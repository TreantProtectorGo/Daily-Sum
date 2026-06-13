import SwiftUI

protocol IconColorSelectable: Identifiable {
    var selectionTitle: String { get }
    var selectionIcon: String { get }
    var selectionColor: Color { get }
}

extension AccountTypeDefinition: IconColorSelectable {
    var selectionTitle: String { name }
    var selectionIcon: String { icon }
    var selectionColor: Color { color }
}

extension Category: IconColorSelectable {
    var selectionTitle: String { displayName }
    var selectionIcon: String { icon }
    var selectionColor: Color { color }
}

struct IconColorCircle: View {
    let icon: String
    let color: Color
    let size: CategoryIcon.Size

    init(icon: String, color: Color, size: CategoryIcon.Size = .medium) {
        self.icon = icon
        self.color = color
        self.size = size
    }

    var body: some View {
        Image(systemName: icon)
            .font(size.iconFont)
            .foregroundStyle(color)
            .frame(width: size.dimension, height: size.dimension)
            .background(color.opacity(0.15))
            .clipShape(Circle())
    }
}

struct IconColorSelectionBox<Item: IconColorSelectable>: View where Item.ID: Equatable {
    @Binding private var selection: Item?

    let title: String
    let placeholderTitle: String
    let placeholderIcon: String
    let placeholderColor: Color
    let items: [Item]
    let manageTitle: String
    let onManage: () -> Void

    @State private var isExpanded = false

    init(
        title: String,
        placeholderTitle: String,
        placeholderIcon: String = "tag",
        placeholderColor: Color = .secondary,
        selection: Binding<Item?>,
        items: [Item],
        manageTitle: String,
        onManage: @escaping () -> Void
    ) {
        self.title = title
        self.placeholderTitle = placeholderTitle
        self.placeholderIcon = placeholderIcon
        self.placeholderColor = placeholderColor
        self._selection = selection
        self.items = items
        self.manageTitle = manageTitle
        self.onManage = onManage
    }

    var body: some View {
        VStack(spacing: 10) {
            Button {
                isExpanded.toggle()
            } label: {
                IconColorSelectionHeader(
                    title: title,
                    displayTitle: selection?.selectionTitle ?? placeholderTitle,
                    icon: selection?.selectionIcon ?? placeholderIcon,
                    color: selection?.selectionColor ?? placeholderColor,
                    isExpanded: isExpanded
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(selection?.selectionTitle ?? placeholderTitle)

            if isExpanded {
                VStack(spacing: 4) {
                    ForEach(items) { item in
                        IconColorSelectionRow(
                            title: item.selectionTitle,
                            icon: item.selectionIcon,
                            color: item.selectionColor,
                            isSelected: selection?.id == item.id
                        ) {
                            selection = item
                            isExpanded = false
                        }
                    }

                    Divider()
                        .padding(.vertical, 2)

                    Button {
                        isExpanded = false
                        onManage()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppColors.selectedNavigation)
                                .frame(width: 32, height: 32)

                            Text(manageTitle)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(AppColors.selectedNavigation)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                    }
                    .buttonStyle(.plain)
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
}

private struct IconColorSelectionHeader: View {
    let title: String
    let displayTitle: String
    let icon: String
    let color: Color
    let isExpanded: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer(minLength: 12)

            IconColorCircle(icon: icon, color: color, size: .small)

            Text(displayTitle)
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

private struct IconColorSelectionRow: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                IconColorCircle(icon: icon, color: color, size: .small)

                Text(title)
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
            .background(isSelected ? color.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

struct IconColorItemDraft: Equatable {
    var name: String
    var icon: String
    var colorHex: String

    static let empty = IconColorItemDraft(
        name: "",
        icon: "tag",
        colorHex: "#808080"
    )
}

struct IconColorItemEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let saveTitle: String
    let initialDraft: IconColorItemDraft
    let onSave: (IconColorItemDraft) throws -> Void

    @State private var draft: IconColorItemDraft
    @State private var errorMessage = ""
    @State private var showError = false

    private let icons = [
        "banknote", "building.columns", "creditcard", "chart.line.uptrend.xyaxis",
        "wallet.pass", "tag", "cart.fill", "fork.knife", "cup.and.saucer.fill",
        "house.fill", "car.fill", "gift.fill", "briefcase.fill", "percent"
    ]

    private let colors = [
        "#34C759", "#0A84FF", "#FF9500", "#AF52DE", "#FF3B30", "#5AC8FA",
        "#30D158", "#FFD60A", "#BF5AF2", "#64D2FF", "#8E8E93", "#FF2D55"
    ]

    init(
        title: String,
        saveTitle: String = AppLocalization.string("action.save", defaultValue: "Save"),
        initialDraft: IconColorItemDraft,
        onSave: @escaping (IconColorItemDraft) throws -> Void
    ) {
        self.title = title
        self.saveTitle = saveTitle
        self.initialDraft = initialDraft
        self.onSave = onSave
        self._draft = State(initialValue: initialDraft)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $draft.name)
                        .textInputAutocapitalization(.words)
                }

                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(icons, id: \.self) { icon in
                            Button {
                                draft.icon = icon
                            } label: {
                                IconColorCircle(
                                    icon: icon,
                                    color: Color(hex: draft.colorHex) ?? .secondary,
                                    size: .medium
                                )
                                .overlay {
                                    if draft.icon == icon {
                                        Circle()
                                            .stroke(AppColors.selectedNavigation, lineWidth: 2)
                                            .padding(-4)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(colors, id: \.self) { colorHex in
                            Button {
                                draft.colorHex = colorHex
                            } label: {
                                Circle()
                                    .fill(Color(hex: colorHex) ?? .secondary)
                                    .frame(width: 34, height: 34)
                                    .overlay {
                                        if draft.colorHex == colorHex {
                                            Circle()
                                                .stroke(.primary, lineWidth: 2)
                                                .padding(-4)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppLocalization.string("action.cancel", defaultValue: "Cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(saveTitle) {
                        save()
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert(AppLocalization.string("error.title", defaultValue: "Error"), isPresented: $showError) {
                Button(AppLocalization.string("action.ok", defaultValue: "OK")) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func save() {
        do {
            try onSave(draft)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
