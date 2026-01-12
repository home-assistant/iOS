import HAKit
import SFSafeSymbols
import Shared
import SwiftUI

@available(iOS 26.0, *)
struct HomeViewCustomizationView: View {
    @ObservedObject var viewModel: HomeViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    backgroundPicker
                }
            }
            .navigationTitle("Customize")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    CloseButton {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var backgroundPicker: some View {
        Picker("Background", selection: backgroundThemeBinding) {
            Text("Default")
                .tag(nil as AppBackgroundTheme?)
            ForEach(AppBackgroundTheme.allCases) { theme in
                Text(theme.rawValue)
                    .tag(theme as AppBackgroundTheme?)
            }
        }
        .pickerStyle(.menu)
    }

    private var backgroundThemeBinding: Binding<AppBackgroundTheme?> {
        Binding(
            get: { viewModel.configuration.selectedBackgroundTheme },
            set: { newValue in
                viewModel.setBackgroundTheme(newValue)
            }
        )
    }
}
