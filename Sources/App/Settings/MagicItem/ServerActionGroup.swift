import Shared

/// One server's actions, as `ServerActionPicker` lists them.
struct ServerActionGroup: Identifiable {
    /// The server's id — also what a chosen action is stored against, so the picker can tell two
    /// servers offering the same `domain.service` apart.
    let id: String
    let name: String
    let actions: [IntentActionDefinition]
}
