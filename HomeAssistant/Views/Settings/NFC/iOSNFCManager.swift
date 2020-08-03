import Foundation
import PromiseKit
import CoreNFC
import Shared

// swiftlint:disable:next type_name
class iOSNFCManager: NFCManager {
    var isAvailable: Bool {
        NFCNDEFReaderSession.readingAvailable
    }

    func read() -> Promise<String> {
        if #available(iOS 13, *) {
            let reader = NFCReader()
            var readerRetain: NFCReader? = reader

            return firstly {
                reader.promise
            }.ensure {
                withExtendedLifetime(readerRetain) {
                    readerRetain = nil
                }
            }.then {
                Self.identifier(from: $0)
            }
        } else {
            return .init(error: NFCManagerError.unavailable)
        }
    }

    func write(value: String) -> Promise<String> {
        if #available(iOS 13, *) {
            guard let payload = NFCNDEFPayload.wellKnownTypeURIPayload(url: Self.url(for: value)) else {
                return .init(error: NFCManagerError.notHomeAssistantTag)
            }

            let message = NFCNDEFMessage(records: [ payload ])
            let writer = NFCWriter(message: message)
            var writerRetain: NFCWriter? = writer

            return firstly {
                writer.promise
            }.ensure {
                withExtendedLifetime(writerRetain) {
                    writerRetain = nil
                }
            }.then {
                // we use the same logic as reading, so we can be sure the identifier is right
                Self.identifier(from: message)
            }
        } else {
            return .init(error: NFCManagerError.unavailable)
        }
    }

    func handle(userActivity: NSUserActivity) -> NFCManagerHandleResult {
        guard let url = userActivity.webpageURL else {
            return .unhandled
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        if let tag = Self.identifier(from: url) {
            fireEvent(tag: tag).cauterize()
            return .handled
        }

        if let urlString = components?.queryItems?.first(where: { $0.name.lowercased() == "url" })?.value,
           let url = URL(string: urlString) {
            return .open(url)
        }

        return .unhandled
    }

    private static func url(for identifier: String) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.home-assistant.io"
        components.path = "/nfc/" + identifier
        return components.url!
    }

    private static func identifier(from url: URL) -> String? {
        if url.pathComponents.starts(with: ["/", "nfc"]) {
            // ["/", "nfc", "5f0ba733-172f-430d-a7f8-e4ad940c88d7"] for example
            let value = url.pathComponents.dropFirst(2).joined(separator: "/")
            if !value.isEmpty {
                return value
            } else {
                return nil
            }
        } else {
            return nil
        }
    }

    @available(iOS 13, *)
    private static func identifier(from message: NFCNDEFMessage) -> Promise<String> {
        firstly {
            .value(message.records)
        }.compactMapValues { payload in
            payload.wellKnownTypeURIPayload()
        }.compactMapValues { url -> String? in
            Self.identifier(from: url)
        }.map {
            if let value = $0.first {
                return value
            } else {
                throw NFCManagerError.notHomeAssistantTag
            }
        }
    }

}
