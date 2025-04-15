import AppIntents
import AVFoundation
import AVFAudio
import WidgetKit
import Foundation
import Shared
import SwiftUI
import ActivityKit

@available(iOS 18, *)
struct NewAssistAppIntent: AudioRecordingIntent, LiveActivityIntent {
    static var title: LocalizedStringResource = "New Assist"

    @Parameter(title: .init("app_intents.assist.pipeline.title", defaultValue: "Pipeline"))
    var pipeline: AssistPipelineEntity


    func perform() async throws -> some IntentResult {
        let attributes = AssistActivityAttributes()
        let contentState = AssistActivityAttributes.ContentState(state: .recording)

        let content = ActivityContent(
            state: contentState,
            staleDate: nil,
            relevanceScore: 0
        )
        do {
            let _  = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: .none
            )
        } catch {
            fatalError("Failed to start activity \(error.localizedDescription)")
        }
        await Task.sleep(5 * 1_000_000_000)
        return .result()
    }
}

import Foundation
import WidgetKit
import SwiftUI
import ActivityKit
import Shared
import SFSafeSymbols

@available(iOS 18, *)
struct AssistActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var state: AssistState
    }

    enum AssistState: Codable {
        case idle
        case recording
        case done
    }
}

@available(iOS 18, *)
struct ProgressLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AssistActivityAttributes.self) { context in
            HStack(spacing: Spaces.two) {
                Image(imageAsset: Asset.SharedAssets.logo)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40, alignment: .leading)
                    .padding()

                progressView(state: context.state.state)

            }
            .activityBackgroundTint(Color.white)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(imageAsset: Asset.SharedAssets.logo)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    progressView(state: context.state.state)
                }
            } compactLeading: {
                Image(imageAsset: Asset.SharedAssets.logo)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
            } compactTrailing: {
                EmptyView()
            } minimal: {
                EmptyView()
            }
            .keylineTint(Color.red)
        }
    }

    private func progressView(state: AssistActivityAttributes.AssistState) -> some View {
        Group {
            switch state {
            case .idle:
                Text("Idle")
            case .recording:
                Text("Recording")
            case .done:
                Text("Done")
            }
        }
        .font(.body.bold())
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
