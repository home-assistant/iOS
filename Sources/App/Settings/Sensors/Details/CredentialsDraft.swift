import Combine
import Shared

/// Shared, unsaved edit buffer for a `.credentials` setting. The individual field rows
/// and the Save row bind to the same instance so nothing is persisted until Save is
/// tapped, and the button can react to whether there are pending changes.
final class CredentialsDraft: ObservableObject {
    let fields: [WebhookSensorSetting.CredentialField]
    @Published var values: [String]

    init(fields: [WebhookSensorSetting.CredentialField]) {
        self.fields = fields
        self.values = fields.map { $0.getter() }
    }

    var hasChanges: Bool {
        guard values.count == fields.count else { return false }
        return zip(values, fields).contains { $0 != $1.getter() }
    }

    func save() {
        for (index, field) in fields.enumerated() where values.indices.contains(index) {
            field.setter(values[index])
        }
        objectWillChange.send()
    }
}
