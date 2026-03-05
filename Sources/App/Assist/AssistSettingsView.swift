import Foundation
import Shared
import SwiftUI

// MARK: - Settings View

struct AssistSettingsView: View {
    @StateObject private var viewModel = AssistSettingsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle(L10n.Assist.Settings.TtsMute.toggle, isOn: $viewModel.configuration.muteTTS)
                } footer: {
                    Text(L10n.Assist.Settings.TtsMute.footer)
                }
            }
            .navigationTitle(L10n.Assist.Settings.title)
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
