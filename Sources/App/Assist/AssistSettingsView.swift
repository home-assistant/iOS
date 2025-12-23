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
    @AppStorage("assistModernUITheme") private var selectedThemeRawValue = ModernAssistTheme.homeAssistant.rawValue
    
    private var selectedTheme: Binding<ModernAssistTheme> {
        Binding(
            get: { ModernAssistTheme(rawValue: selectedThemeRawValue) ?? .homeAssistant },
            set: { selectedThemeRawValue = $0.rawValue }
        )
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("Enable on-device Speech-to-Text", isOn: $enableOnDeviceSTT)
                } footer: {
                    Text("Use Apple's on-device speech recognition for improved privacy. Your voice will be processed locally and transcribed to text before being sent to your server. Not all languages are supported.")
                }

                Section {
                    Toggle("Experimental UI", isOn: $enableModernUI)

                    if enableModernUI {
                        Picker("Theme", selection: selectedTheme) {
                            ForEach(ModernAssistTheme.allCases) { theme in
                                Text(theme.rawValue)
                                    .tag(theme)
                            }
                        }
                    }
                } header: {
                    Label("Labs", systemSymbol: .flaskFill)
                } footer: {
                    Text("Enable the new modern interface design for Assist. This is a labs feature and may have limited functionality as well as it can be removed without previous notice.")
                }

            }
            .navigationTitle("Assist Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    CloseButton {
                        dismiss()
                    }
                }
            }
        }
    }
}

