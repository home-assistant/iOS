import Alamofire
import Foundation
import MobileCoreServices
import PromiseKit
import UIKit
import UserNotifications

public enum NotificationAttachmentManagerServiceError: Error {
    case noAttachment
}

public protocol NotificationAttachmentManager {
    func content(
        from originalContent: UNNotificationContent,
        api: HomeAssistantAPI
    ) -> Guarantee<UNNotificationContent>
    func downloadAttachment(
        from originalContent: UNNotificationContent,
        api: HomeAssistantAPI
    ) -> Promise<URL>
}

class NotificationAttachmentManagerImpl: NotificationAttachmentManager {
    let parsers: [NotificationAttachmentParser.Type]

    convenience init() {
        self.init(parsers: [
            NotificationAttachmentParserURL.self,
            NotificationAttachmentParserCamera.self,
        ])
    }

    init(parsers: [NotificationAttachmentParser.Type]) {
        self.parsers = parsers
    }

    public func content(
        from originalContent: UNNotificationContent,
        api: HomeAssistantAPI
    ) -> Guarantee<UNNotificationContent> {
        let attachmentPromise: Promise<UNNotificationAttachment> = firstly {
            attachmentInfo(from: originalContent)
        }.then { [self] attachmentInfo -> Promise<UNNotificationAttachment> in
            Current.Log.info("using attachment info \(attachmentInfo)")
            return attachment(from: attachmentInfo, api: api)
        }.recover { [self] error -> Promise<UNNotificationAttachment> in
            Current.Log.error("failed at getting attachment info: \(error)")

            if case NotificationAttachmentManagerServiceError.noAttachment = error {
                throw error
            } else if error is URLError || error.asAFError?.isSessionTaskError == true {
                // we'll try loading in the content extension, no need to decorate the thumbnail
                throw error
            } else {
                #if os(iOS)
                return .value(try self.attachment(for: error, api: api))
                #else
                throw error
                #endif
            }
        }

        return firstly {
            Guarantee.value(originalContent)
        }.map { content in
            // swiftlint:disable:next force_cast
            content.mutableCopy() as! UNMutableNotificationContent
        }.then { content in
            when(resolved: attachmentPromise.get { attachment in
                Current.Log.info("adding attachment \(attachment)")
                content.attachments.append(attachment)
            }).map { _ in content }
        }.get { content in
            Current.Log.info("delivering content \(content)")

            withExtendedLifetime(self) {
                // just in case we're not retained by our caller, keep alive through
            }
        }
    }

    public func downloadAttachment(
        from originalContent: UNNotificationContent,
        api: HomeAssistantAPI
    ) -> Promise<URL> {
        firstly {
            attachmentInfo(from: originalContent)
        }.then { attachmentInfo in
            api.DownloadDataAt(url: attachmentInfo.url, needsAuth: attachmentInfo.needsAuth)
        }.recover { error throws -> Promise<URL> in
            if case NotificationAttachmentManagerServiceError.noAttachment = error {
                throw error
            } else {
                #if os(iOS)
                return .value(try self.savedImage(for: error, api: api).0)
                #else
                throw error
                #endif
            }
        }
    }

    private func attachmentInfo(from content: UNNotificationContent) -> Promise<NotificationAttachmentInfo> {
        let concreteParsers = parsers.map { $0.init() }

        return firstly {
            when(fulfilled: concreteParsers.map { $0.attachmentInfo(from: content) })
        }.ensure {
            withExtendedLifetime(concreteParsers) {
                // just to keep the instances alive until they're all done
            }
        }.map { results in
            if let firstSuccess = results.compactMap(\.attachmentInfo).first {
                return firstSuccess
            } else {
                // importantly not using 'missing' for values here
                throw results.compactMap(\.error).first ?? NotificationAttachmentManagerServiceError.noAttachment
            }
        }
    }

    private func attachment(
        from attachmentInfo: NotificationAttachmentInfo,
        api: HomeAssistantAPI
    ) -> Promise<UNNotificationAttachment> {
        guard !attachmentInfo.lazy else {
            return .init(error: NotificationAttachmentManagerServiceError.noAttachment)
        }

        return firstly {
            api.DownloadDataAt(url: attachmentInfo.url, needsAuth: attachmentInfo.needsAuth)
        }.map { url -> UNNotificationAttachment in
            try UNNotificationAttachment(
                identifier: url.lastPathComponent,
                url: url,
                options: attachmentInfo.attachmentOptions
            )
        }
    }

    #if os(iOS)
    private func savedImage(
        for error: Error,
        api: HomeAssistantAPI
    ) throws -> (URL, String) {
        guard let temporaryURL = api.temporaryDownloadFileURL() else {
            throw error
        }

        let localizedString = try NotificationAttachmentErrorImage.saveImage(
            for: error,
            savingTo: temporaryURL
        )

        return (temporaryURL, localizedString)
    }

    private func attachment(
        for error: Error,
        api: HomeAssistantAPI
    ) throws -> UNNotificationAttachment {
        let (url, localizedString) = try savedImage(for: error, api: api)

        return with(try UNNotificationAttachment(
            identifier: "error",
            url: url,
            options: [
                UNNotificationAttachmentOptionsTypeHintKey: kUTTypePNG,
            ]
        )) {
            // note: attachments don't actually support accessibility here (yet?) but this is used also for tests
            $0.accessibilityLabel = localizedString
        }
    }
    #endif
}
