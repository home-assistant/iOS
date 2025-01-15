import Shared
import SwiftUI

struct WidgetBuilderView: View {
    @StateObject private var viewModel = WidgetBuilderViewModel()
    @State private var showAddWidget = false

    var body: some View {
        List {
            Section(L10n.Settings.Widgets.YourWidgets.title) {
                Button(action: {
                    showAddWidget = true
                }) {
                    Label(L10n.Settings.Widgets.Create.title, systemSymbol: .plus)
                }
            }

            Section {
                reloadWidgetsView
            } footer: {
                Text(L10n.SettingsDetails.Widgets.ReloadAll.description)
            }
        }
        .sheet(isPresented: $showAddWidget, content: {
            WidgetCreationView()
        })
        .navigationTitle(L10n.Settings.Widgets.title)
    }

    @ViewBuilder
    private var reloadWidgetsView: some View {
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
    }
}

#Preview {
    NavigationView {
        WidgetBuilderView()
    }
}
