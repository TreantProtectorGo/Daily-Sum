import SwiftUI
import SwiftData

struct ExchangeCalculatorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel: ExchangeCalculatorViewModel?
    @State private var selectedDetent: PresentationDetent = .large

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    calculatorForm(viewModel: viewModel)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(
                AppLocalization.string(
                    "exchangeCalculator.title",
                    defaultValue: "Exchange Calculator"
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(AppLocalization.string("action.cancel", defaultValue: "Cancel"))
                }
            }
            .task {
                if viewModel == nil {
                    viewModel = ExchangeCalculatorViewModel(modelContext: modelContext)
                }
                await viewModel?.initializeDefaults()
            }
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
    }

    private func calculatorForm(viewModel: ExchangeCalculatorViewModel) -> some View {
        Form {
            amountAndResultSection(viewModel: viewModel)
            currencySection(viewModel: viewModel)
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

    private func amountAndResultSection(viewModel: ExchangeCalculatorViewModel) -> some View {
        Section(
            AppLocalization.string(
                "exchangeCalculator.amount",
                defaultValue: "Amount"
            )
        ) {
            VStack(alignment: .leading, spacing: 14) {
                AmountInputView(
                    amount: Binding(
                        get: { viewModel.amount },
                        set: { viewModel.amount = $0 }
                    ),
                    currencyCode: viewModel.fromCurrencyCode,
                    autoFocus: true,
                    useGlassBackground: false,
                    useOuterPadding: false
                )

                Divider()

                HStack(alignment: .center, spacing: 8) {
                    if let convertedAmount = viewModel.convertedAmount {
                        Text(currency: convertedAmount, code: viewModel.toCurrencyCode)
                            .font(.title2.weight(.semibold))
                    } else {
                        Text("--")
                            .font(.title2.weight(.semibold))
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
            .glassBackground(cornerRadius: 12, isInteractive: true)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    private func currencySection(viewModel: ExchangeCalculatorViewModel) -> some View {
        Section {
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
        }
    }
}

#Preview("Exchange Calculator") {
    do {
        let container = try ModelContainerConfiguration.createPreviewContainer()
        return ExchangeCalculatorSheet()
            .modelContainer(container)
    } catch {
        return Text("Preview Error: \(error.localizedDescription)")
    }
}
