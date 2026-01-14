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
                commonControlsSection
                areasLayoutSection
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

    private var commonControlsSection: some View {
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
    private var areasLayoutSection: some View {
        Section {
            Picker(
                L10n.HomeView.Customization.AreasLayout.title,
                selection: Binding(
                    get: { viewModel.configuration.areasLayout ?? .list },
                    set: { newValue in
                        viewModel.configuration.areasLayout = newValue
                    }
                )
            ) {
                ForEach(HomeViewConfiguration.AreasLayout.allCases, id: \.self) { layout  in
                    Label(layout.localizableName, systemSymbol: layout.icon).tag(layout)
                }
            }
        }
    }
}

