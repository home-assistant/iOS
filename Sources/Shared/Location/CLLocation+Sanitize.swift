import CoreLocation

extension CLLocation {
    private enum SanitizeFailure: Error {
        case invalid(String)
        case invalidKeyPath
    }

    func sanitized() throws -> CLLocation {
        // FB9030164 iOS 14.5 (at least betas) started reporting vertical accuracy as non-finite
        var doubleKeyPaths: [KeyPath<CLLocation, Double>: Result<Double, SanitizeFailure>] = [
            \.horizontalAccuracy: .failure(.invalid("horizontalAccuracy")),
            \.verticalAccuracy: .success(-1),
            \.altitude: .success(0),
            \.coordinate.latitude: .failure(.invalid("latitude")),
            \.coordinate.longitude: .failure(.invalid("longitude")),
            \.course: .success(-1),
            \.speed: .success(-1),
            \.speedAccuracy: .success(-1),
        ]

        if #available(iOS 13.4, watchOS 6.2, *) {
            doubleKeyPaths[\.courseAccuracy] = .success(-1)
        }

        func isValid(_ value: Double) -> Bool {
            value.isFinite && !value.isNaN
        }

        func sanitize(_ keyPath: KeyPath<CLLocation, Double>) throws -> Double {
            let value = self[keyPath: keyPath]
            if isValid(value) {
                return value
            } else {
                if let fallback = doubleKeyPaths[keyPath] {
                    return try fallback.get()
                } else {
                    throw SanitizeFailure.invalidKeyPath
                }
            }
        }

        let needsSanitization = !doubleKeyPaths.keys.allSatisfy({ isValid(self[keyPath: $0]) })

        guard needsSanitization else { return self }

        let sanitizedCoordinate = try CLLocationCoordinate2D(
            latitude: sanitize(\.coordinate.latitude),
            longitude: sanitize(\.coordinate.longitude)
        )

        if #available(iOS 13.4, watchOS 6.2, *) {
            return try CLLocation(
                coordinate: sanitizedCoordinate,
                altitude: sanitize(\.altitude),
                horizontalAccuracy: sanitize(\.horizontalAccuracy),
                verticalAccuracy: sanitize(\.verticalAccuracy),
                course: sanitize(\.course),
                courseAccuracy: sanitize(\.courseAccuracy),
                speed: sanitize(\.speed),
                speedAccuracy: sanitize(\.speedAccuracy),
                timestamp: timestamp
            )
        } else {
            return try CLLocation(
                coordinate: sanitizedCoordinate,
                altitude: sanitize(\.altitude),
                horizontalAccuracy: sanitize(\.horizontalAccuracy),
                verticalAccuracy: sanitize(\.verticalAccuracy),
                course: sanitize(\.course),
                speed: sanitize(\.speed),
                timestamp: timestamp
            )
        }
    }
}
