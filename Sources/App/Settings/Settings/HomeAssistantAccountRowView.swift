//
//  HomeAssistantAccountRowView.swift
//  App
//
//  Created by Bruno Pantaleão on 12/11/25.
//  Copyright © 2025 Home Assistant. All rights reserved.
//

import SwiftUI
import Shared

struct HomeAssistantAccountRowView: View {
    let server: Server

    var body: some View {
        HStack {
            // Account icon
            Circle()
                .fill(Color.blue)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(server.info.name.prefix(1).uppercased())
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading) {
                Text(server.info.name)
                    .font(.headline)
                if let url = server.info.connection.activeURL() {
                    Text(url.host ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
