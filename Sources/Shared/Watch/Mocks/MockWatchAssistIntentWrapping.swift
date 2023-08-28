import Foundation
import Shared

final class MockWatchAssistIntentWrapping: WatchAssistIntentWrapping {
    var handleCompletionData: (String, AssistIntentResponse)!

    func handle(audioData: Data, completion: @escaping (String, AssistIntentResponse) -> Void) {
        completion(handleCompletionData.0, handleCompletionData.1)
    }
}
