import Foundation
import HAKit
import ObjectMapper

public struct MobileAppConfigAction: HADataDecodable, UpdatableModelSource {
    var name: String
    var backgroundColor: String?
    var labelText: String?
    var labelColor: String?
    var iconIcon: String?
    var iconColor: String?

    public init(data: HAData) throws {
        self.name = try data.decode("name")
        self.backgroundColor = data.decode("background_color", fallback: nil)
        self.labelText = data.decode("label.text", fallback: nil)
        self.labelColor = data.decode("label.color", fallback: nil)
        self.iconIcon = data.decode("icon.icon", fallback: nil)
        self.iconColor = data.decode("icon.color", fallback: nil)
    }

    public var primaryKey: String { name }
}

public struct MobileAppConfigPushCategory: HADataDecodable, UpdatableModelSource {
    public struct Action: HADataDecodable {
        public var title: String
        public var identifier: String
        public var authenticationRequired: Bool
        public var behavior: String
        public var activationMode: String
        public var destructive: Bool
        public var textInputButtonTitle: String?
        public var textInputPlaceholder: String?
        public var url: String?

        public init(data: HAData) throws {
            self.title = data.decode("title", fallback: "Missing title")
            // we fall back to 'action' for android-style dynamic actions
            if let identifier: String = try? data.decode("identifier") {
                self.identifier = identifier
            } else {
                self.identifier = data.decode("action", fallback: "missing")
            }

            self.authenticationRequired = data.decode("authenticationRequired", fallback: false)
            self.behavior = data.decode("behavior", fallback: "default")
            self.activationMode = data.decode("activationMode", fallback: "background")
            self.destructive = data.decode("destructive", fallback: false)
            self.textInputButtonTitle = data.decode("textInputButtonTitle", fallback: nil)
            self.textInputPlaceholder = data.decode("textInputPlaceholder", fallback: nil)
            for urlKey in ["url", "uri"] {
                if let value: String = try? data.decode(urlKey) {
                    // a url is set, which means this is likely coming from an actionable notification
                    // so assume that it wants activation for it
                    self.url = value
                    self.activationMode = "foreground"
                }
            }

            if identifier.lowercased() == "reply" {
                // matching Android behavior
                self.behavior = "textinput"
            }
        }
    }

    public var name: String
    public var identifier: String
    public var actions: [Action]

    public init(data: HAData) throws {
        let name: String = try data.decode("name")
        self.name = name
        self.identifier = data.decode("identifier", fallback: name)
        self.actions = data.decode("actions", fallback: [])
    }

    public var primaryKey: String { identifier.uppercased() }
}

public struct MobileAppConfigPush: HADataDecodable {
    public var categories: [MobileAppConfigPushCategory]

    internal init(categories: [MobileAppConfigPushCategory] = []) {
        self.categories = []
    }

    public init(data: HAData) throws {
        self.categories = data.decode("categories", fallback: [])
    }
}

public struct MobileAppConfig: HADataDecodable {
    public var push: MobileAppConfigPush
    public var actions: [MobileAppConfigAction]

    internal init(push: MobileAppConfigPush = .init(), actions: [MobileAppConfigAction] = []) {
        self.push = push
        self.actions = actions
    }

    public init(data: HAData) throws {
        self.push = data.decode("push", fallback: MobileAppConfigPush())
        self.actions = data.decode("actions", fallback: [])
    }
}
