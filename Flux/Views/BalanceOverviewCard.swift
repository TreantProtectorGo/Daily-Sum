import SwiftUI
import SwiftData
import Charts

enum BalanceTrendRange: String, CaseIterable, Identifiable {
    case week
    case oneMonth
    case threeMonths
    case oneYear
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week:
            "1W"
        case .oneMonth:
            "1M"
        case .threeMonths:
            "3M"
        case .oneYear:
            "1Y"
        case .all:
            "All"
        }
    }

    var summaryTitle: String {
        switch self {
        case .week:
            AppLocalization.string("balance.range.week", defaultValue: "1W")
        case .oneMonth:
            AppLocalization.string("balance.range.oneMonth", defaultValue: "1M")
        case .threeMonths:
            AppLocalization.string("balance.range.threeMonths", defaultValue: "3M")
        case .oneYear:
            AppLocalization.string("balance.range.oneYear", defaultValue: "1Y")
        case .all:
            AppLocalization.string("balance.range.all", defaultValue: "All")
        }
    }

    func startDate(now: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .week:
            calendar.date(byAdding: .day, value: -6, to: now)
        case .oneMonth:
            calendar.date(byAdding: .month, value: -1, to: now)
        case .threeMonths:
            calendar.date(byAdding: .month, value: -3, to: now)
        case .oneYear:
            calendar.date(byAdding: .year, value: -1, to: now)
        case .all:
            nil
        }
    }
}

struct BalanceTrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let balance: Decimal

    var balanceValue: Double {
        NSDecimalNumber(decimal: balance).doubleValue
    }
}

struct BalanceTrendSummary {
    var points: [BalanceTrendPoint] = []
    var currentBalance: Decimal = 0
    var startingBalance: Decimal = 0

    var change: Decimal {
        currentBalance - startingBalance
    }

    var percentChange: Decimal {
        guard startingBalance != 0 else { return 0 }
        return change / abs(startingBalance) * 100
    }
}

enum BalanceTrendCalculator {
    static func percentageText(_ percent: Decimal) -> String {
        let value = NSDecimalNumber(decimal: percent).doubleValue
        let formatted = value.formatted(
            .number
                .precision(.fractionLength(2))
                .sign(strategy: .always())
        )
        return "\(formatted)%"
    }
}

@Observable
@MainActor
final class BalanceTrendViewModel {
    private let modelContext: ModelContext
    private let conversionService: CurrencyConversionService
    private let currencyCode: String

    var summary = BalanceTrendSummary()
    var isLoading = false
    var errorMessage: String?

    init(
        modelContext: ModelContext,
        currencyCode: String,
        conversionService: CurrencyConversionService? = nil
    ) {
        self.modelContext = modelContext
        self.currencyCode = currencyCode
        self.conversionService = conversionService ?? CurrencyConversionService(context: modelContext)
    }

    func load(range: BalanceTrendRange) async {
        isLoading = true
        errorMessage = nil

        do {
            let currentBalance = try await currentTotalBalance()
            let points = try await buildPoints(range: range, currentTotal: currentBalance)
            let startingBalance = points.first?.balance ?? currentBalance

            summary = BalanceTrendSummary(
                points: points,
                currentBalance: currentBalance,
                startingBalance: startingBalance
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func buildPoints(
        range: BalanceTrendRange,
        currentTotal: Decimal
    ) async throws -> [BalanceTrendPoint] {
        let now = Date.now
        let calendar = Calendar.current
        let start = try startDate(for: range, now: now, calendar: calendar)
        let transactions = try transactionsSince(start)
        let sampleDates = sampleDates(from: start, to: now, calendar: calendar)
        var points: [BalanceTrendPoint] = []

        for sampleDate in sampleDates {
            let futureDelta = try await convertedSignedTotal(
                transactions.filter { $0.date > sampleDate && $0.date <= now }
            )
            points.append(BalanceTrendPoint(date: sampleDate, balance: currentTotal - futureDelta))
        }

        return points
    }

    private func startDate(
        for range: BalanceTrendRange,
        now: Date,
        calendar: Calendar
    ) throws -> Date {
        if let date = range.startDate(now: now, calendar: calendar) {
            return calendar.startOfDay(for: date)
        }

        return calendar.startOfDay(for: try earliestIncludedActivityDate(defaultDate: now))
    }

    private func earliestIncludedActivityDate(defaultDate: Date) throws -> Date {
        let accounts = try modelContext.fetch(FetchDescriptor<Account>())
            .filter(\.includeInTotal)
        let earliestAccountDate = accounts.map(\.createdAt).min()
        let includedAccountIDs = Set(accounts.map(\.id))
        let transactionDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> {
                !$0.isRecurringTemplate
            }
        )
        let earliestTransactionDate = try modelContext.fetch(transactionDescriptor)
            .filter { transaction in
                guard let account = transaction.account else {
                    return true
                }
                return includedAccountIDs.contains(account.id)
            }
            .map(\.date)
            .min()

        return [earliestAccountDate, earliestTransactionDate]
            .compactMap { $0 }
            .min() ?? defaultDate
    }

    private func currentTotalBalance() async throws -> Decimal {
        let descriptor = FetchDescriptor<Account>()
        let accounts = try modelContext.fetch(descriptor)
        var total: Decimal = 0

        for account in accounts where account.includeInTotal {
            total += try await conversionService.convert(
                account.currentBalance,
                from: account.currencyCode,
                to: currencyCode,
                on: .now,
                mode: .defaultForDashboard
            )
        }

        return total
    }

    private func transactionsSince(_ start: Date) throws -> [Transaction] {
        let now = Date.now
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> {
                !$0.isRecurringTemplate && $0.date >= start && $0.date <= now
            }
        )
        return try modelContext.fetch(descriptor)
            .filter { $0.account?.includeInTotal != false }
    }

    private func convertedSignedTotal(_ transactions: [Transaction]) async throws -> Decimal {
        var total: Decimal = 0

        for transaction in transactions {
            let converted = try await conversionService.convert(
                transaction.signedAmount,
                from: transaction.currencyCode,
                to: currencyCode,
                on: transaction.date,
                mode: .defaultForDashboard
            )
            total += converted
        }

        return total
    }

    private func sampleDates(from start: Date, to end: Date, calendar: Calendar) -> [Date] {
        let days = max(calendar.dateComponents([.day], from: start, to: end).day ?? 0, 1)
        let targetCount = min(max(days + 1, 2), 24)
        let step = max(days / max(targetCount - 1, 1), 1)
        var dates: [Date] = []
        var offset = 0

        while offset < days {
            if let date = calendar.date(byAdding: .day, value: offset, to: start) {
                dates.append(date)
            }
            offset += step
        }

        dates.append(end)
        return dates
    }
}

struct BalanceOverviewCard: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: BalanceTrendViewModel?
    @State private var selectedRange: BalanceTrendRange = .week
    @State private var showInfo = false

    let totalBalance: Decimal
    let accountCount: Int
    let hasAccounts: Bool
    let currencyCode: String

    private var summary: BalanceTrendSummary {
        viewModel?.summary ?? BalanceTrendSummary(
            currentBalance: totalBalance,
            startingBalance: totalBalance
        )
    }

    private var trendColor: Color {
        summary.change < 0 ? AppColors.expense : AppColors.income
    }

    private var rangeSummaryText: String {
        let amount = CurrencyFormatter.shared.format(
            summary.change,
            currencyCode: currencyCode,
            showSign: true
        )
        let percent = BalanceTrendCalculator.percentageText(summary.percentChange)
        return "\(selectedRange.summaryTitle) \(amount) (\(percent))"
    }

    var body: some View {
        GlassCard(cornerRadius: 22, padding: 22, style: .hero) {
            VStack(alignment: .leading, spacing: 16) {
                header
                chartSection
                rangeSelector
                accountCountLabel
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("dashboard.totalBalance.card")
        .task {
            if viewModel == nil {
                viewModel = BalanceTrendViewModel(
                    modelContext: modelContext,
                    currencyCode: currencyCode
                )
            }
            await viewModel?.load(range: selectedRange)
        }
        .onChange(of: selectedRange) { _, newValue in
            Task {
                await viewModel?.load(range: newValue)
            }
        }
        .alert(
            AppLocalization.string("balance.info.title", defaultValue: "How this is calculated"),
            isPresented: $showInfo
        ) {
            Button(AppLocalization.string("action.ok", defaultValue: "OK")) { }
        } message: {
            Text(
                AppLocalization.string(
                    "balance.info.message",
                    defaultValue: "This trend estimates past total balance from current included account balances and recorded transactions. It is not investment market performance."
                )
            )
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Text(AppLocalization.string("dashboard.totalBalance", defaultValue: "Total Balance"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(currency: totalBalance, code: currencyCode)
                    .font(.system(size: 36, weight: .bold))
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)

                Text(rangeSummaryText)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(trendColor)
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button {
                showInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(AppLocalization.string("balance.info", defaultValue: "About balance trend"))
        }
    }

    private var chartSection: some View {
        Chart(summary.points) { point in
            AreaMark(
                x: .value("Date", point.date),
                y: .value("Balance", point.balanceValue)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [trendColor.opacity(0.28), trendColor.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)

            LineMark(
                x: .value("Date", point.date),
                y: .value("Balance", point.balanceValue)
            )
            .foregroundStyle(trendColor)
            .lineStyle(.init(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.catmullRom)
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))
                    .foregroundStyle(.secondary.opacity(0.28))
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(CurrencyFormatter.shared.formatCompact(Decimal(number), currencyCode: currencyCode))
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .frame(height: 180)
        .overlay {
            if viewModel?.isLoading == true {
                ProgressView()
            } else if summary.points.isEmpty {
                Text(AppLocalization.string("balance.trend.empty", defaultValue: "No trend data yet"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("dashboard.balanceTrend.chart")
    }

    private var rangeSelector: some View {
        HStack(spacing: 6) {
            ForEach(BalanceTrendRange.allCases) { range in
                Button {
                    selectedRange = range
                } label: {
                    Text(range.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .foregroundStyle(selectedRange == range ? AppColors.selectedNavigation : .secondary)
                        .background {
                            if selectedRange == range {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(AppColors.selectedNavigation.opacity(0.12))
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityIdentifier("balance.range.selector")
    }

    @ViewBuilder
    private var accountCountLabel: some View {
        if hasAccounts {
            HStack(spacing: 4) {
                Image(systemName: "building.columns.fill")
                    .font(.caption)
                Text("\(accountCount) accounts")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
    }
}

#Preview("Balance Overview Card") {
    BalanceOverviewCard(
        totalBalance: 18_301.07,
        accountCount: 3,
        hasAccounts: true,
        currencyCode: "HKD"
    )
    .padding()
    .modelContainer(for: [Account.self, Transaction.self], inMemory: true)
}
