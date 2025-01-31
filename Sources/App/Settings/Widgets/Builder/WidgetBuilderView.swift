import Shared
import SwiftUI

struct WidgetBuilderView: View {
    @StateObject private var viewModel = WidgetBuilderViewModel()
    @State private var showDeleteConfirmation = false
    var body: some View {
        List {
            if #available(iOS 17, *) {
                header
                yourWidgetsSection
            }
            Section {
                reloadWidgetsView
            } footer: {
                Text(L10n.SettingsDetails.Widgets.ReloadAll.description)
            }

            if #available(iOS 17, *) {
                Button {
                    showDeleteConfirmation = true

                } label: {
                    Text(L10n.Settings.Widgets.Custom.DeleteAll.title)
                }
                .tint(.red)
                .confirmationDialog(
                    L10n.Alert.Confirmation.Generic.title,
                    isPresented: $showDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button(role: .cancel, action: { /* no-op */ }) {
                        Text(L10n.cancelLabel)
                    }

                    Button(role: .destructive, action: {
                        viewModel.deleteAllWidgets()
                    }) {
                        Text(L10n.yesLabel)
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadWidgets()
        }
    }

    private var header: some View {
        AppleLikeListTopRowHeader(
            image: Image(uiImage: MaterialDesignIcons.widgetsIcon.image(
                ofSize: .init(width: 80, height: 80),
                color: Asset.Colors.haPrimary.color
            )),
            title: L10n.Widgets.Custom.title,
            subtitle: L10n.Widgets.Custom.subtitle
        )
    }

    private var yourWidgetsSection: some View {
        Section(L10n.Settings.Widgets.YourWidgets.title) {
            widgetsList
            NavigationLink(destination: {
                WidgetCreationView {
                    viewModel.loadWidgets()
                }
            }) {
                Label(L10n.Settings.Widgets.Create.title, systemSymbol: .plus)
            }
        }
    }

    private var widgetsList: some View {
        ForEach(viewModel.widgets, id: \.id) { widget in
            NavigationLink {
                WidgetCreationView(widget: widget) {
                    viewModel.loadWidgets()
                }
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
