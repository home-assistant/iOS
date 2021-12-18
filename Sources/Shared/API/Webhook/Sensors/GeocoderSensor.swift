import Contacts
import CoreLocation
import Foundation
import PromiseKit

public class GeocoderSensor: SensorProvider {
    public enum GeocoderError: Error {
        case noLocation
    }

    internal enum UserDefaultsKeys: String {
        case geocodeUseZone = "geocoded_location_use_zone"

        var title: String {
            switch self {
            case .geocodeUseZone: return L10n.Sensors.GeocodedLocation.Setting.useZones
            }
        }
    }

    public let request: SensorProviderRequest
    public required init(request: SensorProviderRequest) {
        self.request = request
    }

    public func sensors() -> Promise<[WebhookSensor]> {
        firstly { () -> Promise<[CLPlacemark]> in
            guard let location = request.location else {
                throw GeocoderError.noLocation
            }

            return Current.geocoder.geocode(location)
        }.recover { [request] (error: Error) -> Promise<[CLPlacemark]> in
            guard case GeocoderError.noLocation = error, case .registration = request.reason else { throw error }
            return .value([])
        }.map { [request] (placemarks: [CLPlacemark]) -> [WebhookSensor] in
            let sensor = with(WebhookSensor(name: "Geocoded Location", uniqueID: "geocoded_location")) {
                $0.State = "Unknown"
                $0.Icon = "mdi:\(MaterialDesignIcons.mapIcon.name)"
                $0.Settings = [
                    .init(type: .switch(getter: {
                        Current.settingsStore.prefs.bool(forKey: UserDefaultsKeys.geocodeUseZone.rawValue)
                    }, setter: {
                        Current.settingsStore.prefs.set($0, forKey: UserDefaultsKeys.geocodeUseZone.rawValue)
                    }), title: UserDefaultsKeys.geocodeUseZone.title),
                ]
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

            var attributes = Self.attributes(for: placemarks)

            if let location = request.location {
                let insideZones = Current.realm().objects(RLMZone.self)
                    .filter(RLMZone.trackablePredicate)
                    .sorted(byKeyPath: "Radius")
                    .filter { $0.circularRegion.contains(location.coordinate) }
                    .map { $0.FriendlyName ?? $0.Name }
                    .filter { $0 != "" }

                if let zone = insideZones.first,
                   Current.settingsStore.prefs.bool(forKey: UserDefaultsKeys.geocodeUseZone.rawValue) {
                    // only override if there's something to set, and only if the user wants us to do so
                    sensor.State = zone
                }

                // needs to be explicitly typed or the JSON encoding will barf
                attributes["Zones"] = Array(insideZones)
            }

            sensor.Attributes = attributes

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
            "Time Zone": Self.best(from: placemarks, keyPath: \.timeZone?.identifier) ?? TimeZone.current.identifier,
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
        if let address = placemark.postalAddress {
            return address
        }

        return with(CNMutablePostalAddress()) {
            $0.street = placemark.thoroughfare ?? ""
            $0.city = placemark.locality ?? ""
            $0.state = placemark.administrativeArea ?? ""
            $0.postalCode = placemark.postalCode ?? ""

            // matching behavior with iOS 11+, prefer iso country code
            $0.country = placemark.isoCountryCode ?? placemark.country ?? ""

            if #available(iOS 10.3, *) {
                $0.subLocality = placemark.subLocality ?? ""
                $0.subAdministrativeArea = placemark.subAdministrativeArea ?? ""
            }
        }
    }
}

public extension CLGeocoder {
    static func geocode(location: CLLocation) -> Promise<[CLPlacemark]> {
        Promise { seal in
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
