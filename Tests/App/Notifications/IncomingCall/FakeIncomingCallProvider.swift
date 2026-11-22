import CallKit
import Foundation
@testable import HomeAssistant

/// Stands in for `CXProvider`: records what `IncomingCallController` reports, and answers reports with
/// `reportError`.
final class FakeIncomingCallProvider: IncomingCallProvider {
    struct Report {
        let uuid: UUID
        let update: CXCallUpdate
    }

    struct End: Equatable {
        let uuid: UUID
        let reason: CXCallEndedReason
    }

    var reportError: Error?
    private(set) var reports = [Report]()
    private(set) var ends = [End]()

    func setDelegate(_ delegate: CXProviderDelegate?, queue: DispatchQueue?) {}

    func reportNewIncomingCall(with uuid: UUID, update: CXCallUpdate, completion: @escaping (Error?) -> Void) {
        reports.append(Report(uuid: uuid, update: update))
        completion(reportError)
    }

    func reportCall(with uuid: UUID, endedAt dateEnded: Date?, reason endedReason: CXCallEndedReason) {
        ends.append(End(uuid: uuid, reason: endedReason))
    }
}
