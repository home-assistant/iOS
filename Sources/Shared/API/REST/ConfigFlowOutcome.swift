import Foundation

/// The result of starting or advancing a Home Assistant config flow over the REST API.
///
/// Home Assistant answers every config flow request with the same envelope, discriminated by
/// `type`; this models the three outcomes a single-step flow can produce.
public enum ConfigFlowOutcome: Equatable {
    /// The flow finished and created a config entry with this title.
    case created(title: String)
    /// The flow is waiting on user input. `errors` is empty on the first form and carries the
    /// per-field failure codes (e.g. `cannot_connect`) when a submission was rejected.
    case form(flowID: String, errors: [String: String])
    /// The flow ended without creating anything, e.g. `already_configured`.
    case aborted(reason: String)

    public init(json: Any) throws {
        guard let body = json as? [String: Any], let type = body["type"] as? String else {
            throw HomeAssistantConfigFlowError.unexpectedResponse
        }

        switch type {
        case "create_entry":
            self = .created(title: body["title"] as? String ?? "")
        case "form":
            guard let flowID = body["flow_id"] as? String else {
                throw HomeAssistantConfigFlowError.unexpectedResponse
            }
            self = .form(flowID: flowID, errors: body["errors"] as? [String: String] ?? [:])
        case "abort":
            self = .aborted(reason: body["reason"] as? String ?? "unknown")
        default:
            throw HomeAssistantConfigFlowError.unexpectedResponse
        }
    }
}
