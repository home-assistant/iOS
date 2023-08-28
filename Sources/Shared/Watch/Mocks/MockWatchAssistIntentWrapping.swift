//
//  MockWatchAssistIntentWrapping.swift
//  App
//
//  Created by Bruno Pantaleão on 28/08/2023.
//  Copyright © 2023 Home Assistant. All rights reserved.
//

import Foundation
import Shared

final class MockWatchAssistIntentWrapping: WatchAssistIntentWrapping {

    var handleCompletionData: (String, AssistIntentResponse)!

    func handle(audioData: Data, completion: @escaping (String, AssistIntentResponse) -> Void) {
        completion(handleCompletionData.0, handleCompletionData.1)
    }
}
