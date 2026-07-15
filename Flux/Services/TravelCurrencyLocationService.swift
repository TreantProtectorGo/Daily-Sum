import CoreLocation
import Foundation
import MapKit

enum TravelLocationAuthorizationStatus: Equatable {
    case notDetermined
    case denied
    case restricted
    case authorized
}

enum TravelCurrencyLocationSelection {
    static let maximumCachedLocationAge: TimeInterval = 2 * 60

    static func isRecent(
        _ location: CLLocation,
        now: Date = .now,
        maximumAge: TimeInterval = maximumCachedLocationAge
    ) -> Bool {
        let age = now.timeIntervalSince(location.timestamp)
        let horizontalAccuracy = location.horizontalAccuracy
        return horizontalAccuracy.isFinite &&
            horizontalAccuracy >= 0 &&
            horizontalAccuracy <= kCLLocationAccuracyThreeKilometers &&
            age >= 0 &&
            age <= maximumAge
    }
}

@MainActor
final class OneShotRequestBroker<Value> {
    private var continuations: [UUID: CheckedContinuation<Value?, Never>] = [:]
    private var isRequestInFlight = false
    private(set) var requestStartCount = 0
    var waiterCount: Int { continuations.count }

    func wait(start: () -> Void) async -> Value? {
        let requestID = UUID()
        let value: Value? = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(returning: nil)
                    return
                }

                let shouldStartRequest = !isRequestInFlight
                continuations[requestID] = continuation
                if shouldStartRequest {
                    isRequestInFlight = true
                    requestStartCount += 1
                    start()
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.cancel(requestID)
            }
        }
        return Task.isCancelled ? nil : value
    }

    func resolve(_ value: Value?) {
        isRequestInFlight = false
        let pendingContinuations = continuations.values
        continuations.removeAll()
        for continuation in pendingContinuations {
            continuation.resume(returning: value)
        }
    }

    private func cancel(_ requestID: UUID) {
        guard let continuation = continuations.removeValue(forKey: requestID) else {
            return
        }
        continuation.resume(returning: nil)
    }
}

@MainActor
protocol TravelCurrencyLocationServicing {
    func authorizationStatus() -> TravelLocationAuthorizationStatus
    func requestAuthorizationIfNeeded() async -> TravelLocationAuthorizationStatus
    func detectLocalCurrency() async -> SupportedCurrency?
}

@MainActor
final class TravelCurrencyLocationService: NSObject, TravelCurrencyLocationServicing {
    private let locationManager: CLLocationManager

    private let authorizationBroker = OneShotRequestBroker<TravelLocationAuthorizationStatus>()
    private let locationBroker = OneShotRequestBroker<CLLocation>()

    init(locationManager: CLLocationManager = CLLocationManager()) {
        self.locationManager = locationManager
        super.init()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    func authorizationStatus() -> TravelLocationAuthorizationStatus {
        mapAuthorizationStatus(locationManager.authorizationStatus)
    }

    func requestAuthorizationIfNeeded() async -> TravelLocationAuthorizationStatus {
        let currentStatus = authorizationStatus()
        guard currentStatus == .notDetermined else {
            return currentStatus
        }

        return await authorizationBroker.wait {
            locationManager.requestWhenInUseAuthorization()
        } ?? authorizationStatus()
    }

    func detectLocalCurrency() async -> SupportedCurrency? {
        guard authorizationStatus() == .authorized else {
            return nil
        }

        guard let location = await requestLocation() else {
            return nil
        }

        guard let regionCode = await reverseGeocodeRegionCode(for: location) else {
            return nil
        }

        return SupportedCurrency.currency(forRegionCode: regionCode)
    }

    private func requestLocation() async -> CLLocation? {
        if let cachedLocation = locationManager.location,
           TravelCurrencyLocationSelection.isRecent(cachedLocation) {
            return cachedLocation
        }

        return await locationBroker.wait {
            locationManager.requestLocation()
        }
    }

    private func reverseGeocodeRegionCode(for location: CLLocation) async -> String? {
        guard let request = MKReverseGeocodingRequest(location: location) else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            request.getMapItems { mapItems, _ in
                let regionCode = mapItems?.first?.addressRepresentations?.region?.identifier
                continuation.resume(returning: regionCode)
            }
        }
    }

    private func mapAuthorizationStatus(
        _ status: CLAuthorizationStatus
    ) -> TravelLocationAuthorizationStatus {
        switch status {
        case .notDetermined:
            .notDetermined
        case .restricted:
            .restricted
        case .denied:
            .denied
        case .authorizedAlways, .authorizedWhenInUse:
            .authorized
        @unknown default:
            .denied
        }
    }
}

extension TravelCurrencyLocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = authorizationStatus()
        guard status != .notDetermined else {
            return
        }
        authorizationBroker.resolve(status)
    }

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        locationBroker.resolve(locations.last)
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        locationBroker.resolve(nil)
    }
}
