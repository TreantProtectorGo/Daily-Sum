import Foundation

@MainActor
struct TravelCurrencyPreferenceRefresher {
    private let locationService: any TravelCurrencyLocationServicing

    init(locationService: (any TravelCurrencyLocationServicing)? = nil) {
        self.locationService = locationService ?? TravelCurrencyLocationService()
    }

    @discardableResult
    func refreshDetectedTravelCurrency() async -> String? {
        guard locationService.authorizationStatus() == .authorized else {
            return TravelCurrencyPreference.detectedCurrencyCode
        }

        if let detectedCurrencyCode = await locationService.detectLocalCurrency()?.rawValue {
            TravelCurrencyPreference.detectedCurrencyCode = detectedCurrencyCode
        }

        return TravelCurrencyPreference.detectedCurrencyCode
    }
}
