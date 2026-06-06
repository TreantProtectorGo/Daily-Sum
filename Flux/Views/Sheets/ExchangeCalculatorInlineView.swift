import SwiftUI
import SwiftData

struct ExchangeCalculatorInlineView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ExchangeCalculatorViewModel?

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .task {
            if viewModel == nil {
                viewModel = ExchangeCalculatorViewModel(modelContext: modelContext)
            }
            await viewModel?.initializeDefaults()
        }
    }

    private func content(viewModel: ExchangeCalculatorViewModel) -> some View {
        Group {
            Text(
                AppLocalization.string(
                    "exchangeCalculator.title",
                    defaultValue: "Exchange Calculator"
                )
            )
            .font(.subheadline.weight(.semibold))

            VStack(alignment: .leading, spacing: 14) {
                AmountInputView(
                    amount: Binding(
                        get: { viewModel.amount },
                        set: { viewModel.amount = $0 }
                    ),
                    currencyCode: viewModel.fromCurrencyCode,
                    autoFocus: false,
                    useGlassBackground: false,
                    useOuterPadding: false
                )

                Divider()

                HStack(alignment: .center, spacing: 8) {
                    if let convertedAmount = viewModel.convertedAmount {
                        Text(currency: convertedAmount, code: viewModel.toCurrencyCode)
                            .font(.title3.weight(.semibold))
                    } else {
                        Text("--")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                HStack {
                    Text(
                        AppLocalization.string(
                            "exchangeCalculator.rate",
                            defaultValue: "Rate"
                        )
                    )
                    Spacer()
                    if let rate = viewModel.exchangeRate {
                        Text(
                            "1 \(viewModel.fromCurrencyCode) = \(CurrencyFormatter.shared.format(rate, currencyCode: viewModel.toCurrencyCode))"
                        )
                        .foregroundStyle(.secondary)
                    } else {
                        Text("--")
                            .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)

                    Button(
                        AppLocalization.string(
                            "exchangeCalculator.retry",
                            defaultValue: "Retry"
                        )
                    ) {
                        viewModel.retry()
                    }
                }
            }
            .padding(16)
            .glassBackground(cornerRadius: 12, isInteractive: true, style: .section)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            Picker(
                AppLocalization.string(
                    "exchangeCalculator.from",
                    defaultValue: "From"
                ),
                selection: Binding(
                    get: { viewModel.fromCurrencyCode },
                    set: { viewModel.fromCurrencyCode = $0 }
                )
            ) {
                ForEach(SupportedCurrency.allCases, id: \.self) { currency in
                    Text("\(currency.symbol) \(currency.rawValue) - \(currency.localizedName)")
                        .tag(currency.rawValue)
                }
            }

            Picker(
                AppLocalization.string(
                    "exchangeCalculator.to",
                    defaultValue: "To"
                ),
                selection: Binding(
                    get: { viewModel.toCurrencyCode },
                    set: { viewModel.toCurrencyCode = $0 }
                )
            ) {
                ForEach(SupportedCurrency.allCases, id: \.self) { currency in
                    Text("\(currency.symbol) \(currency.rawValue) - \(currency.localizedName)")
                        .tag(currency.rawValue)
                }
            }

            Button {
                viewModel.swapCurrencies()
            } label: {
                Label(
                    AppLocalization.string(
                        "exchangeCalculator.swap",
                        defaultValue: "Swap Currencies"
                    ),
                    systemImage: "arrow.up.arrow.down"
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 12) {
                    Text(
                        AppLocalization.string(
                            "settings.exchangeRate.lastUpdated",
                            defaultValue: "Last Updated"
                        )
                    )
                    .foregroundStyle(.secondary)

                    Spacer()

                    Text(viewModel.lastUpdatedText)
                        .foregroundStyle(.secondary)

                    Button {
                        Task {
                            await viewModel.refreshExchangeRates(force: true)
                        }
                    } label: {
                        if viewModel.isRefreshingRates {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text(
                                AppLocalization.string(
                                    "settings.exchangeRate.refreshNow",
                                    defaultValue: "Refresh Now"
                                )
                            )
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isRefreshingRates)
                }

                if viewModel.isExchangeRateSyncStale {
                    Text(
                        AppLocalization.string(
                            "settings.exchangeRate.staleWarning",
                            defaultValue: "Rates may be outdated. Refresh to improve accuracy."
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
        }
        .onChange(of: viewModel.amount) { _, _ in
            viewModel.scheduleCalculation()
        }
        .onChange(of: viewModel.fromCurrencyCode) { _, _ in
            viewModel.scheduleCalculation()
        }
        .onChange(of: viewModel.toCurrencyCode) { _, _ in
            viewModel.scheduleCalculation()
        }
    }
}

#Preview("Inline Exchange Calculator") {
    do {
        let container = try ModelContainerConfiguration.createPreviewContainer()
        return Form {
            Section("Exchange Rates") {
                ExchangeCalculatorInlineView()
            }
        }
        .modelContainer(container)
    } catch {
        return Text("Preview Error: \(error.localizedDescription)")
    }
}
