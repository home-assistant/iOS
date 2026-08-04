import Foundation

/// What the watch's full-screen Assist cover should show. Presented from the home screen's toolbar
/// button, the Assist complication, and Assist/Assist prompt items in the configuration.
enum WatchAssistPresentation: Identifiable {
    /// A pipeline session. An empty `pipelineId` means the server's preferred pipeline, and `prompt`
    /// — set by an Assist prompt item — is sent as text instead of recording.
    case session(serverId: String, pipelineId: String, prompt: String?)
    /// Assist was requested before its configuration reached the watch (e.g. a cold launch from the
    /// complication), so there is no pipeline to run yet.
    case unconfigured

    /// The prompt is reduced to a fingerprint rather than embedded: the id only has to tell two
    /// sessions apart, and it must not carry what the user wrote into logs or diagnostics.
    var id: String {
        switch self {
        case let .session(serverId, pipelineId, prompt):
            return "\(serverId)|\(pipelineId)|\(prompt.map { String($0.hashValue) } ?? "")"
        case .unconfigured:
            return "__unconfigured__"
        }
    }
}
