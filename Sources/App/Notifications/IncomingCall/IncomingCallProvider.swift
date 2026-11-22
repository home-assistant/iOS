import CallKit
import Foundation

/// The part of `CXProvider` that `IncomingCallController` uses, so tests can stand in for CallKit.
protocol IncomingCallProvider: AnyObject {
    func setDelegate(_ delegate: CXProviderDelegate?, queue: DispatchQueue?)
    func reportNewIncomingCall(with uuid: UUID, update: CXCallUpdate, completion: @escaping (Error?) -> Void)
    func reportCall(with uuid: UUID, endedAt dateEnded: Date?, reason endedReason: CXCallEndedReason)
}

extension CXProvider: IncomingCallProvider {}
