//
//  WidgetAssistView.swift
//  App
//
//  Created by Bruno Pantaleão on 27/03/2024.
//  Copyright © 2024 Home Assistant. All rights reserved.
//

import SwiftUI
import Shared

struct WidgetAssistView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    let entry: WidgetAssistEntry

    var body: some View {
        content
    }

    @ViewBuilder
    private var content: some View {
        switch widgetFamily {
        case .accessoryCircular:
            VStack {
                Image(uiImage: MaterialDesignIcons.microphoneMessageIcon.image(ofSize: .init(width: 40, height: 40), color: nil))
                    .foregroundStyle(.ultraThickMaterial)
                    .padding(Spaces.one)
            }
            .background(Color(uiColor: .systemBackground))
            .clipShape(Circle())
        default:
            VStack {
                Image(uiImage: MaterialDesignIcons.microphoneMessageIcon.image(ofSize: .init(width: 40, height: 40), color: nil))
                    .foregroundStyle(.ultraThickMaterial)
                    .padding(Spaces.one)
            }
            .background(Color(uiColor: .systemBackground))
            .clipShape(Circle())
        }
    }
}
