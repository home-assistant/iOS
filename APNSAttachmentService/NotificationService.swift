//
//  NotificationService.swift
//  APNSAttachmentService
//
//  Created by Robbie Trencheny on 9/8/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import UserNotifications
import MobileCoreServices
import Shared
import Alamofire

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

        guard let content = (request.content.mutableCopy() as? UNMutableNotificationContent) else {
            return failEarly()
        }

        var incomingAttachment: [String: Any] = [:]

        if let iAttachment = content.userInfo["attachment"] as? [String: Any] {
            incomingAttachment = iAttachment
        }

        var needsAuth = false

        if content.categoryIdentifier == "camera" && incomingAttachment["url"] == nil {
            guard let entityId = content.userInfo["entity_id"] as? String else {
                return failEarly()
            }

            incomingAttachment["url"] = "/api/camera_proxy/\(entityId)"
            if incomingAttachment["content-type"] == nil {
                incomingAttachment["content-type"] = "jpeg"
            }

            needsAuth = true
        } else {
            // Check if we still have an empty dictionary
            if incomingAttachment.isEmpty {
                // Attachment wasn't there/not a string:any, and this isn't a camera category, so we should fail
                return failEarly()
            }
        }

        guard let attachmentString = incomingAttachment["url"] as? String else {
            return failEarly()
        }

        if attachmentString.hasPrefix("/") { // URL is something like /api or /www so lets prepend base URL
            needsAuth = true
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

        _ = HomeAssistantAPI.authenticatedAPI()?.downloadDataAt(url: attachmentURL,
                                                                needsAuth: needsAuth).done { fileURL in

            do {
                let attachment = try UNNotificationAttachment(identifier: attachmentURL.lastPathComponent, url: fileURL,
                                                              options: attachmentOptions)
                content.attachments.append(attachment)
            } catch let error {
                print("Error when building UNNotificationAttachment: \(error)")

                return failEarly()
            }

            if let copiedContent = content.copy() as? UNNotificationContent {
                contentHandler(copiedContent)
            }
        }.catch { error in

            if let error = error as? AFError, let desc = error.errorDescription {
                print("Alamofire error while getting attachment data", desc)
            } else {
                print("Error when getting attachment data!", error.localizedDescription)
            }

            return failEarly()
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
