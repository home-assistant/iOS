import Foundation
import Shared

protocol AssistSessionDelegate: AnyObject {
    func didRequestNewSession(_ context: AssistSessionContext)
}

struct AssistSessionContext {
    let server: Server
    let pipelineId: String
    let autoStartRecording: Bool
    /// Places the keyboard in the text input as soon as Assist appears.
    let focusInputOnAppear: Bool
}

final class AssistSession: ObservableObject {
    static var shared = AssistSession()
    weak var delegate: AssistSessionDelegate?

    @Published var inProgress = false

    func requestNewSession(_ context: AssistSessionContext) {
        delegate?.didRequestNewSession(context)
    }
}
