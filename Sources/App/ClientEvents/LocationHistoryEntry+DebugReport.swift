import CoreLocation
import Shared

extension LocationHistoryEntry {
    /// A Markdown report of the entry for a bug report: the payload that was sent, where the device was,
    /// and how that location relates to every region the app monitors.
    func debugReport() -> String {
        var value = "# Debug Information\n\n"

        let accuracyNote: String

        if accuracy == 65 {
            accuracyNote = " (from Wi-Fi)"
        } else if accuracy == 1414 {
            accuracyNote = " (from cell tower)"
        } else {
            accuracyNote = ""
        }

        let accuracyAuthorization: String

        if let authorization = clAccuracyAuthorization {
            switch authorization {
            case .fullAccuracy: accuracyAuthorization = "full"
            case .reducedAccuracy: accuracyAuthorization = "reduced"
            @unknown default: accuracyAuthorization = "unknown"
            }
        } else {
            accuracyAuthorization = "missing"
        }

        func latLongString(_ value: Double) -> String {
            String(format: "%.06lf", value)
        }

        func distanceString(_ value: Double) -> String {
            String(format: "%04.02lfm", max(0, value))
        }

        value.append(
            """
            ## Payload
            ```json
            \(payload)
            ```

            ## Location
            - Trigger: \(trigger ?? "(unknown)")
            - Center: (\(latLongString(latitude)), \(latLongString(longitude)))
            - Accuracy: \(distanceString(accuracy))\(accuracyNote)
            - Accuracy Authorization: \(accuracyAuthorization)

            ## Regions
            """ + "\n"
        )

        let allRegions = AppZone.all()
            .flatMap(\.circularRegionsForMonitoring)
            .sorted(by: { a, b in
                a.distanceWithAccuracy(from: clLocation) < b.distanceWithAccuracy(from: clLocation)
            })
        for region in allRegions {
            let regionLocation = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
            let distanceWithoutAccuracy = regionLocation.distance(from: clLocation)
            let distanceWithAccuracy = region.distanceWithAccuracy(from: clLocation)
            let contains = region.containsWithAccuracy(clLocation)

            value.append(
                """
                ### \(region.identifier)
                - Center: (\(latLongString(region.center.latitude)), \(latLongString(region.center.longitude)))
                - Radius: \(distanceString(region.radius))
                - Distance From Perimeter: \(distanceString(distanceWithAccuracy))
                - Distance From Center: \(distanceString(distanceWithoutAccuracy))
                - Relative State: \(contains ? "inside" : "outside")
                """
            )

            value.append("\n\n")
        }

        return value
    }
}
