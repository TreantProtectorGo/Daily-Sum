import SwiftUI

enum RecentTransactionCurrencyPreference {
    static let storageKey = "flux.transactionCurrency.recentCodes"
    static let maximumCount = 3

    static func currencyCodes(defaults: UserDefaults = .standard) -> [String] {
        let storedCodes = defaults.stringArray(forKey: storageKey) ?? []
        var seenCodes = Set<String>()
        return storedCodes.compactMap { storedCode in
            guard let normalizedCode = TravelCurrencyState.normalizedCurrencyCode(storedCode),
                  seenCodes.insert(normalizedCode).inserted else {
                return nil
            }
            return normalizedCode
        }
        .prefix(maximumCount)
        .map { $0 }
    }

    static func record(
        _ currencyCode: String,
        defaults: UserDefaults = .standard
    ) {
        guard let normalizedCode = TravelCurrencyState.normalizedCurrencyCode(currencyCode) else {
            return
        }
        let updatedCodes = [normalizedCode] + currencyCodes(defaults: defaults).filter {
            $0 != normalizedCode
        }
        defaults.set(Array(updatedCodes.prefix(maximumCount)), forKey: storageKey)
    }
}

struct TransactionCurrencyPickerView: View {
    let selectedCurrencyCode: String?
    let suggestedCurrencyCode: String?
    let availableCurrencies: [SupportedCurrency]
    let onSelect: (String) -> Void

    @State private var isShowingSelection = false

    private var selectedCurrency: SupportedCurrency? {
        selectedCurrencyCode.flatMap(SupportedCurrency.init(rawValue:))
    }

    var body: some View {
        Button {
            isShowingSelection = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "coloncurrencysign.circle")
                    .font(.title3)
                    .foregroundStyle(AppColors.UI.interactiveText)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(
                        AppLocalization.string(
                            "transaction.travel.currency",
                            defaultValue: "Foreign Currency"
                        )
                    )
                    .foregroundStyle(.primary)

                    if let selectedCurrency {
                        Text(
                            "\(selectedCurrency.rawValue) · \(selectedCurrency.localizedName)"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    } else {
                        Text(
                            AppLocalization.string(
                                "settings.exchangeRate.manualTravelCurrency.placeholder",
                                defaultValue: "Select Currency"
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let selectedCurrency {
                    Text(selectedCurrency.symbol)
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("transaction.currencyPicker.trigger")
        .sheet(isPresented: $isShowingSelection) {
            TransactionCurrencySelectionSheet(
                selectedCurrencyCode: selectedCurrencyCode,
                suggestedCurrencyCode: suggestedCurrencyCode,
                availableCurrencies: availableCurrencies
            ) { selectedCode in
                onSelect(selectedCode)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

private struct TransactionCurrencySelectionSheet: View {
    let selectedCurrencyCode: String?
    let suggestedCurrencyCode: String?
    let availableCurrencies: [SupportedCurrency]
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var recentCurrencyCodes =
        RecentTransactionCurrencyPreference.currencyCodes()

    private var availableCurrencyByCode: [String: SupportedCurrency] {
        Dictionary(uniqueKeysWithValues: availableCurrencies.map { ($0.rawValue, $0) })
    }

    private var suggestedCurrency: SupportedCurrency? {
        guard let suggestedCurrencyCode = TravelCurrencyState.normalizedCurrencyCode(
            suggestedCurrencyCode
        ),
        let currency = availableCurrencyByCode[suggestedCurrencyCode],
        matchesSearch(currency) else {
            return nil
        }
        return currency
    }

    private var recentCurrencies: [SupportedCurrency] {
        recentCurrencyCodes.compactMap { availableCurrencyByCode[$0] }.filter { currency in
            currency.rawValue != suggestedCurrency?.rawValue && matchesSearch(currency)
        }
    }

    private var allCurrencies: [SupportedCurrency] {
        let featuredCodes = Set(
            recentCurrencies.map(\.rawValue) + [suggestedCurrency?.rawValue].compactMap { $0 }
        )
        return availableCurrencies.filter { currency in
            !featuredCodes.contains(currency.rawValue) && matchesSearch(currency)
        }
    }

    private var hasResults: Bool {
        suggestedCurrency != nil || !recentCurrencies.isEmpty || !allCurrencies.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                if let suggestedCurrency {
                    Section(
                        AppLocalization.string(
                            "transaction.currencyPicker.suggested",
                            defaultValue: "Suggested by Location"
                        )
                    ) {
                        currencyRow(suggestedCurrency, showsLocationIndicator: true)
                    }
                }

                if !recentCurrencies.isEmpty {
                    Section(
                        AppLocalization.string(
                            "transaction.currencyPicker.recent",
                            defaultValue: "Recently Used"
                        )
                    ) {
                        ForEach(recentCurrencies) { currency in
                            currencyRow(currency)
                        }
                    }
                }

                if !allCurrencies.isEmpty {
                    Section(
                        AppLocalization.string(
                            "transaction.currencyPicker.all",
                            defaultValue: "All Currencies"
                        )
                    ) {
                        ForEach(allCurrencies) { currency in
                            currencyRow(currency)
                        }
                    }
                }

                if !hasResults {
                    ContentUnavailableView.search(text: searchText)
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle(
                AppLocalization.string(
                    "transaction.currencyPicker.title",
                    defaultValue: "Select Currency"
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: AppLocalization.string(
                    "transaction.currencyPicker.search",
                    defaultValue: "Search code or currency name"
                )
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    IconToolbarButton(
                        systemName: "xmark",
                        accessibilityLabel: AppLocalization.string(
                            "action.close",
                            defaultValue: "Close"
                        )
                    ) {
                        dismiss()
                    }
                }
            }
            .accessibilityIdentifier("transaction.currencyPicker.sheet")
        }
    }

    @ViewBuilder
    private func currencyRow(
        _ currency: SupportedCurrency,
        showsLocationIndicator: Bool = false
    ) -> some View {
        Button {
            RecentTransactionCurrencyPreference.record(currency.rawValue)
            recentCurrencyCodes = RecentTransactionCurrencyPreference.currencyCodes()
            onSelect(currency.rawValue)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Text(currency.symbol)
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(AppColors.UI.interactiveText)
                    .frame(width: 38, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(currency.rawValue)
                            .font(.body.monospaced())
                            .foregroundStyle(.primary)

                        if showsLocationIndicator {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(currency.localizedName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if selectedCurrencyCode == currency.rawValue {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.UI.interactiveText)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(
            "transaction.currencyPicker.option.\(currency.rawValue)"
        )
    }

    private func matchesSearch(_ currency: SupportedCurrency) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return currency.rawValue.localizedCaseInsensitiveContains(query) ||
            currency.localizedName.localizedCaseInsensitiveContains(query) ||
            currency.symbol.localizedCaseInsensitiveContains(query)
    }
}
