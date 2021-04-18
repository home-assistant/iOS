import Foundation
import RealmSwift
import UserNotifications

public final class NotificationCategory: Object, UpdatableModel {
    public static let FallbackActionIdentifier = "_"

    @objc public dynamic var isServerControlled: Bool = false

    @objc public dynamic var Name: String = ""
    @objc public dynamic var Identifier: String = ""
    @objc public dynamic var HiddenPreviewsBodyPlaceholder: String?
    // iOS 12+ only
    @objc public dynamic var CategorySummaryFormat: String?

    // Options
    @objc public dynamic var SendDismissActions: Bool = true
    @objc public dynamic var HiddenPreviewsShowTitle: Bool = false
    @objc public dynamic var HiddenPreviewsShowSubtitle: Bool = false

    // Maybe someday, HA will be on CarPlay (hey that rhymes!)...
    // @objc dynamic var AllowInCarPlay: Bool = false

    public var Actions = List<NotificationAction>()

    override public static func primaryKey() -> String? {
        "Identifier"
    }

    public var options: UNNotificationCategoryOptions {
        var categoryOptions = UNNotificationCategoryOptions([])

        if SendDismissActions { categoryOptions.insert(.customDismissAction) }

        #if os(iOS)
        if HiddenPreviewsShowTitle { categoryOptions.insert(.hiddenPreviewsShowTitle) }
        if HiddenPreviewsShowSubtitle { categoryOptions.insert(.hiddenPreviewsShowSubtitle) }
        #endif

        return categoryOptions
    }

    #if os(iOS)
    public var categories: [UNNotificationCategory] {
        let allActions = Array(Actions.map(\.action))

        // both lowercase and uppercase since this is a point of confusion
        return [Identifier.uppercased(), Identifier.lowercased()].map { anIdentifier in
            UNNotificationCategory(
                identifier: anIdentifier,
                actions: allActions,
                intentIdentifiers: [],
                hiddenPreviewsBodyPlaceholder: self.HiddenPreviewsBodyPlaceholder,
                categorySummaryFormat: self.CategorySummaryFormat,
                options: self.options
            )
        }
    }
    #endif

    public var exampleServiceCall: String {
        let urlStrings = Actions.map { "\"\($0.Identifier)\": \"http://example.com/url\"" }

        let indentation = "\n    "

        return """
        service: notify.mobile_app_#name_here
        data:
          push:
            category: \(Identifier.uppercased())
          action_data:
            # see example trigger in action
            # value will be in fired event

          # url can be absolute path like:
          # "http://example.com/url"
          # or relative like:
          # "/lovelace/dashboard"

          # pick one of the following styles:

          # always open when opening notification
          url: "/lovelace/dashboard"

          # open a different url per action
          # use "\(Self.FallbackActionIdentifier)" as key for no action chosen
          url:
            "\(Self.FallbackActionIdentifier)": "http://example.com/fallback"
            \(urlStrings.joined(separator: indentation))
        """
    }

    static func didUpdate(objects: [NotificationCategory], realm: Realm) {}

    static func willDelete(objects: [NotificationCategory], realm: Realm) {}

    static var updateEligiblePredicate: NSPredicate {
        .init(format: "isServerControlled == YES")
    }

    public func update(with object: MobileAppConfigPushCategory, using realm: Realm) -> Bool {
        if self.realm == nil {
            Identifier = object.identifier.uppercased()
        } else {
            precondition(Identifier == object.identifier.uppercased())
        }

        isServerControlled = true
        Name = object.name

        // TODO: update
        realm.delete(Actions)
        Actions.removeAll()

        Actions.append(objectsIn: object.actions.map { action in
            NotificationAction(action: action)
        })

        return true
    }
}
