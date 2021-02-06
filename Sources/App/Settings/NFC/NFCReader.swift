import CoreNFC
import Foundation
import PromiseKit
import Shared

@available(iOS 13, *)
class NFCReader: NSObject, NFCTagReaderSessionDelegate {
    private var readerSession: NFCTagReaderSession!
    public let promise: Promise<NFCNDEFMessage>
    private let seal: Resolver<NFCNDEFMessage>

    enum NFCReaderError: LocalizedError {
        case unsupportedTag
        case readFailed

        var errorDescription: String? {
            switch self {
            case .unsupportedTag: return L10n.Nfc.Read.Error.tagInvalid
            case .readFailed: return L10n.Nfc.Read.Error.genericFailure
            }
        }
    }

    override init() {
        (self.promise, self.seal) = Promise<NFCNDEFMessage>.pending()

        super.init()
        self.readerSession = NFCTagReaderSession(
            pollingOption: [.iso14443, .iso15693, .iso18092],
            delegate: self,
            queue: nil
        )
        readerSession.alertMessage = L10n.Nfc.Read.startMessage(Current.device.inspecificModel())
        readerSession.begin()
    }

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        session.invalidate(errorMessage: error.localizedDescription)
        seal.reject(error)
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else {
            return
        }

        let ndefTag: NFCNDEFTag
        switch tag {
        case let .iso7816(tag):
            ndefTag = tag
        case let .feliCa(tag):
            ndefTag = tag
        case let .iso15693(tag):
            ndefTag = tag
        case let .miFare(tag):
            ndefTag = tag
        @unknown default:
            seal.reject(NFCReaderError.unsupportedTag)
            session.invalidate(errorMessage: NFCReaderError.unsupportedTag.localizedDescription)
            return
        }

        session.connect(to: tag) { [seal] error in
            if let error = error {
                session.invalidate(errorMessage: error.localizedDescription)
                seal.reject(error)
                return
            }

            ndefTag.queryNDEFStatus { status, _, error in
                switch status {
                case .notSupported:
                    let displayError = error ?? NFCReaderError.unsupportedTag
                    session.invalidate(errorMessage: displayError.localizedDescription)
                    seal.reject(displayError)
                default:
                    ndefTag.readNDEF { message, error in
                        if let message = message {
                            seal.fulfill(message)
                            session.invalidate()
                        } else {
                            let displayError = error ?? NFCReaderError.readFailed
                            session.invalidate(errorMessage: displayError.localizedDescription)
                            seal.reject(displayError)
                        }
                    }
                }
            }
        }
    }
}
