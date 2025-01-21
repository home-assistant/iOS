import Shared
import SwiftUI

struct WidgetBuilderView: View {
    @StateObject private var viewModel = WidgetBuilderViewModel()

    var body: some View {
        List {
            Section(L10n.Settings.Widgets.YourWidgets.title) {
                widgetsList
                NavigationLink(destination: {
                    WidgetCreationView()
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
        .onAppear {
            viewModel.loadWidgets()
        }
        .navigationTitle(L10n.Settings.Widgets.title)
    }

    private var widgetsList: some View {
        ForEach(viewModel.widgets, id: \.id) { widget in
            NavigationLink {
                WidgetCreationView(widget: widget)
            } label: {
                Text(widget.name)
            }
        }
        .onDelete { indexSet in
            viewModel.deleteItem(at: indexSet)
        }
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
