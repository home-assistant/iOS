import Shared
import SwiftUI

struct DeeplinkView: View {
    @StateObject private var viewModel: DeeplinkViewModel
    @State private var isDeeplinkExpanded = false
    private let onClose: (() -> Void)?

    init(viewModel: DeeplinkViewModel, onClose: (() -> Void)? = nil) {
        self._viewModel = .init(wrappedValue: viewModel)
        self.onClose = onClose
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    AppleLikeListTopRowHeader(
                        image: .linkVariantIcon,
                        title: L10n.Deeplink.title,
                        subtitle: L10n.Deeplink.description
                    )
                    .listRowBackground(Color.clear)
                }

                Section {
                    HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spaces.one) {
                        Text(viewModel.deeplink)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                            .lineLimit(isDeeplinkExpanded ? nil : 1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            withAnimation { isDeeplinkExpanded.toggle() }
                        } label: {
                            Image(systemSymbol: isDeeplinkExpanded ? .chevronUp : .chevronDown)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(
                            isDeeplinkExpanded
                                ? L10n.Component.CollapsibleView.collapse
                                : L10n.Component.CollapsibleView.expand
                        )
                    }
                    if viewModel.didCopy {
                        Label {
                            Text(L10n.Deeplink.copied)
                        } icon: {
                            Image(systemSymbol: .checkmarkCircleFill)
                        }
                        .font(.subheadline)
                        .foregroundStyle(Color.green)
                        .transition(.opacity)
                    }
                }

                if viewModel.hasMultipleServers {
                    Section(footer: Text(L10n.Deeplink.IncludeServer.subtitle(viewModel.serverName))) {
                        Toggle(L10n.Deeplink.IncludeServer.title, isOn: $viewModel.includeServer.animation())
                            .onChange(of: viewModel.includeServer) { _ in
                                viewModel.includeServerChanged()
                            }
                    }
                    .modify { view in
                        if #available(iOS 17.0, *) {
                            view.listSectionSpacing(DesignSystem.Spaces.two)
                        } else {
                            view
                        }
                    }
                }
            }
            .modify { view in
                if #available(iOS 17.0, *) {
                    view
                        .listSectionSpacing(.zero)
                        .contentMargins(.top, 0)
                } else {
                    view
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    viewModel.copyToClipboard()
                } label: {
                    Text(L10n.Deeplink.copyToClipboard)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primaryButton)
                .padding(.horizontal, DesignSystem.Spaces.two)
                .padding(.bottom, DesignSystem.Spaces.two)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    CloseButton(alternativeAction: onClose)
                }
            }
            .onAppear {
                viewModel.copyToClipboard()
            }
        }
        .navigationViewStyle(.stack)
    }
}

@available(iOS 17.0, *)
#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            DeeplinkView(viewModel: DeeplinkViewModel(entityId: "light.mesa_de_jantar", serverName: "Home"))
                .presentationDetents([.medium, .large])
        }
}
