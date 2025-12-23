//
//  AssistSettingsView.swift
//  App
//
//  Created by Bruno Pantaleão on 23/12/25.
//  Copyright © 2025 Home Assistant. All rights reserved.
//

import Foundation
import SwiftUI
import Shared

// MARK: - Settings View
@available(iOS 26.0, *)
struct AssistSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("enableAssistOnDeviceSTT") private var enableOnDeviceSTT = false
    @AppStorage("enableAssistModernUI") private var enableModernUI = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("Modern UI (Beta)", isOn: $enableModernUI)
                } footer: {
                    Text("Enable the new modern interface design for Assist. This is a beta feature and may have limited functionality.")
                }
                
                Section {
                    Toggle("Enable on-device Speech-to-Text", isOn: $enableOnDeviceSTT)
                } footer: {
                    Text("Use Apple's on-device speech recognition for improved privacy. Your voice will be processed locally and transcribed to text before being sent to your server.")
                }
            }
            .navigationTitle("Assist Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

