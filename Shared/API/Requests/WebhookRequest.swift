//
//  WebhookRequest.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 2/26/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper
import Sodium

public class WebhookRequest: Mappable {
    var PayloadType: String?
    var Data: Any?
    var Encrypted: Bool = false
    var EncryptedData: String?

    init() {}

    required public init?(map: Map) {}

    public convenience init(type: String, data: Any) {
        self.init()
        self.PayloadType = type
        self.Data = data

        if let secret = Current.settingsStore.webhookSecret {
            let sodium = Sodium()

            guard let jsonData = try? JSONSerialization.data(withJSONObject: data, options: []) else {
                Current.Log.error("Unable to convert JSON dictionary to data!")
                return
            }

            guard let jsonStr = String(data: jsonData, encoding: .utf8) else {
                Current.Log.error("Unable to convert JSON data to string!")
                return
            }

            let key: Bytes = Array(secret.bytes[0..<sodium.secretBox.KeyBytes])

            guard let encryptedData: Bytes = sodium.secretBox.seal(message: jsonStr.bytes,
                                                                   secretKey: key) else {
                Current.Log.error("Unable to generate encrypted webhook payload! Secret: \(secret), JSON: \(jsonStr)")
                return
            }

            guard let b64payload = sodium.utils.bin2base64(encryptedData, variant: .ORIGINAL) else {
                Current.Log.error("Unable to encode encrypted payload to base64!")
                return
            }

            self.EncryptedData = b64payload
            self.Encrypted = true
            self.Data = nil
        }
    }

    public func mapping(map: Map) {
        PayloadType           <- map["type"]
        Data                  <- map["data"]
        Encrypted             <- map["encrypted"]
        EncryptedData         <- map["encrypted_data"]
    }
}
