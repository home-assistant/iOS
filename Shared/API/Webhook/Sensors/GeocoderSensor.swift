import Foundation
import PromiseKit
import Iconic
import CoreLocation
import Contacts

public class GeocoderSensor: SensorProvider {
    public enum GeocoderError: Error {
        case noLocation
    }

    public let request: SensorProviderRequest
    required public init(request: SensorProviderRequest) {
        self.request = request
    }

    public func sensors() -> Promise<[WebhookSensor]> {
        return firstly { () -> Promise<[CLPlacemark]> in
            guard let location = request.location else {
                throw GeocoderError.noLocation
            }

            return Current.geocoder.geocode(location)
        }.recover { [request] (error: Error) -> Promise<[CLPlacemark]> in
            guard case GeocoderError.noLocation = error, case .registration = request.reason else { throw error }
            return .value([])
        }.map { (placemarks: [CLPlacemark]) -> [WebhookSensor] in
            let sensor = with(WebhookSensor(name: "Geocoded Location", uniqueID: "geocoded_location")) {
                $0.State = "Unknown"
                $0.Icon = "mdi:\(MaterialDesignIcons.mapIcon.name)"
            }

            guard !placemarks.isEmpty else {
                return [sensor]
            }

            let address: String? = placemarks
                .compactMap(Self.postalAddress(for:))
                .map { CNPostalAddressFormatter.string(from: $0, style: .mailingAddress) }
                .first(where: { $0.isEmpty == false })

            if let address = address {
                sensor.State = address
            }

            sensor.Attributes = Self.attributes(for: placemarks)

            return [sensor]
        }
    }

    private static func attributes(for placemarks: [CLPlacemark]) -> [String: Any] {
        let bestLocation = Self.best(from: placemarks, keyPath: \.location)

        func value(_ keyPath: KeyPath<CLPlacemark, String?>) -> String {
            Self.best(from: placemarks, keyPath: keyPath) ?? "N/A"
        }

        return [
            "Administrative Area": value(\.administrativeArea),
            "Areas Of Interest": Self.best(from: placemarks, keyPath: \.areasOfInterest) ?? "N/A",
            "Country": value(\.country),
            "Inland Water": value(\.inlandWater),
            "ISO Country Code": value(\.isoCountryCode),
            "Locality": value(\.locality),
            "Location": bestLocation.flatMap { [$0.coordinate.latitude, $0.coordinate.longitude] } ?? "N/A",
            "Name": value(\.name),
            "Ocean": value(\.ocean),
            "Postal Code": value(\.postalCode),
            "Sub Administrative Area": value(\.subAdministrativeArea),
            "Sub Locality": value(\.subLocality),
            "Sub Thoroughfare": value(\.subThoroughfare),
            "Thoroughfare": value(\.thoroughfare),
            "Time Zone": Self.best(from: placemarks, keyPath: \.timeZone?.identifier) ?? TimeZone.current.identifier
        ]
    }

    private static func best<ElementType, ReturnType>(
        from: [ElementType],
        keyPath: KeyPath<ElementType, ReturnType?>
    ) -> ReturnType? {
        let results = from.compactMap { $0[keyPath: keyPath] }
        if let nonEmpty = results.first(where: { ($0 as? String)?.isEmpty == false }) {
            return nonEmpty
        } else {
            return results.first
        }
    }

    private static func postalAddress(for placemark: CLPlacemark) -> CNPostalAddress? {
        return placemark.postalAddress
    }
}

public extension CLGeocoder {
    static func geocode(location: CLLocation) -> Promise<[CLPlacemark]> {
        return Promise { seal in
            let geocoder = CLGeocoder()
            var strongGeocoder: CLGeocoder? = geocoder

            let completionHandler: ([CLPlacemark]?, Error?) -> Void = { results, error in
                withExtendedLifetime(strongGeocoder) {
                    seal.resolve(results, error)
                    strongGeocoder = nil
                }
            }

            geocoder.reverseGeocodeLocation(location, preferredLocale: nil, completionHandler: completionHandler)
        }
    }
}
