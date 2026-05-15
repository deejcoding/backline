//
//  LocationHelper.swift
//  backline
//
//  Created by Khadija Aslam on 4/30/26.
//

import CoreLocation

/// Provides a one-shot async wrapper around CoreLocation.
enum LocationHelper {

    enum LocationError: LocalizedError {
        case denied
        case failed(Error)

        var errorDescription: String? {
            switch self {
            case .denied: return "Location access denied."
            case .failed(let err): return err.localizedDescription
            }
        }
    }

    /// Held to keep the delegate alive until the continuation resumes.
    private static var activeDelegate: Delegate?

    /// Requests when-in-use authorization (if needed) and returns a single location fix.
    @MainActor
    static func requestCurrentLocation() async throws -> CLLocationCoordinate2D {
        try await withCheckedThrowingContinuation { continuation in
            let delegate = Delegate(continuation: continuation) {
                // Clean up the retained reference once finished
                LocationHelper.activeDelegate = nil
            }
            activeDelegate = delegate
            delegate.start()
        }
    }

    // MARK: - Private delegate

    private final class Delegate: NSObject, CLLocationManagerDelegate {
        private let manager = CLLocationManager()
        private var continuation: CheckedContinuation<CLLocationCoordinate2D, Error>?
        private var didResume = false
        private let onFinish: () -> Void

        init(continuation: CheckedContinuation<CLLocationCoordinate2D, Error>, onFinish: @escaping () -> Void) {
            self.continuation = continuation
            self.onFinish = onFinish
            super.init()
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        }

        func start() {
            let status = manager.authorizationStatus
            switch status {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            default:
                resume(with: .failure(LocationError.denied))
            }
        }

        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                resume(with: .failure(LocationError.denied))
            default:
                break
            }
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            if let loc = locations.first {
                resume(with: .success(loc.coordinate))
            }
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            resume(with: .failure(LocationError.failed(error)))
        }

        private func resume(with result: Result<CLLocationCoordinate2D, Error>) {
            guard !didResume else { return }
            didResume = true
            switch result {
            case .success(let coord): continuation?.resume(returning: coord)
            case .failure(let err): continuation?.resume(throwing: err)
            }
            continuation = nil
            onFinish()
        }
    }
}
