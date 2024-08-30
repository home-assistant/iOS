//
//  ControlAssistAppIntent.swift
//  Extensions-Widgets
//
//  Created by Bruno Pantaleão on 30/8/24.
//  Copyright © 2024 Home Assistant. All rights reserved.
//

import Foundation
import AppIntents

// OpenIntent needs to have it's target the widget extension AND app target!
@available(iOS 18, *)
struct AssistAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Assist"

    @Parameter(title: "Pipeline")
    var target: AssistPipelineEntity

    func perform() async throws -> some IntentResult {
        // For some reason Apple is only allowing universal links to be opened through AppIntent https://mastodon.social/@mgorbach/113001549483710681
        try await OpenURLIntent(URL(string: "https://home-assistant.io/")!).perform()
    }
}
