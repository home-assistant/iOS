import Foundation
import CoreNFC
import PromiseKit
import Shared

@available(iOS 13, *)
class NFCWriter: NSObject, NFCNDEFReaderSessionDelegate {
    private var readerSession: NFCNDEFReaderSession!
    public let promise: Promise<Void>
    private let seal: Resolver<Void>
    private let message: NFCNDEFMessage

    enum NFCWriterError: LocalizedError {
        case invalidFormat
        case notWritable
        case insufficientCapacity(required: Int, available: Int)

        var errorDescription: String? {
            switch self {
            case .notWritable:
                return L10n.Nfc.Write.Error.notWritable
            case .insufficientCapacity(required: let required, available: let available):
                return L10n.Nfc.Write.Error.capacity(required, available)
            case .invalidFormat:
                return L10n.Nfc.Write.Error.invalidFormat
            }
        }
    }

    init(message: NFCNDEFMessage) {
        self.message = message
        (self.promise, self.seal) = Promise<Void>.pending()

        super.init()
        readerSession = NFCNDEFReaderSession(
            delegate: self,
            queue: nil,
            invalidateAfterFirstRead: false
        )
        readerSession.alertMessage = L10n.Nfc.Write.startMessage(Current.device.inspecificModel())
        readerSession.begin()
    }

    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        seal.reject(error)
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // Do not add code in this function. This method isn't called
        // when you provide `reader(_:didDetect:)`.
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let tag = tags.first else {
            return
        }

        session.connect(to: tag) { [seal, message] error in
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
                    if message.length > capacity {
                        let error = NFCWriterError.insufficientCapacity(required: message.length, available: capacity)
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
                            seal.fulfill(())
                        }
                    }
                case .readOnly:
                    let error = NFCWriterError.notWritable
                    session.invalidate(errorMessage: error.localizedDescription)
                    seal.reject(error)
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
