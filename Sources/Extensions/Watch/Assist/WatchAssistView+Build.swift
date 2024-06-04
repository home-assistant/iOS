//
//  WatchAssistView+Build.swift
//  WatchExtension-Watch
//
//  Created by Bruno Pantaleão on 04/06/2024.
//  Copyright © 2024 Home Assistant. All rights reserved.
//

import Foundation

extension WatchAssistView {
    static func build() -> WatchAssistView {
        let viewModel = WatchAssistViewModel(audioRecorder: WatchAudioRecorder())
        return WatchAssistView(viewModel: viewModel)
    }
}
