import Intents

public protocol SingleServerIntent {
    var server: IntentServer? { get }
}

extension CallServiceIntent: SingleServerIntent {}
extension FireEventIntent: SingleServerIntent {}
extension GetCameraImageIntent: SingleServerIntent {}
extension RenderTemplateIntent: SingleServerIntent {}
@available(iOS 13, watchOS 6, *)
extension IntentPanel: SingleServerIntent {}

