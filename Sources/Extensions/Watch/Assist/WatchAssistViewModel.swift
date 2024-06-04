//
//  WatchAssistViewModel.swift
//  WatchExtension-Watch
//
//  Created by Bruno Pantaleão on 04/06/2024.
//  Copyright © 2024 Home Assistant. All rights reserved.
//

import Foundation
import Shared

final class WatchAssistViewModel: ObservableObject {
    enum State {
        case idle
        case recording
        case loading
    }

    @Published var chatItems: [AssistChatItem] = []

    @Published var state: State = .idle

    private let audioRecorder: WatchAudioRecorder

    private let audioPlayer = AudioPlayer()

    init(audioRecorder: WatchAudioRecorder) {
        self.audioRecorder = audioRecorder

        audioRecorder.delegate = self
    }

    func assist() {
        chatItems.append(.init(content: "Hello", itemType: .input))
        audioRecorder.startRecording()
    }
}

extension WatchAssistViewModel: WatchAudioRecorderDelegate {
    @MainActor
    func didStartRecording() {
        state = .recording
    }
    
    @MainActor
    func didStopRecording() {
        state = .loading
    }
    
    @MainActor
    func didFinishRecording(audioURL: URL) {
        state = .loading
        chatItems.append(.init(content: "\(audioURL.absoluteString)", itemType: .input))
        audioPlayer.play(url: audioURL)
    }
    
    func didFailRecording(error: any Error) {
        Current.Log.error("Failed to record Assist audio in watch App: \(error.localizedDescription)")
    }
}
