import Shared
import SwiftUI

struct WidgetsSettingsView: View {
    @StateObject private var viewModel: WidgetsSettingsViewModel

    init(viewModel: WidgetsSettingsViewModel) {
        self._viewModel = .init(wrappedValue: viewModel)
    }

    var body: some View {
        content
            .navigationTitle(L10n.Settings.Widgets.title)
            .navigationBarTitleDisplayMode(.inline)
    }

    private var content: some View {
        List {
            Button(action: {
                viewModel.reloadWidgets()
            }, label: {
                HStack {
                    Label(L10n.SettingsDetails.Widgets.ReloadAll.title, systemImage: "square.text.square.fill")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                }
            })
            .listRowSeparator(.hidden)

            // New section to avoid list to not round previous item corners
            Section {
                Text(L10n.SettingsDetails.Widgets.ReloadAll.description)
                    .font(.footnote)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                    .listRowBackground(Color.clear)
            }
        }
        .modify {
            if #available(iOS 17.0, *) {
                $0.listSectionSpacing(.leastNonzeroMagnitude)
            }
        }
    }
}

#Preview {
    NavigationView {
        WidgetsSettingsView(viewModel: .init())
    }
}
