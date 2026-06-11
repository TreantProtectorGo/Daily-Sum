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

enum BalanceTrendPolarity: Equatable {
    case positive
    case negative

    var color: Color {
        switch self {
        case .positive:
            AppColors.income
        case .negative:
            AppColors.expense
        }
    }
}

struct BalanceTrendChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let balance: Decimal
    let polarity: BalanceTrendPolarity
    let segmentID: String

    var balanceValue: Double {
        NSDecimalNumber(decimal: balance).doubleValue
    }
}

enum BalanceTrendChartSeries {
    static func points(from points: [BalanceTrendPoint]) -> [BalanceTrendChartPoint] {
        guard let first = points.first else { return [] }

        var output: [BalanceTrendChartPoint] = []
        var segmentIndex = 0
        var currentPolarity = polarity(for: first.balance, fallback: .positive)

        append(
            first,
            polarity: currentPolarity,
            segmentIndex: segmentIndex,
            to: &output
        )

        for point in points.dropFirst() {
            guard let previous = output.last else { continue }
            let nextPolarity = polarity(for: point.balance, fallback: currentPolarity)

            if nextPolarity != currentPolarity, let zeroDate = zeroCrossingDate(
                from: previous.date,
                previousBalance: previous.balance,
                to: point.date,
                nextBalance: point.balance
            ) {
                let zeroPoint = BalanceTrendPoint(date: zeroDate, balance: 0)
                append(
                    zeroPoint,
                    polarity: currentPolarity,
                    segmentIndex: segmentIndex,
                    to: &output
                )

                segmentIndex += 1
                currentPolarity = nextPolarity
                append(
                    zeroPoint,
                    polarity: currentPolarity,
                    segmentIndex: segmentIndex,
                    to: &output
                )
            }

            append(
                point,
                polarity: currentPolarity,
                segmentIndex: segmentIndex,
                to: &output
            )
        }

        return output
    }

    private static func append(
        _ point: BalanceTrendPoint,
        polarity: BalanceTrendPolarity,
        segmentIndex: Int,
        to output: inout [BalanceTrendChartPoint]
    ) {
        output.append(
            BalanceTrendChartPoint(
                date: point.date,
                balance: point.balance,
                polarity: polarity,
                segmentID: "\(polarity)-\(segmentIndex)"
            )
        )
    }

    private static func polarity(
        for balance: Decimal,
        fallback: BalanceTrendPolarity
    ) -> BalanceTrendPolarity {
        if balance > 0 { return .positive }
        if balance < 0 { return .negative }
        return fallback
    }

    private static func zeroCrossingDate(
        from previousDate: Date,
        previousBalance: Decimal,
        to nextDate: Date,
        nextBalance: Decimal
    ) -> Date? {
        let previousValue = NSDecimalNumber(decimal: previousBalance).doubleValue
        let nextValue = NSDecimalNumber(decimal: nextBalance).doubleValue
        let distance = abs(previousValue) + abs(nextValue)
        guard distance > 0 else { return nil }

        let fraction = abs(previousValue) / distance
        let interval = nextDate.timeIntervalSince(previousDate)
        return previousDate.addingTimeInterval(interval * fraction)
    }
}

struct BalanceTrendSummary {
    var points: [BalanceTrendPoint] = []
    var currentBalance: Decimal = 0
    var startingBalance: Decimal = 0

    var change: Decimal {
        currentBalance - startingBalance
    }
}

enum BalanceTrendDisclosureCopy {
    static func accountText(_ accountCount: Int) -> String {
        AppLocalization.formatted(
            "%lld accounts",
            defaultValue: "%lld accounts",
            Int64(accountCount)
        )
    }

    static func summary(
        range: BalanceTrendRange,
        accountCount: Int,
        hasAccounts: Bool
    ) -> String {
        guard hasAccounts else { return range.title }
        return "\(range.title) · \(accountText(accountCount))"
    }

    static func accessibilityLabel(isExpanded: Bool) -> String {
        isExpanded
            ? AppLocalization.string("balance.trend.hide", defaultValue: "Hide balance trend")
            : AppLocalization.string("balance.trend.show", defaultValue: "Show balance trend")
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
    @AppStorage("dashboard.balanceTrendExpanded") private var isTrendExpanded = false

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

    private var chartPoints: [BalanceTrendChartPoint] {
        BalanceTrendChartSeries.points(from: summary.points)
    }

    private var rangeSummaryText: String {
        let amount = CurrencyFormatter.shared.format(
            summary.change,
            currencyCode: currencyCode,
            showSign: true
        )
        return amount
    }

    var body: some View {
        GlassCard(cornerRadius: 22, padding: 22, style: .hero) {
            VStack(alignment: .leading, spacing: 16) {
                header
                trendDisclosureControl

                if isTrendExpanded {
                    rangeSelector
                    trendExpandedFooter
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.snappy(duration: 0.28), value: isTrendExpanded)
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

    @ViewBuilder
    private var trendDisclosureControl: some View {
        if isTrendExpanded {
            chartSection(isCompact: false)
        } else {
            Button {
                setTrendExpanded(true)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    chartSection(isCompact: true)
                    disclosureSummaryPill
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(BalanceTrendDisclosureCopy.accessibilityLabel(isExpanded: false))
            .accessibilityValue(
                BalanceTrendDisclosureCopy.summary(
                    range: selectedRange,
                    accountCount: accountCount,
                    hasAccounts: hasAccounts
                )
            )
            .accessibilityIdentifier("dashboard.balanceTrend.disclosure")
        }
    }

    private var disclosureSummaryPill: some View {
        HStack(spacing: 8) {
            Text(
                BalanceTrendDisclosureCopy.summary(
                    range: selectedRange,
                    accountCount: accountCount,
                    hasAccounts: hasAccounts
                )
            )
            .font(.caption)
            .fontWeight(.semibold)

            Image(systemName: "chevron.down")
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background {
            Capsule(style: .continuous)
                .fill(.thinMaterial)
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(.secondary.opacity(0.12), lineWidth: 1)
                }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var trendExpandedFooter: some View {
        Button {
            setTrendExpanded(false)
        } label: {
            HStack(spacing: 4) {
                if hasAccounts {
                    Image(systemName: "building.columns.fill")
                        .font(.caption)
                    Text(BalanceTrendDisclosureCopy.accountText(accountCount))
                        .font(.caption)
                }

                Spacer(minLength: 12)

                Image(systemName: "chevron.up")
                    .font(.caption.weight(.semibold))
                    .frame(width: 28, height: 28)
                    .background {
                        Circle()
                            .fill(.thinMaterial)
                            .overlay {
                                Circle()
                                    .stroke(.secondary.opacity(0.12), lineWidth: 1)
                            }
                    }
            }
            .foregroundStyle(.secondary)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(BalanceTrendDisclosureCopy.accessibilityLabel(isExpanded: true))
        .accessibilityValue(
            BalanceTrendDisclosureCopy.summary(
                range: selectedRange,
                accountCount: accountCount,
                hasAccounts: hasAccounts
            )
        )
        .accessibilityIdentifier("dashboard.balanceTrend.collapse")
    }

    private func setTrendExpanded(_ expanded: Bool) {
        withAnimation(.snappy(duration: 0.28)) {
            isTrendExpanded = expanded
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

    private func chartSection(isCompact: Bool) -> some View {
        Chart(chartPoints) { point in
            if !isCompact {
                AreaMark(
                    x: .value("Date", point.date),
                    yStart: .value("HK$0", 0),
                    yEnd: .value("Balance", point.balanceValue),
                    series: .value("Trend Segment", point.segmentID)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [point.polarity.color.opacity(0.22), point.polarity.color.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }

            LineMark(
                x: .value("Date", point.date),
                y: .value("Balance", point.balanceValue),
                series: .value("Trend Segment", point.segmentID)
            )
            .foregroundStyle(isCompact ? point.polarity.color.opacity(0.74) : point.polarity.color)
            .lineStyle(.init(lineWidth: isCompact ? 2 : 3, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.catmullRom)
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            if !isCompact {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))
                        .foregroundStyle(.secondary.opacity(0.24))
                    AxisValueLabel {
                        if let number = value.as(Double.self) {
                            Text(CurrencyFormatter.shared.formatCompact(Decimal(number), currencyCode: currencyCode))
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .frame(height: isCompact ? 44 : 180)
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
