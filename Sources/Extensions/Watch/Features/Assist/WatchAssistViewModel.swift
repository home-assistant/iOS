import Foundation

protocol WatchAssistViewModelProtocol: ObservableObject {
    var chatItems: [AssistChatItem] { get set }
    var preferredPipelineId: String { get set }
    var showScreenLoader: Bool { get set }
    var inputText: String { get set }
    var isRecording: Bool { get set }
}

final class WatchAssistViewModel: WatchAssistViewModelProtocol {
    @Published var chatItems: [AssistChatItem] = []
    @Published var preferredPipelineId: String = ""
    @Published var showScreenLoader = false
    @Published var inputText = ""
    @Published var isRecording = false

    
}
