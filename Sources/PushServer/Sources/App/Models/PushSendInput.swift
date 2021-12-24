import Vapor

struct PushRegistrationInfo: Content {
    enum CodingKeys: String, CodingKey {
        case appId = "app_id"
        case appVersion = "app_version"
        case osVersion = "os_version"
        case webhookId = "webhook_id"
    }

    var appId: String
    var appVersion: String
    var osVersion: String
    var webhookId: String? // added in core-2021.10

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.appId = try container.decode(String.self, forKey: .appId)
        self.appVersion = try container.decode(String.self, forKey: .appVersion)
        self.osVersion = try container.decode(String.self, forKey: .osVersion)
        self.webhookId = try container.decodeIfPresent(String.self, forKey: .webhookId)
    }

    internal init(appId: String, appVersion: String, osVersion: String, webhookId: String?) {
        self.appId = appId
        self.appVersion = appVersion
        self.osVersion = osVersion
        self.webhookId = webhookId
    }
}

struct PushSendInput: Content {
    enum CodingKeys: String, CodingKey {
        case encrypted = "encrypted"
        case encryptedData = "encrypted_data"
        case registrationInfo = "registration_info"
        case pushToken = "push_token"
    }

    var encrypted: Bool
    var encryptedData: String?
    var registrationInfo: PushRegistrationInfo
    var pushToken: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.pushToken = try container.decode(String.self, forKey: .pushToken)
        self.registrationInfo = try container.decode(PushRegistrationInfo.self, forKey: .registrationInfo)
        self.encrypted = try container.decodeIfPresent(Bool.self, forKey: .encrypted) ?? false
        if encrypted {
            self.encryptedData = try container.decode(String.self, forKey: .encryptedData)
        } else {
            self.encryptedData = try container.decodeIfPresent(String.self, forKey: .encryptedData)
        }
    }

    internal init(encrypted: Bool, encryptedData: String?, registrationInfo: PushRegistrationInfo, pushToken: String) {
        self.encrypted = encrypted
        self.encryptedData = encryptedData
        self.registrationInfo = registrationInfo
        self.pushToken = pushToken
    }
}
