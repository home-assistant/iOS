import CoreLocation
import Foundation
import HAKit
import Intents
import MapKit
import UIColor_Hex_Swift

public extension CallServiceIntent {
    convenience init(domain: String, service: String) {
        self.init()
        self.service = "\(domain).\(service)"
    }

    convenience init(domain: String, service: String, payload: Any?) {
        self.init()
        self.service = "\(domain).\(service)"

        if let payload, let jsonData = try? JSONSerialization.data(withJSONObject: payload),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            self.payload = jsonString
        }
    }
}

public extension FireEventIntent {
    convenience init(eventName: String) {
        self.init()
        self.eventName = eventName
    }

    convenience init(eventName: String, payload: Any?) {
        self.init()
        self.eventName = eventName

        if let payload, let jsonData = try? JSONSerialization.data(withJSONObject: payload),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            self.eventData = jsonString
        }
    }
}

public extension SendLocationIntent {
    convenience init(place: CLPlacemark) {
        self.init()
        self.location = place
    }

    convenience init(location: CLLocation) {
        self.init()

        // We use MKPlacemark so we can return a CLPlacemark without requiring use of the geocoder
        self.location = MKPlacemark(coordinate: location.coordinate)
    }
}

public extension PerformActionIntent {
    convenience init(action: Action) {
        self.init()
        self.action = .init(action: action)

        #if os(iOS)
        let image = INImage(
            icon: MaterialDesignIcons(named: action.IconName),
            foreground: UIColor(hex: action.IconColor),
            background: UIColor(hex: action.BackgroundColor)
        )

        // this should be:
        //   setImage(image, forParameterNamed: \Self.action)
        // but this crashes at runtime, iOS 13 and iOS 14 at least
        __setImage(image, forParameterNamed: "action")
        #endif
    }
}

public extension IntentAction {
    convenience init(action: Action) {
        #if os(iOS)
        self.init(
            identifier: action.ID,
            display: action.Name,
            subtitle: nil,
            image: INImage(
                icon: MaterialDesignIcons(named: action.IconName),
                foreground: UIColor(hex: action.IconColor),
                background: UIColor(hex: action.BackgroundColor)
            )
        )
        #else
        self.init(identifier: action.ID, display: action.Name)
        #endif
    }

    func asActionWithUpdated() -> (updated: IntentAction, action: Action)? {
        guard let action = asAction() else {
            return nil
        }

        return (.init(action: action), action)
    }

    func asAction() -> Action? {
        guard let identifier, identifier.isEmpty == false else {
            return nil
        }

        guard let result = Current.realm().object(ofType: Action.self, forPrimaryKey: identifier) else {
            return nil
        }

        return result
    }
}

public extension WidgetActionsIntent {
    static let widgetKind = "WidgetActions"
}

public extension IntentPanel {
    convenience init(panel: HAPanel, server: Server) {
        let image: INImage?

        let icon = panel.icon?.normalizingIconString

        #if os(iOS)
        image = icon.flatMap { icon in
            INImage(
                icon: Self.materialDesignIcon(for: icon),
                foreground: Constants.tintColor.resolvedColor(with: .init(userInterfaceStyle: .light)),
                background: .white
            )
        }
        #else
        image = nil
        #endif

        if #available(watchOS 7, *) {
            self.init(
                identifier: panel.path,
                display: panel.title,
                subtitle: nil,
                image: image
            )
        } else if Current.servers.all.count > 1 {
            self.init(
                identifier: panel.path,
                display: panel.title + " (\(server.info.name))"
            )
        } else {
            self.init(identifier: panel.path, display: panel.title)
        }
        self.icon = icon
        self.serverIdentifier = server.identifier.rawValue
    }

    var widgetURL: URL {
        var components = URLComponents()
        components.scheme = "homeassistant"
        components.host = "navigate"
        components.path = "/" + (identifier ?? "lovelace")
        if let server = Current.servers.server(for: self) {
            components.insertWidgetServer(server: server)
        }
        return components.url!
    }

    private static func materialDesignIcon(for name: String?) -> MaterialDesignIcons {
        MaterialDesignIcons(serversideValueNamed: name ?? "", fallback: .cogOutlineIcon)
    }

    var materialDesignIcon: MaterialDesignIcons {
        Self.materialDesignIcon(for: icon)
    }
}

public extension WidgetOpenPageIntent {
    static let widgetKind = "WidgetOpenPage"
}

public extension IntentServer {
    convenience init(server: Server) {
        self.init(identifier: server.identifier.rawValue, display: server.info.name)
    }

    static var all: [IntentServer] {
        Current.servers.all.map { IntentServer(server: $0) }
    }
}
