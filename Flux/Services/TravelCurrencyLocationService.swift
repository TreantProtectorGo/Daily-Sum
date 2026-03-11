import CoreLocation
import Foundation
import MapKit

enum TravelLocationAuthorizationStatus {
    case notDetermined
    case denied
    case restricted
    case authorized
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

    private var authorizationContinuation: CheckedContinuation<TravelLocationAuthorizationStatus, Never>?
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    init(locationManager: CLLocationManager = CLLocationManager()) {
        self.locationManager = locationManager
        super.init()
        self.locationManager.delegate = self
    }

    func authorizationStatus() -> TravelLocationAuthorizationStatus {
        mapAuthorizationStatus(locationManager.authorizationStatus)
    }

    func requestAuthorizationIfNeeded() async -> TravelLocationAuthorizationStatus {
        let currentStatus = authorizationStatus()
        guard currentStatus == .notDetermined else {
            return currentStatus
        }

        return await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            locationManager.requestWhenInUseAuthorization()
        }
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
        await withCheckedContinuation { continuation in
            locationContinuation = continuation
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
        guard let continuation = authorizationContinuation else {
            return
        }

        let status = authorizationStatus()
        guard status != .notDetermined else {
            return
        }

        authorizationContinuation = nil
        continuation.resume(returning: status)
    }

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let continuation = locationContinuation else {
            return
        }

        locationContinuation = nil
        continuation.resume(returning: locations.last)
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        guard let continuation = locationContinuation else {
            return
        }

        locationContinuation = nil
        continuation.resume(returning: nil)
    }
}
