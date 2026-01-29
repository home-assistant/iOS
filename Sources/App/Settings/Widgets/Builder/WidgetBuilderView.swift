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
                Text(verbatim: L10n.SettingsDetails.Widgets.ReloadAll.description)
            }

            if #available(iOS 17, *) {
                Button {
                    showDeleteConfirmation = true

                } label: {
                    Text(verbatim: L10n.Settings.Widgets.Custom.DeleteAll.title)
                }
                .tint(.red)
                .confirmationDialog(
                    L10n.Alert.Confirmation.Generic.title,
                    isPresented: $showDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button(role: .cancel, action: { /* no-op */ }) {
                        Text(verbatim: L10n.cancelLabel)
                    }

                    Button(role: .destructive, action: {
                        viewModel.deleteAllWidgets()
                    }) {
                        Text(verbatim: L10n.yesLabel)
                    }
                }
            }
            Section {
                WidgetDocumentationLink()
            }
        }
        .onAppear {
            viewModel.loadWidgets()
        }
    }

    private var header: some View {
        AppleLikeListTopRowHeader(
            image: nil,
            headerImageAlternativeView: AnyView(
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: MaterialDesignIcons.widgetsIcon.image(
                        ofSize: .init(width: 80, height: 80),
                        color: .haPrimary
                    ))
                    Text("BETA")
                        .font(.caption)
                        .padding(.horizontal, DesignSystem.Spaces.one)
                        .padding(.vertical, DesignSystem.Spaces.half)
                        .background(.regularMaterial)
                        .clipShape(Capsule())
                        .offset(x: DesignSystem.Spaces.oneAndHalf, y: 0)
                }
            ),
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
            HStack {
                NavigationLink {
                    WidgetCreationView(needsNavigationController: false, widget: widget) {
                        viewModel.loadWidgets()
                    }
                } label: {
                    Text(widget.name)
                }
                Spacer()
                #if targetEnvironment(macCatalyst)
                Button {
                    viewModel.deleteWidget(widget)
                } label: {
                    Image(systemSymbol: .trash)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                #endif
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
