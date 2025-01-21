import Shared
import SwiftUI

struct WidgetBuilderView: View {
    @StateObject private var viewModel = WidgetBuilderViewModel()

    var body: some View {
        List {
            AppleLikeListTopRowHeader(
                image: Image(uiImage: MaterialDesignIcons.widgetsIcon.image(
                    ofSize: .init(width: 80, height: 80),
                    color: Asset.Colors.haPrimary.color
                )),
                title: L10n.Widgets.Custom.title,
                subtitle: L10n.Widgets.Custom.subtitle
            )
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
                Label(L10n.SettingsDetails.Widgets.ReloadAll.title, systemSymbol: .squareTextSquareFill)
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
