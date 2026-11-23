import Foundation

/// Home Assistant asked to stop a call: `clear_notification` with the call's tag, from one server.
///
/// The server and the time keep the request from ending the wrong call: a call from another server with the
/// same tag, or a newer call that reused the tag after this request was made.
public struct IncomingCallEndRequest: Equatable {
    public var tag: String
    /// The server that asked. `nil` only for requests queued before servers were recorded, which match any.
    public var webhookID: String?
    public var date: Date

    public init(tag: String, webhookID: String?, date: Date) {
        self.tag = tag
        self.webhookID = webhookID
        self.date = date
    }

    /// Whether this request stops a call with this tag and server that started ringing at `startDate`.
    public func ends(tag: String, webhookID: String?, startedAt startDate: Date) -> Bool {
        guard tag == self.tag, date >= startDate else { return false }
        guard let requester = self.webhookID else { return true }
        return requester == webhookID
    }

    var dictionary: [String: Any] {
        var dictionary: [String: Any] = ["tag": tag, "date": date]
        if let webhookID {
            dictionary["webhook_id"] = webhookID
        }
        return dictionary
    }

    init?(dictionary: [String: Any]) {
        guard let tag = dictionary["tag"] as? String, IncomingCallRequest.isValidTag(tag),
              let date = dictionary["date"] as? Date else {
            return nil
        }
        self.init(tag: tag, webhookID: dictionary["webhook_id"] as? String, date: date)
    }
}
