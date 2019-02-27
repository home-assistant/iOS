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

class WebhookRequest: Mappable {
    var PayloadType: String?
    var Data: [String: Any]?
    var Encrypted: Bool = false
    var EncryptedData: String?

    init() {}

    required init?(map: Map) {}

    public convenience init(type: String, data: [String: Any]) {
        self.init()
        self.PayloadType = type

        if let secret = Current.settingsStore.webhookSecret {
            let sodium = Sodium()

            guard let jsonData = try? JSONSerialization.data(withJSONObject: data, options: []) else {
                fatalError("Unable to convert JSON dictionary to data!")
            }

            guard let jsonStr = String(data: jsonData, encoding: .utf8) else {
                fatalError("Unable to convert JSON data to string!")
            }

            let encryptedDataBytes: Bytes = sodium.secretBox.seal(message: jsonStr.bytes, secretKey: secret.bytes)!

            guard let b64payload = sodium.utils.bin2base64(encryptedDataBytes, variant: .ORIGINAL) else {
                fatalError("Unable to encode encrypted payload to base64!")
            }

            self.EncryptedData = b64payload
            self.Encrypted = true
        } else {
            self.Data = data
        }
    }

    func mapping(map: Map) {
        PayloadType           <- map["type"]
        Data                  <- map["data"]
        Encrypted             <- map["encrypted"]
        EncryptedData         <- map["encrypted_data"]
    }
}
