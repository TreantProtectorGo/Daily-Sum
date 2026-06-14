import SwiftUI
import UIKit

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

struct IconToolbarButton: View {
    let systemName: String
    let accessibilityLabel: String
    let role: ButtonRole?
    let action: () -> Void

    init(
        systemName: String,
        accessibilityLabel: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.accessibilityLabel = accessibilityLabel
        self.role = role
        self.action = action
    }

    var body: some View {
        Button(role: role, action: action) {
            Image(systemName: systemName)
                .font(.headline.weight(.semibold))
                .frame(width: 34, height: 34)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct IconColorSelectionBox<Item: IconColorSelectable>: View where Item.ID: Equatable {
    @Binding private var selection: Item?

    let title: String
    let placeholderTitle: String
    let placeholderIcon: String
    let placeholderColor: Color
    let items: [Item]
    let manageAccessibilityLabel: String
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
        self.manageAccessibilityLabel = manageTitle
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
                        HStack(spacing: 10) {
                            Spacer()

                            Image(systemName: "slider.horizontal.3")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppColors.selectedNavigation)
                                .frame(width: 34, height: 34)

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(manageAccessibilityLabel)
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

enum SFSymbolCatalog {
    static let featured = unique([
        "banknote", "building.columns", "creditcard", "chart.line.uptrend.xyaxis",
        "wallet.pass", "tag", "cart.fill", "fork.knife", "cup.and.saucer.fill",
        "house.fill", "car.fill", "gift.fill", "briefcase.fill", "percent"
    ])

    static let all = unique([
        // Finance
        "banknote", "banknote.fill", "building.columns", "building.columns.fill",
        "creditcard", "creditcard.fill", "creditcard.and.123", "wallet.pass",
        "wallet.pass.fill", "dollarsign", "dollarsign.circle", "dollarsign.circle.fill",
        "centsign.circle", "sterlingsign.circle", "eurosign.circle", "yensign.circle",
        "bitcoinsign.circle", "percent", "percent.ar", "chart.line.uptrend.xyaxis",
        "chart.line.uptrend.xyaxis.circle", "chart.bar", "chart.bar.fill",
        "chart.pie", "chart.pie.fill", "chart.dots.scatter", "arrow.up.right",
        "arrow.down.left", "arrow.left.arrow.right", "arrow.triangle.2.circlepath",
        "calendar.badge.clock", "clock", "clock.fill",

        // Shopping and daily spend
        "cart", "cart.fill", "basket", "basket.fill", "bag", "bag.fill",
        "shippingbox", "shippingbox.fill", "tag", "tag.fill", "tags", "tags.fill",
        "gift", "gift.fill", "ticket", "ticket.fill", "takeoutbag.and.cup.and.straw",
        "takeoutbag.and.cup.and.straw.fill", "cup.and.saucer", "cup.and.saucer.fill",
        "fork.knife", "wineglass", "wineglass.fill", "birthday.cake", "birthday.cake.fill",

        // Home and bills
        "house", "house.fill", "building.2", "building.2.fill", "door.left.hand.open",
        "sofa", "sofa.fill", "bed.double", "bed.double.fill", "lamp.table",
        "lamp.table.fill", "lightbulb", "lightbulb.fill", "bolt", "bolt.fill",
        "drop", "drop.fill", "flame", "flame.fill", "wifi", "antenna.radiowaves.left.and.right",
        "phone", "phone.fill", "tv", "tv.fill", "washer", "washer.fill",

        // Transport and travel
        "car", "car.fill", "fuelpump", "fuelpump.fill", "bus", "bus.fill",
        "tram", "tram.fill", "train.side.front.car", "bicycle", "scooter",
        "airplane", "airplane.departure", "airplane.arrival", "ferry", "ferry.fill",
        "figure.walk", "figure.run", "mappin", "mappin.circle", "map", "map.fill",
        "location", "location.fill", "suitcase", "suitcase.fill",

        // Work and income
        "briefcase", "briefcase.fill", "laptopcomputer", "desktopcomputer",
        "keyboard", "printer", "printer.fill", "doc.text", "doc.text.fill",
        "doc.on.doc", "doc.on.doc.fill", "folder", "folder.fill", "tray",
        "tray.fill", "person.crop.circle.badge.checkmark", "person.2",
        "person.2.fill", "person.3", "person.3.fill", "graduationcap",
        "graduationcap.fill", "book", "book.fill", "books.vertical", "books.vertical.fill",

        // Lifestyle and services
        "heart", "heart.fill", "cross.case", "cross.case.fill", "pills",
        "pills.fill", "stethoscope", "bandage", "bandage.fill", "scissors",
        "comb", "paintbrush", "paintbrush.fill", "gamecontroller", "gamecontroller.fill",
        "music.note", "music.mic", "film", "film.fill", "popcorn", "popcorn.fill",
        "camera", "camera.fill", "pawprint", "pawprint.fill", "leaf", "leaf.fill",

        // Planning and generic
        "calendar", "calendar.circle", "calendar.badge.plus", "calendar.badge.minus",
        "checkmark", "checkmark.circle", "checkmark.circle.fill", "xmark",
        "xmark.circle", "xmark.circle.fill", "plus", "plus.circle", "plus.circle.fill",
        "minus", "minus.circle", "minus.circle.fill", "square.grid.2x2",
        "square.grid.2x2.fill", "list.bullet", "slider.horizontal.3", "gear",
        "gearshape", "gearshape.fill", "star", "star.fill", "flag", "flag.fill",
        "pin", "pin.fill", "bell", "bell.fill", "exclamationmark.triangle",
        "exclamationmark.triangle.fill", "info.circle", "info.circle.fill"
    ])

    static func search(_ query: String) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return featured }

        return all.filter { symbol in
            symbol.localizedStandardContains(trimmed)
        }
    }

    static func isValid(_ symbol: String) -> Bool {
        UIImage(systemName: symbol.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
    }

    private static func unique(_ symbols: [String]) -> [String] {
        var seen = Set<String>()
        return symbols.filter { seen.insert($0).inserted }
    }
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
    @State private var showSymbolPicker = false

    private let colors = [
        "#34C759", "#0A84FF", "#FF9500", "#AF52DE", "#FF3B30", "#5AC8FA",
        "#30D158", "#FFD60A", "#BF5AF2", "#64D2FF", "#8E8E93", "#FF2D55"
    ]

    init(
        title: String,
        saveTitle: String = "Apply",
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
                    Button {
                        showSymbolPicker = true
                    } label: {
                        HStack(spacing: 12) {
                            IconColorCircle(
                                icon: draft.icon,
                                color: Color(hex: draft.colorHex) ?? .secondary,
                                size: .medium
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                Text("SF Symbol")
                                    .foregroundStyle(.primary)
                                Text(draft.icon)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
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
                    IconToolbarButton(
                        systemName: "xmark",
                        accessibilityLabel: "Close"
                    ) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.headline.weight(.semibold))
                            .frame(width: 34, height: 34)
                            .contentShape(.circle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(saveTitle)
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert(AppLocalization.string("error.title", defaultValue: "Error"), isPresented: $showError) {
                Button(AppLocalization.string("action.ok", defaultValue: "OK")) { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showSymbolPicker) {
                SFSymbolPickerSheet(
                    selectedSymbol: $draft.icon,
                    tintColor: Color(hex: draft.colorHex) ?? .secondary
                )
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

private struct SFSymbolPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedSymbol: String
    let tintColor: Color

    @State private var searchText = ""
    @State private var manualSymbol = ""
    @State private var manualSymbolIsInvalid = false

    private var symbols: [String] {
        SFSymbolCatalog.search(searchText)
    }

    private var cleanedManualSymbol: String {
        manualSymbol.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(selectedSymbol: Binding<String>, tintColor: Color) {
        self._selectedSymbol = selectedSymbol
        self.tintColor = tintColor
        self._manualSymbol = State(initialValue: selectedSymbol.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                symbolPreview

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 54), spacing: 12)], spacing: 14) {
                        if shouldShowManualResult {
                            SFSymbolGridButton(
                                symbol: cleanedManualSymbol,
                                tintColor: tintColor,
                                isSelected: selectedSymbol == cleanedManualSymbol,
                                showsName: true
                            ) {
                                select(cleanedManualSymbol)
                            }
                        }

                        ForEach(symbols, id: \.self) { symbol in
                            SFSymbolGridButton(
                                symbol: symbol,
                                tintColor: tintColor,
                                isSelected: selectedSymbol == symbol,
                                showsName: searchText.isEmpty == false
                            ) {
                                select(symbol)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Choose Symbol")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search SF Symbols")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    IconToolbarButton(
                        systemName: "xmark",
                        accessibilityLabel: "Close"
                    ) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    IconToolbarButton(
                        systemName: "checkmark",
                        accessibilityLabel: "Finish"
                    ) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var symbolPreview: some View {
        VStack(spacing: 14) {
            IconColorCircle(icon: selectedSymbol, color: tintColor, size: .large)

            Text(selectedSymbol)
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image(systemName: "keyboard")
                        .foregroundStyle(.secondary)

                    TextField("Enter any SF Symbol name", text: $manualSymbol)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())

                    Button("Use") {
                        useManualSymbol()
                    }
                    .font(.subheadline.weight(.semibold))
                    .disabled(cleanedManualSymbol.isEmpty)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text(manualSymbolIsInvalid ? "This SF Symbol is not available on this iOS version." : "Paste any Apple SF Symbol name here.")
                    .font(.caption)
                    .foregroundStyle(manualSymbolIsInvalid ? .red : .secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .background(.thinMaterial)
    }

    private var shouldShowManualResult: Bool {
        let symbol = cleanedManualSymbol
        return !symbol.isEmpty
            && SFSymbolCatalog.isValid(symbol)
            && !symbols.contains(symbol)
    }

    private func select(_ symbol: String) {
        selectedSymbol = symbol
        manualSymbol = symbol
        manualSymbolIsInvalid = false
    }

    private func useManualSymbol() {
        let symbol = cleanedManualSymbol
        guard SFSymbolCatalog.isValid(symbol) else {
            manualSymbolIsInvalid = true
            return
        }

        select(symbol)
    }
}

private struct SFSymbolGridButton: View {
    let symbol: String
    let tintColor: Color
    let isSelected: Bool
    let showsName: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(isSelected ? .white : tintColor)
                    .frame(width: 48, height: 48)
                    .background(
                        isSelected ? tintColor : tintColor.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isSelected ? tintColor : tintColor.opacity(0.18), lineWidth: 1)
                    }

                if showsName {
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                        .frame(width: 64)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(symbol)
        }
        .buttonStyle(.plain)
    }
}
