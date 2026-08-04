import SwiftUI
import UIKit

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
        Image(systemName: SFSymbolCatalog.filledVariant(icon))
            .font(size.iconFont)
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(IconColorCircleStyle.glyphColor(for: color))
            .frame(width: size.dimension, height: size.dimension)
            .background(color)
            .clipShape(Circle())
    }
}

enum IconColorCircleStyle {
    static func glyphColor(for color: Color) -> Color {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return .white
        }

        let luminance = (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
        return luminance > 0.68 ? Color(uiColor: .darkGray) : .white
    }
}

struct IconToolbarGlyph: View {
    let systemName: String

    var body: some View {
        glyph
            .font(.headline.weight(.semibold))
            .frame(width: 34, height: 34)
            .contentShape(.circle)
    }

    @ViewBuilder
    private var glyph: some View {
        if systemName == "checkmark" {
            Image(systemName: systemName)
                .foregroundStyle(.tint)
        } else {
            Image(systemName: systemName)
                .foregroundStyle(.primary)
        }
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
            IconToolbarGlyph(systemName: systemName)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct IconTitleGridItem<Icon: View>: View {
    let title: String
    let subtitle: String?
    let tintColor: Color
    let isSelected: Bool
    let icon: Icon
    let onSelect: () -> Void

    init(
        title: String,
        subtitle: String? = nil,
        tintColor: Color,
        isSelected: Bool,
        @ViewBuilder icon: () -> Icon,
        onSelect: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.tintColor = tintColor
        self.isSelected = isSelected
        self.icon = icon()
        self.onSelect = onSelect
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                icon
                    .overlay {
                        Circle()
                            .stroke(tintColor, lineWidth: isSelected ? 3 : 0)
                            .padding(-6)
                    }

                VStack(spacing: 2) {
                    Text(title)
                        .font(.caption.weight(isSelected ? .semibold : .regular))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .minimumScaleFactor(0.78)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption2)
                            .lineLimit(1)
                            .foregroundStyle(.tertiary)
                            .minimumScaleFactor(0.72)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(minWidth: 76, minHeight: subtitle == nil ? 78 : 96)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(subtitle.map { "\(title), \($0)" } ?? title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct IconManagementGridItem<Icon: View>: View {
    let title: String
    let subtitle: String?
    let tintColor: Color
    let isSelected: Bool
    let icon: Icon
    let onEdit: () -> Void
    let onDelete: () -> Void

    init(
        title: String,
        subtitle: String? = nil,
        tintColor: Color,
        isSelected: Bool,
        @ViewBuilder icon: () -> Icon,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.tintColor = tintColor
        self.isSelected = isSelected
        self.icon = icon()
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onEdit) {
                VStack(spacing: 8) {
                    icon
                        .overlay {
                            Circle()
                                .stroke(tintColor, lineWidth: isSelected ? 3 : 0)
                                .padding(-6)
                        }

                    VStack(spacing: 2) {
                        Text(title)
                            .font(.caption.weight(isSelected ? .semibold : .regular))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(isSelected ? .primary : .secondary)
                            .minimumScaleFactor(0.72)

                        if let subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.caption2)
                                .lineLimit(1)
                                .foregroundStyle(.tertiary)
                                .minimumScaleFactor(0.68)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(minHeight: subtitle == nil ? 92 : 108)
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(subtitle.map { "\(title), \($0)" } ?? title)
            .accessibilityHint(AppLocalization.string("action.edit", defaultValue: "Edit"))
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(.red, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(AppLocalization.string("action.delete", defaultValue: "Delete"))
            .offset(x: 2, y: -2)
        }
    }
}

struct IconManagementListRow<Icon: View>: View {
    let title: String
    let countText: String
    let countAccessibilityLabel: String
    let tintColor: Color
    let isSelected: Bool
    let icon: Icon

    init(
        title: String,
        countText: String,
        countAccessibilityLabel: String,
        tintColor: Color,
        isSelected: Bool,
        @ViewBuilder icon: () -> Icon
    ) {
        self.title = title
        self.countText = countText
        self.countAccessibilityLabel = countAccessibilityLabel
        self.tintColor = tintColor
        self.isSelected = isSelected
        self.icon = icon()
    }

    var body: some View {
        HStack(spacing: 12) {
            icon
                .overlay {
                    Circle()
                        .stroke(tintColor, lineWidth: isSelected ? 3 : 0)
                        .padding(-5)
                }

            Text(title)
                .font(.body.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .layoutPriority(1)

            Spacer(minLength: 12)

            Text(countText)
                .font(.body)
                .monospacedDigit()
                .foregroundStyle(.secondary)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .accessibilityLabel("\(title), \(countAccessibilityLabel)")
        .accessibilityHint(AppLocalization.string("action.edit", defaultValue: "Edit"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

enum IconManagementReorder {
    static func reordered<Item>(
        items: [Item],
        sourceIndex: Int,
        destinationIndex: Int
    ) -> [Item] {
        guard items.indices.contains(sourceIndex),
              destinationIndex >= 0,
              destinationIndex < items.count,
              sourceIndex != destinationIndex else {
            return items
        }

        var reorderedItems = items
        let movedItem = reorderedItems.remove(at: sourceIndex)
        let insertionIndex = min(destinationIndex, reorderedItems.count)
        reorderedItems.insert(movedItem, at: insertionIndex)
        return reorderedItems
    }
}

struct IconManagementReorderList<Item: Identifiable, Icon: View>: UIViewRepresentable where Item.ID: Hashable {
    let items: [Item]
    let selectedID: Item.ID?
    let title: (Item) -> String
    let countText: (Item) -> String
    let countAccessibilityLabel: (Item) -> String
    let tintColor: (Item) -> Color
    let icon: (Item) -> Icon
    let onEdit: (Item) -> Void
    let onDelete: (Item) -> Void
    let onMove: ([Item]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITableView {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.dataSource = context.coordinator
        tableView.delegate = context.coordinator
        tableView.dragDelegate = context.coordinator
        tableView.dropDelegate = context.coordinator
        tableView.dragInteractionEnabled = true
        tableView.backgroundColor = .systemGroupedBackground
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 62, bottom: 0, right: 0)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 52
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Coordinator.cellIdentifier)
        return tableView
    }

    func updateUIView(_ tableView: UITableView, context: Context) {
        context.coordinator.parent = self
        if !tableView.hasActiveDrag {
            tableView.reloadData()
        }
    }

    final class Coordinator: NSObject,
        UITableViewDataSource,
        UITableViewDelegate,
        UITableViewDragDelegate,
        UITableViewDropDelegate {

        static var cellIdentifier: String { "IconManagementReorderCell" }

        var parent: IconManagementReorderList

        init(_ parent: IconManagementReorderList) {
            self.parent = parent
        }

        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            parent.items.count
        }

        func tableView(
            _ tableView: UITableView,
            cellForRowAt indexPath: IndexPath
        ) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: Self.cellIdentifier,
                for: indexPath
            )
            let item = parent.items[indexPath.row]

            cell.contentConfiguration = UIHostingConfiguration {
                IconManagementListRow(
                    title: parent.title(item),
                    countText: parent.countText(item),
                    countAccessibilityLabel: parent.countAccessibilityLabel(item),
                    tintColor: parent.tintColor(item),
                    isSelected: parent.selectedID == item.id
                ) {
                    parent.icon(item)
                }
                .padding(.vertical, 4)
            }
            cell.selectionStyle = .default
            cell.accessibilityIdentifier = "iconManagement.row.\(indexPath.row)"
            return cell
        }

        func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            tableView.deselectRow(at: indexPath, animated: true)
            parent.onEdit(parent.items[indexPath.row])
        }

        func tableView(
            _ tableView: UITableView,
            trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
        ) -> UISwipeActionsConfiguration? {
            let item = parent.items[indexPath.row]
            let delete = UIContextualAction(style: .destructive, title: nil) { [weak self] _, _, completion in
                self?.parent.onDelete(item)
                completion(true)
            }
            delete.image = UIImage(systemName: "trash")
            delete.backgroundColor = .systemRed

            let configuration = UISwipeActionsConfiguration(actions: [delete])
            configuration.performsFirstActionWithFullSwipe = false
            return configuration
        }

        func tableView(
            _ tableView: UITableView,
            itemsForBeginning session: UIDragSession,
            at indexPath: IndexPath
        ) -> [UIDragItem] {
            let itemID = parent.items[indexPath.row].id
            let itemProvider = NSItemProvider(object: "\(itemID)" as NSString)
            let dragItem = UIDragItem(itemProvider: itemProvider)
            dragItem.localObject = itemID
            return [dragItem]
        }

        func tableView(
            _ tableView: UITableView,
            dropSessionDidUpdate session: UIDropSession,
            withDestinationIndexPath destinationIndexPath: IndexPath?
        ) -> UITableViewDropProposal {
            guard tableView.hasActiveDrag else {
                return UITableViewDropProposal(operation: .cancel)
            }
            return UITableViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
        }

        func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
            guard let draggedID = coordinator.items.first?.dragItem.localObject as? Item.ID,
                  let sourceIndex = parent.items.firstIndex(where: { $0.id == draggedID }) else {
                return
            }

            let destinationIndex = min(
                coordinator.destinationIndexPath?.row ?? parent.items.index(before: parent.items.endIndex),
                parent.items.index(before: parent.items.endIndex)
            )
            guard sourceIndex != destinationIndex else { return }

            let reorderedItems = IconManagementReorder.reordered(
                items: parent.items,
                sourceIndex: sourceIndex,
                destinationIndex: destinationIndex
            )

            tableView.performBatchUpdates {
                tableView.moveRow(
                    at: IndexPath(row: sourceIndex, section: 0),
                    to: IndexPath(row: destinationIndex, section: 0)
                )
            }
            parent.onMove(reorderedItems)
        }
    }
}

struct IconColorItemDraft: Equatable {
    var name: String
    var icon: String
    var colorHex: String

    static let empty = IconColorItemDraft(
        name: "",
        icon: "",
        colorHex: ""
    )
}

@MainActor
enum SFSymbolCatalog {
    static let featured = unique([
        "banknote", "building.columns", "creditcard", "chart.line.uptrend.xyaxis",
        "wallet.bifold", "wallet.pass", "tag", "cart.fill", "fork.knife", "cup.and.saucer.fill",
        "house.fill", "car.fill", "gift.fill", "briefcase.fill", "percent"
    ])

    static let all = unique([
        // Finance
        "banknote", "banknote.fill", "building.columns", "building.columns.fill",
        "creditcard", "creditcard.fill", "creditcard.and.123", "wallet.bifold",
        "wallet.bifold.fill", "wallet.pass", "wallet.pass.fill", "dollarsign", "dollarsign.circle", "dollarsign.circle.fill",
        "centsign.circle", "sterlingsign.circle", "eurosign.circle", "yensign.circle",
        "bitcoinsign.circle", "percent", "percent.ar", "chart.line.uptrend.xyaxis",
        "chart.line.uptrend.xyaxis.circle", "chart.bar", "chart.bar.fill",
        "chart.pie", "chart.pie.fill", "chart.dots.scatter", "arrow.up.right",
        "arrow.down.left", "arrow.left.arrow.right", "arrow.triangle.2.circlepath",
        "calendar.badge.clock", "clock", "clock.fill",

        // Shopping and daily spend
        "cart", "cart.fill", "basket", "basket.fill", "bag", "bag.fill", "tshirt", "tshirt.fill",
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
        "refrigerator", "refrigerator.fill", "oven", "oven.fill", "microwave", "microwave.fill",
        "dishwasher", "dishwasher.fill", "toilet", "toilet.fill", "shower", "shower.fill",
        "bathtub", "bathtub.fill", "sink", "sink.fill", "chair", "chair.fill",
        "table.furniture", "table.furniture.fill", "cabinet", "cabinet.fill",
        "blinds.horizontal.closed", "window.vertical.closed",

        // Transport and travel
        "car", "car.fill", "fuelpump", "fuelpump.fill", "bus", "bus.fill",
        "car.side", "car.side.fill", "car.front.waves.up", "car.front.waves.up.fill",
        "bus.doubledecker", "bus.doubledecker.fill", "tram", "tram.fill",
        "tram.fill.tunnel", "train.side.front.car", "train.side.middle.car",
        "train.side.rear.car", "bicycle", "bicycle.circle", "scooter",
        "motorcycle", "motorcycle.fill", "moped", "moped.fill",
        "airplane", "airplane.departure", "airplane.arrival", "ferry", "ferry.fill",
        "sailboat", "sailboat.fill", "water.waves", "fuelpump.circle",
        "ev.charger", "ev.charger.fill", "parkingsign", "parkingsign.circle",
        "figure.walk", "figure.run", "figure.wave", "mappin", "mappin.circle",
        "map", "map.fill", "location", "location.fill", "suitcase", "suitcase.fill",

        // Work and income
        "briefcase", "briefcase.fill", "laptopcomputer", "desktopcomputer",
        "keyboard", "printer", "printer.fill", "doc.text", "doc.text.fill",
        "doc.on.doc", "doc.on.doc.fill", "folder", "folder.fill", "tray",
        "tray.fill", "person.crop.circle.badge.checkmark", "person.2",
        "person.2.fill", "person.3", "person.3.fill", "graduationcap",
        "graduationcap.fill", "book", "book.fill", "books.vertical", "books.vertical.fill",

        // Fitness and health
        "dumbbell", "dumbbell.fill", "figure.strengthtraining.traditional",
        "figure.strengthtraining.functional", "figure.core.training", "figure.yoga",
        "figure.pool.swim", "figure.outdoor.cycle", "figure.hiking", "figure.dance",
        "figure.mind.and.body", "figure.cooldown", "figure.flexibility",
        "heart", "heart.fill", "cross.case", "cross.case.fill", "pills",
        "pills.fill", "stethoscope", "bandage", "bandage.fill", "scissors",
        "medical.thermometer", "facemask", "facemask.fill", "syringe", "syringe.fill",
        "lungs", "lungs.fill", "brain.head.profile", "heart.text.square",
        "heart.text.square.fill", "staroflife", "staroflife.fill",

        // Lifestyle and services
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
        "exclamationmark.triangle.fill", "info.circle", "info.circle.fill",
        "ellipsis.circle", "ellipsis.circle.fill"
    ])

    static func search(_ query: String) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return featured }

        let matches = all.filter { symbol in
            symbol.localizedStandardContains(trimmed)
        }
        return uniqueRendered(matches.filter(isValid))
    }

    static func isValid(_ symbol: String) -> Bool {
        UIImage(systemName: symbol.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
    }

    static var selectable: [String] {
        uniqueRendered(all.filter(isValid))
    }

    static func filledVariant(_ symbol: String) -> String {
        let trimmed = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasSuffix(".fill") else { return trimmed }

        let candidate = "\(trimmed).fill"
        return isValid(candidate) ? candidate : trimmed
    }

    private static func unique(_ symbols: [String]) -> [String] {
        var seen = Set<String>()
        return symbols.filter { seen.insert($0).inserted }
    }

    private static func uniqueRendered(_ symbols: [String]) -> [String] {
        var seen = Set<String>()
        return symbols.filter { symbol in
            seen.insert(filledVariant(symbol)).inserted
        }
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

    private let colors = [
        "#22C55E", "#14B8A6", "#06B6D4", "#3B82F6", "#6366F1", "#A855F7",
        "#EC4899", "#F43F5E", "#EF4444", "#F59E0B", "#A16207", "#64748B"
    ]

    init(
        title: String,
        saveTitle: String = AppLocalization.string("action.apply", defaultValue: "Apply"),
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
            ScrollView {
                VStack(spacing: 20) {
                    nameField
                    colorSelectionPanel
                    iconSelectionPanel
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .scrollIndicators(.hidden)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    IconToolbarButton(
                        systemName: "xmark",
                        accessibilityLabel: AppLocalization.string("action.close", defaultValue: "Close")
                    ) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    IconToolbarButton(
                        systemName: "checkmark",
                        accessibilityLabel: saveTitle
                    ) {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
            .alert(AppLocalization.string("error.title", defaultValue: "Error"), isPresented: $showError) {
                Button(AppLocalization.string("action.ok", defaultValue: "OK")) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var selectedColor: Color {
        Color(hex: draft.colorHex) ?? .secondary
    }

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && SFSymbolCatalog.isValid(draft.icon)
            && Color(hex: draft.colorHex) != nil
    }

    private var nameField: some View {
        TextField(AppLocalization.string("field.name", defaultValue: "Name"), text: $draft.name)
            .textInputAutocapitalization(.words)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                Color(uiColor: .secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
    }

    private var colorSelectionPanel: some View {
        IconColorSelectionPanel {
            LazyVGrid(columns: pickerColumns, spacing: 18) {
                ForEach(colors, id: \.self) { colorHex in
                    ColorSwatchButton(
                        color: Color(hex: colorHex) ?? .secondary,
                        isSelected: draft.colorHex == colorHex
                    ) {
                        draft.colorHex = colorHex
                    }
                }
            }
        }
    }

    private var iconSelectionPanel: some View {
        IconColorSelectionPanel {
            LazyVGrid(columns: pickerColumns, spacing: 18) {
                ForEach(SFSymbolCatalog.selectable, id: \.self) { symbol in
                    SymbolCircleButton(
                        symbol: symbol,
                        tintColor: selectedColor,
                        isSelected: draft.icon == symbol
                    ) {
                        draft.icon = symbol
                    }
                }
            }
        }
    }

    private var pickerColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 36, maximum: 56), spacing: 8, alignment: .center),
            count: 6
        )
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

private struct IconColorSelectionPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
            .background(
                Color(uiColor: .secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 30, style: .continuous)
            )
    }
}

private struct ColorSwatchButton: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    Circle()
                        .stroke(Color(uiColor: .systemGray3), lineWidth: 6)
                        .frame(width: 48, height: 48)

                    Circle()
                        .stroke(Color(uiColor: .secondarySystemGroupedBackground), lineWidth: 4)
                        .frame(width: 40, height: 40)
                }

                Circle()
                    .fill(color)
                    .frame(width: 36, height: 36)
            }
            .frame(width: 52, height: 52)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AppLocalization.string("field.color", defaultValue: "Color"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SymbolCircleButton: View {
    let symbol: String
    let tintColor: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    Circle()
                        .stroke(Color(uiColor: .systemGray3), lineWidth: 6)
                        .frame(width: 50, height: 50)

                    Circle()
                        .stroke(Color(uiColor: .secondarySystemGroupedBackground), lineWidth: 4)
                        .frame(width: 42, height: 42)
                }

                Circle()
                    .fill(
                        isSelected
                            ? tintColor
                            : Color(uiColor: .tertiarySystemGroupedBackground)
                    )
                    .frame(width: 40, height: 40)

                Image(systemName: SFSymbolCatalog.filledVariant(symbol))
                    .font(.title3.weight(.semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(
                        isSelected
                            ? IconColorCircleStyle.glyphColor(for: tintColor)
                            : Color(uiColor: .darkGray)
                    )
                    .frame(width: 28, height: 28)
                    .minimumScaleFactor(0.78)
            }
            .frame(width: 54, height: 54)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbol)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
            .navigationTitle(AppLocalization.string("symbol.choose", defaultValue: "Choose Symbol"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: AppLocalization.string("symbol.search", defaultValue: "Search SF Symbols")
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    IconToolbarButton(
                        systemName: "xmark",
                        accessibilityLabel: AppLocalization.string("action.close", defaultValue: "Close")
                    ) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    IconToolbarButton(
                        systemName: "checkmark",
                        accessibilityLabel: AppLocalization.string("action.finish", defaultValue: "Finish")
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

                    TextField(
                        AppLocalization.string(
                            "symbol.manual.placeholder",
                            defaultValue: "Enter any SF Symbol name"
                        ),
                        text: $manualSymbol
                    )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())

                    Button(AppLocalization.string("action.use", defaultValue: "Use")) {
                        useManualSymbol()
                    }
                    .font(.subheadline.weight(.semibold))
                    .disabled(cleanedManualSymbol.isEmpty)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text(
                    manualSymbolIsInvalid
                        ? AppLocalization.string(
                            "symbol.manual.invalid",
                            defaultValue: "This SF Symbol is not available on this iOS version."
                        )
                        : AppLocalization.string(
                            "symbol.manual.help",
                            defaultValue: "Paste any Apple SF Symbol name here."
                        )
                )
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
