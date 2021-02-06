import CoreNFC
import Foundation
import PromiseKit
import Shared

@available(iOS 13, *)
class NFCWriter: NSObject, NFCNDEFReaderSessionDelegate {
    private var readerSession: NFCNDEFReaderSession!
    public let promise: Promise<NFCNDEFMessage>
    private let seal: Resolver<NFCNDEFMessage>
    private let requiredMessage: NFCNDEFMessage
    private let optionalMessage: NFCNDEFMessage

    enum NFCWriterError: LocalizedError {
        case invalidFormat
        case notWritable
        case insufficientCapacity(required: Int, available: Int)

        var errorDescription: String? {
            switch self {
            case .notWritable:
                return L10n.Nfc.Write.Error.notWritable
            case let .insufficientCapacity(required: required, available: available):
                return L10n.Nfc.Write.Error.capacity(required, available)
            case .invalidFormat:
                return L10n.Nfc.Write.Error.invalidFormat
            }
        }
    }

    init(requiredPayload: [NFCNDEFPayload], optionalPayload: [NFCNDEFPayload]) {
        self.requiredMessage = NFCNDEFMessage(records: requiredPayload)
        self.optionalMessage = NFCNDEFMessage(records: requiredPayload + optionalPayload)
        (self.promise, self.seal) = Promise<NFCNDEFMessage>.pending()

        super.init()
        self.readerSession = NFCNDEFReaderSession(
            delegate: self,
            queue: nil,
            invalidateAfterFirstRead: false
        )
        readerSession.alertMessage = L10n.Nfc.Write.startMessage(Current.device.inspecificModel())
        readerSession.begin()
    }

    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {}

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        seal.reject(error)
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // Do not add code in this function. This method isn't called
        // when you provide `reader(_:didDetect:)`.
    }

    private static func message(
        for capacity: Int,
        required: NFCNDEFMessage,
        optional: NFCNDEFMessage
    ) throws -> NFCNDEFMessage {
        if capacity >= optional.length {
            return optional
        } else if capacity >= required.length {
            return required
        } else {
            throw NFCWriterError.insufficientCapacity(
                required: required.length,
                available: capacity
            )
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let tag = tags.first else {
            return
        }

        session.connect(to: tag) { [seal, requiredMessage, optionalMessage] error in
            if error != nil {
                session.restartPolling()
                return
            }

            tag.queryNDEFStatus { status, capacity, error in
                if let error = error {
                    session.invalidate(errorMessage: error.localizedDescription)
                    seal.reject(error)
                    return
                }

                switch status {
                case .readWrite:
                    let message: NFCNDEFMessage

                    do {
                        message = try Self.message(for: capacity, required: requiredMessage, optional: optionalMessage)
                    } catch {
                        session.invalidate(errorMessage: error.localizedDescription)
                        seal.reject(error)
                        return
                    }

                    tag.writeNDEF(message) { error in
                        if let error = error {
                            session.invalidate(errorMessage: error.localizedDescription)
                            seal.reject(error)
                        } else {
                            session.alertMessage = L10n.Nfc.Write.successMessage
                            session.invalidate()
                            seal.fulfill(message)
                        }
                    }
                case .readOnly:
                    let error = NFCWriterError.notWritable
                    session.invalidate(errorMessage: error.localizedDescription)
                    seal.reject(error)
                // swiftlint:disable:next fallthrough
                case .notSupported: fallthrough
                @unknown default:
                    let error = NFCWriterError.invalidFormat
                    session.invalidate(errorMessage: error.localizedDescription)
                    seal.reject(error)
                }
            }
        }
    }
}
