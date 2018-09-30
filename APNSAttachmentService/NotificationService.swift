//
//  NotificationService.swift
//  APNSAttachmentService
//
//  Created by Robbie Trencheny on 9/8/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import UserNotifications
import MobileCoreServices
import KeychainAccess
import Shared

final class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    // swiftlint:disable cyclomatic_complexity
    // swiftlint:disable function_body_length
    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        print("APNSAttachmentService started!")
        print("Received userInfo", request.content.userInfo)

        let event = ClientEvent(text: request.content.clientEventTitle, type: .notification,
                                payload: request.content.userInfo as? [String: Any])
        Current.clientEventStore.addEvent(event)

        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        func failEarly() {
            contentHandler(request.content)
        }

        let keychain = Keychain(service: "io.robbie.homeassistant")
        guard let baseURL = keychain["baseURL"] else {
            return failEarly()
        }
        guard let apiPassword = keychain["apiPassword"] else {
            return failEarly()
        }

        guard let content = (request.content.mutableCopy() as? UNMutableNotificationContent) else {
            return failEarly()
        }

        var incomingAttachment: [String: Any] = [:]

        if let iAttachment = content.userInfo["attachment"] as? [String: Any] {
            incomingAttachment = iAttachment
        }

        if content.categoryIdentifier == "camera" && incomingAttachment["url"] == nil {
            guard let entityId = content.userInfo["entity_id"] as? String else {
                return failEarly()
            }

            incomingAttachment["url"] = "\(baseURL)/api/camera_proxy/\(entityId)?api_password=\(apiPassword)"
            if incomingAttachment["content-type"] == nil {
                incomingAttachment["content-type"] = "jpeg"
            }
        } else {
            // Check if we still have an empty dictionary
            if incomingAttachment.isEmpty {
                // Attachment wasn't there/not a string:any, and this isn't a camera category, so we should fail
                return failEarly()
            }
        }

        guard var attachmentString = incomingAttachment["url"] as? String else {
            return failEarly()
        }

        if attachmentString.hasPrefix("/api/") { // prepend base URL
            attachmentString = baseURL + attachmentString
        }

        guard let attachmentURL = URL(string: attachmentString) else {
            return failEarly()
        }

        var attachmentOptions: [String: Any] = [:]
        if let attachmentContentType = incomingAttachment["content-type"] as? String {
            attachmentOptions[UNNotificationAttachmentOptionsTypeHintKey] =
                self.contentTypeForString(attachmentContentType)
        }

        if let attachmentHideThumbnail = incomingAttachment["hide-thumbnail"] as? Bool {
            attachmentOptions[UNNotificationAttachmentOptionsThumbnailHiddenKey] = attachmentHideThumbnail
        }

        guard let attachmentData = NSData(contentsOf: attachmentURL) else { return failEarly() }
        guard let attachment = UNNotificationAttachment.create(fileIdentifier: attachmentURL.lastPathComponent,
                                                               data: attachmentData,
                                                               options: attachmentOptions) else {
                                                                return failEarly()
        }

        content.attachments.append(attachment)

        // Attempt to fill in the summary argument with the thread or category ID if it doesn't exist in payload.
        if #available(iOS 12.0, *) {
            if content.summaryArgument == "" {
                if content.threadIdentifier != "" {
                    content.summaryArgument = content.threadIdentifier
                } else if content.categoryIdentifier != "" {
                    content.summaryArgument = content.categoryIdentifier
                }
            }
        }

        if let copiedContent = content.copy() as? UNNotificationContent {
            contentHandler(copiedContent)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content,
        // otherwise the original push payload will be used.
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

    private func contentTypeForString(_ contentTypeString: String) -> CFString {
        let contentType: CFString
        switch contentTypeString.lowercased() {
        case "aiff":
            contentType = kUTTypeAudioInterchangeFileFormat
        case "avi":
            contentType = kUTTypeAVIMovie
        case "gif":
            contentType = kUTTypeGIF
        case "jpeg", "jpg":
            contentType = kUTTypeJPEG
        case "mp3":
            contentType = kUTTypeMP3
        case "mpeg":
            contentType = kUTTypeMPEG
        case "mpeg2":
            contentType = kUTTypeMPEG2Video
        case "mpeg4":
            contentType = kUTTypeMPEG4
        case "mpeg4audio":
            contentType = kUTTypeMPEG4Audio
        case "png":
            contentType = kUTTypePNG
        case "waveformaudio":
            contentType = kUTTypeWaveformAudio
        default:
            contentType = contentTypeString as CFString
        }

        return contentType
    }
}

extension UNNotificationAttachment {

    /// Save the attachment URL to disk
    static func create(fileIdentifier: String, data: NSData,
                       options: [AnyHashable: Any]?) -> UNNotificationAttachment? {
        let fileManager = FileManager.default
        let tmpSubFolderName = ProcessInfo.processInfo.globallyUniqueString
        let tmpSubFolderURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(tmpSubFolderName,
                                                                                                    isDirectory: true)

        do {
            try fileManager.createDirectory(at: tmpSubFolderURL!, withIntermediateDirectories: true, attributes: nil)
            let fileURL = tmpSubFolderURL?.appendingPathComponent(fileIdentifier)
            try data.write(to: fileURL!, options: [])
            return try UNNotificationAttachment.init(identifier: "", url: fileURL!, options: options)
        } catch let error {
            print("Error when saving attachment: \(error)")
        }

        return nil
    }
}
