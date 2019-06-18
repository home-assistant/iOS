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
import PromiseKit

final class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    // swiftlint:disable cyclomatic_complexity function_body_length
    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        Current.Log.verbose("APNSAttachmentService started!")
        Current.Log.verbose("Received userInfo \(request.content.userInfo)")

        // FIXME: Memory leak caued by ClientEvent/Realm.
        /* let event = ClientEvent(text: request.content.clientEventTitle, type: .notification,
                                payload: request.content.userInfo as? [String: Any])
        Current.clientEventStore.addEvent(event) */

        Current.Log.debug("Added client event")

        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        Current.Log.debug("Set bestAttemptContent")

        func failEarly(_ reason: String) {
            Current.Log.error("Failing early because \(reason)!")
            contentHandler(request.content)
        }

        guard let content = (request.content.mutableCopy() as? UNMutableNotificationContent) else {
            return failEarly("Unable to get mutable copy of notification content")
        }

        guard var incomingAttachment = content.userInfo["attachment"] as? [String: Any] else {
            return failEarly("Attachment dictionary not in payload")
        }

        var needsAuth = false

        if content.categoryIdentifier.hasPrefix("camera") && incomingAttachment["url"] == nil {
            Current.Log.debug("Camera cat prefix")
            guard let entityId = content.userInfo["entity_id"] as? String else {
                return failEarly("Category identifier was prefixed camera but no entity_id was set")
            }

            incomingAttachment["url"] = "/api/camera_proxy/\(entityId)"
            if incomingAttachment["content-type"] == nil {
                incomingAttachment["content-type"] = "jpeg"
            }

            needsAuth = true
            Current.Log.debug("Camera so requiring auth")
        } else {
            Current.Log.debug("Not a camera notification")
            // Check if we still have an empty dictionary
            if incomingAttachment.isEmpty {
                // Attachment wasn't there/not a string:any, and this isn't a camera category, so we should fail
                return failEarly("Content dictionary was not empty")
            }
        }

        guard let attachmentString = incomingAttachment["url"] as? String else {
            return failEarly("url string did not exist in dictionary")
        }

        if attachmentString.hasPrefix("/") { // URL is something like /api or /www so lets prepend base URL
            Current.Log.debug("Appears to be local URL, requiring auth")
            needsAuth = true
        }

        guard let attachmentURL = URL(string: attachmentString) else {
            return failEarly("Could not convert string to URL")
        }

        var attachmentOptions: [String: Any] = [:]
        if let attachmentContentType = incomingAttachment["content-type"] as? String {
            attachmentOptions[UNNotificationAttachmentOptionsTypeHintKey] =
                self.contentTypeForString(attachmentContentType)
        }

        if let attachmentHideThumbnail = incomingAttachment["hide-thumbnail"] as? Bool {
            attachmentOptions[UNNotificationAttachmentOptionsThumbnailHiddenKey] = attachmentHideThumbnail
        }

        Current.Log.debug("Set attachment options to \(attachmentOptions)s")

        Current.Log.verbose("Going to get URL at \(attachmentURL)")

        firstly {
            return HomeAssistantAPI.authenticatedAPIPromise
        }.then { api in
            return api.DownloadDataAt(url: attachmentURL, needsAuth: needsAuth)
        }.done { fileURL in
            do {
                let attachment = try UNNotificationAttachment(identifier: attachmentURL.lastPathComponent, url: fileURL,
                                                              options: attachmentOptions)
                content.attachments.append(attachment)
            } catch let error {
                return failEarly("Unable to build UNNotificationAttachment: \(error)")
            }

            Current.Log.debug("Successfully created and appended attachment \(content.attachments)")

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

            Current.Log.debug("About to return")

            guard let copiedContent = content.copy() as? UNNotificationContent else {
                return failEarly("Unable to copy contents")
            }

            Current.Log.debug("Returning \(copiedContent)")

            contentHandler(copiedContent)
        }.catch { error in
            var reason = "Error when getting attachment data! \(error)"
            if let error = error as? AFError {
                reason = "Alamofire error while getting attachment data: \(error)"
            }

            return failEarly(reason)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content,
        // otherwise the original push payload will be used.
        Current.Log.warning("serviceExtensionTimeWillExpire")
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
