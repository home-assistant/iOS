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
                } header: {
                    Text("Background")
                } footer: {
                    Text("Choose a background style for your home view")
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
        ForEach(HomeViewBackgroundOption.allOptions) { option in
            Button {
                viewModel.configuration.selectedBackgroundId = option.id
            } label: {
                HStack {
                    Text(option.name)
                        .foregroundStyle(.primary)
                    Spacer()
                    if viewModel.configuration.selectedBackgroundId == option.id {
                        Image(systemSymbol: .checkmark)
                            .foregroundStyle(.haPrimary)
                    }
                }
            }
        }
    }
}
