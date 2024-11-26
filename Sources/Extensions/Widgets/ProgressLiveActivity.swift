//
//  MatchLiveScoreLiveActivity.swift
//  Extensions-Widgets
//
//  Created by Bruno Pantaleão on 26/11/24.
//  Copyright © 2024 Home Assistant. All rights reserved.
//

import Foundation
import WidgetKit
import SwiftUI
import ActivityKit
import Shared
import SFSafeSymbols

@available(iOS 18, *)
struct ProgressActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// 0...1
        var percentageCompleted: Int
        var success: Bool?
    }

    var timerId: String
    var date: String
}

@available(iOS 18, *)
struct ProgressLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ProgressActivityAttributes.self) { context in
            HStack(spacing: Spaces.two) {
                Image(imageAsset: Asset.SharedAssets.logo)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40, alignment: .leading)
                    .padding()
                if let success = context.state.success {
                    Text(success ? "Executed" : "Failed")
                        .font(.body.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemSymbol: success ? .checkmarkCircle : .xmarkCircle)
                        .font(.title)
                        .tint(success ? Color.asset(Asset.Colors.haPrimary) : .red)
                } else {
                    Text("In progress...")
                        .font(.body.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
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
                    VStack {
                        if let success = context.state.success {
                            Text(success ? "Executed" : "Failed")
                        } else {
                            Text("In progress...")
                        }
                    }
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
//            .widgetURL(URL(string: ""))
            .keylineTint(Color.red)
        }
    }
}
