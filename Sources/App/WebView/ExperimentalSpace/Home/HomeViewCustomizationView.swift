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
                    Toggle(
                        L10n.HomeView.Customization.CommonControls.title,
                        isOn: Binding(
                            get: { viewModel.configuration.showUsagePredictionSection },
                            set: { newValue in
                                viewModel.configuration.showUsagePredictionSection = newValue
                            }
                        )
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    CloseButton {
                        dismiss()
                    }
                }
            }
        }
    }
}
