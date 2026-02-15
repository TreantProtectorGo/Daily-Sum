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

struct FrankfurterExchangeRateProvider: ExchangeRateProvider {
    private struct APIResponse: Decodable {
        let base: String
        let date: String
        let rates: [String: Double]
    }

    let providerName = "frankfurter"

    private let session: URLSession
    private let baseURL: URL

    init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://api.frankfurter.app")!
    ) {
        self.session = session
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

        guard let url = buildURL(
            baseCurrencyCode: normalizedBase,
            quoteCurrencyCodes: normalizedQuotes,
            date: date
        ) else {
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
        guard let effectiveDate = Self.apiDateFormatter.date(from: decoded.date) else {
            throw ExchangeRateProviderError.invalidDateFormat
        }

        let rates = decoded.rates.reduce(into: [String: Decimal]()) { partialResult, item in
            partialResult[item.key.uppercased()] = NSDecimalNumber(value: item.value).decimalValue
        }

        return ExchangeRateSnapshot(
            baseCurrencyCode: decoded.base.uppercased(),
            effectiveDate: normalizedDay(effectiveDate),
            rates: rates,
            provider: providerName
        )
    }

    private func buildURL(
        baseCurrencyCode: String,
        quoteCurrencyCodes: [String],
        date: Date?
    ) -> URL? {
        var url = baseURL
        if let date {
            url.append(path: Self.apiDateFormatter.string(from: normalizedDay(date)))
        } else {
            url.append(path: "latest")
        }

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "from", value: baseCurrencyCode),
            URLQueryItem(name: "to", value: quoteCurrencyCodes.joined(separator: ","))
        ]

        return components.url
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
}
