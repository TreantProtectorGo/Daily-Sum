import Foundation

struct ExchangeRateSnapshot {
    let baseCurrencyCode: String
    let effectiveDate: Date
    let rates: [String: Decimal]
    let provider: String
}

protocol ExchangeRateProvider {
    var providerName: String { get }

    func fetchRates(
        baseCurrencyCode: String,
        quoteCurrencyCodes: [String],
        on date: Date?
    ) async throws -> ExchangeRateSnapshot
}

enum ExchangeRateProviderError: LocalizedError {
    case invalidRequest
    case invalidResponse
    case invalidDateFormat
    case httpFailure(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Unable to build exchange rate request."
        case .invalidResponse:
            return "Exchange rate provider returned an invalid response."
        case .invalidDateFormat:
            return "Exchange rate provider returned an unexpected date format."
        case .httpFailure(let statusCode):
            return "Exchange rate request failed with status code \(statusCode)."
        }
    }
}

struct HKMAExchangeRateProvider: ExchangeRateProvider {
    private struct APIResponse: Decodable {
        let result: ResultPayload
    }

    private struct ResultPayload: Decodable {
        let records: [Record]
    }

    private struct Record: Decodable {
        let endOfDay: String
        let usd: Double?
        let gbp: Double?
        let jpy: Double?
        let cad: Double?
        let aud: Double?
        let sgd: Double?
        let twd: Double?
        let chf: Double?
        let cny: Double?
        let krw: Double?
        let eur: Double?

        enum CodingKeys: String, CodingKey {
            case endOfDay = "end_of_day"
            case usd
            case gbp
            case jpy
            case cad
            case aud
            case sgd
            case twd
            case chf
            case cny
            case krw
            case eur
        }
    }

    let providerName = "hkma"

    private let session: URLSession
    private let baseURL: URL

    init(
        session: URLSession? = nil,
        baseURL: URL = URL(
            string: "https://api.hkma.gov.hk/public/market-data-and-statistics/monthly-statistical-bulletin/er-ir/er-eeri-daily"
        )!
    ) {
        self.session = session ?? Self.makeDefaultSession()
        self.baseURL = baseURL
    }

    func fetchRates(
        baseCurrencyCode: String,
        quoteCurrencyCodes: [String],
        on date: Date?
    ) async throws -> ExchangeRateSnapshot {
        let normalizedBase = baseCurrencyCode.uppercased()
        let normalizedQuotes = Array(Set(quoteCurrencyCodes.map { $0.uppercased() }))
            .filter { $0 != normalizedBase }
            .sorted()

        if normalizedQuotes.isEmpty {
            return ExchangeRateSnapshot(
                baseCurrencyCode: normalizedBase,
                effectiveDate: normalizedDay(date ?? .now),
                rates: [:],
                provider: providerName
            )
        }

        let record = try await fetchRecord(on: date)
        let hkdRates = hkdPerUnitForeignCurrency(from: record)

        guard let baseToHKD = hkdRates[normalizedBase], baseToHKD > 0 else {
            throw ExchangeRateProviderError.invalidResponse
        }

        let rates = try normalizedQuotes.reduce(into: [String: Decimal]()) { partialResult, quote in
            guard let quoteToHKD = hkdRates[quote], quoteToHKD > 0 else {
                throw ExchangeRateProviderError.invalidResponse
            }
            let rate = baseToHKD / quoteToHKD
            partialResult[quote] = NSDecimalNumber(value: rate).decimalValue
        }

        guard let effectiveDate = Self.apiDateFormatter.date(from: record.endOfDay) else {
            throw ExchangeRateProviderError.invalidDateFormat
        }

        return ExchangeRateSnapshot(
            baseCurrencyCode: normalizedBase,
            effectiveDate: normalizedDay(effectiveDate),
            rates: rates,
            provider: providerName
        )
    }

    private func fetchRecord(on date: Date?) async throws -> Record {
        if date == nil {
            let firstPage = try await fetchPage(offset: 0)
            guard let latest = firstPage.first else {
                throw ExchangeRateProviderError.invalidResponse
            }
            return latest
        }

        let targetDate = normalizedDay(date ?? .now)
        var offset = 0

        while true {
            let records = try await fetchPage(offset: offset)
            if records.isEmpty {
                throw ExchangeRateProviderError.invalidResponse
            }

            var oldestRecordDate: Date?

            for record in records {
                guard let recordDate = Self.apiDateFormatter.date(from: record.endOfDay) else {
                    throw ExchangeRateProviderError.invalidDateFormat
                }

                oldestRecordDate = recordDate
                if recordDate <= targetDate {
                    return record
                }
            }

            guard let oldestRecordDate else {
                throw ExchangeRateProviderError.invalidResponse
            }

            if normalizedDay(oldestRecordDate) <= targetDate {
                throw ExchangeRateProviderError.invalidResponse
            }

            offset += records.count
        }
    }

    private func fetchPage(offset: Int) async throws -> [Record] {
        guard let url = buildURL(offset: offset) else {
            throw ExchangeRateProviderError.invalidRequest
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ExchangeRateProviderError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ExchangeRateProviderError.httpFailure(statusCode: httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(APIResponse.self, from: data)
        return decoded.result.records
    }

    private func buildURL(offset: Int) -> URL? {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }

        components.queryItems = [
            URLQueryItem(name: "offset", value: String(offset))
        ]
        return components.url
    }

    private func hkdPerUnitForeignCurrency(from record: Record) -> [String: Double] {
        var rates: [String: Double] = [
            "HKD": 1
        ]

        if let usd = record.usd { rates["USD"] = usd }
        if let gbp = record.gbp { rates["GBP"] = gbp }
        if let jpy = record.jpy { rates["JPY"] = jpy }
        if let cad = record.cad { rates["CAD"] = cad }
        if let aud = record.aud { rates["AUD"] = aud }
        if let sgd = record.sgd { rates["SGD"] = sgd }
        if let twd = record.twd { rates["TWD"] = twd }
        if let chf = record.chf { rates["CHF"] = chf }
        if let cny = record.cny { rates["CNY"] = cny }
        if let krw = record.krw { rates["KRW"] = krw }
        if let eur = record.eur { rates["EUR"] = eur }

        return rates
    }

    private static let apiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private func normalizedDay(_ date: Date) -> Date {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return utcCalendar.startOfDay(for: date)
    }

    private static func makeDefaultSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 20
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }
}
