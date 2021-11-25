import Intents

public protocol SingleServerIntent {
    var server: IntentServer? { get }
}

extension CallServiceIntent: SingleServerIntent {}
extension FireEventIntent: SingleServerIntent {}
extension GetCameraImageIntent: SingleServerIntent {}
extension RenderTemplateIntent: SingleServerIntent {}

@available(iOS 13, watchOS 6, *)
extension IntentPanel: SingleServerIntent {
    // this custom type as a property does not persist correctly in a configured widget
    // FB9779882
    public var server: IntentServer? {
        get { serverIdentifier.flatMap { .init(identifier: $0, display: $0) } }
        set { serverIdentifier = newValue?.identifier }
    }
}
