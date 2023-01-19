import Intents

public protocol ServerIdentifierProviding {
    var serverIdentifier: String { get }
}

extension Action: ServerIdentifierProviding {}

public protocol ServerIntentProviding {
    var server: IntentServer? { get }
}

extension CallServiceIntent: ServerIntentProviding {}
extension FireEventIntent: ServerIntentProviding {}
extension GetCameraImageIntent: ServerIntentProviding {}
extension RenderTemplateIntent: ServerIntentProviding {}
extension AssistIntent: ServerIntentProviding {}

@available(iOS 13, watchOS 6, *)
extension IntentPanel: ServerIntentProviding {
    // this custom type as a property does not persist correctly in a configured widget
    // FB9779882
    public var server: IntentServer? {
        get { serverIdentifier.flatMap { .init(identifier: $0, display: $0) } }
        set { serverIdentifier = newValue?.identifier }
    }
}
