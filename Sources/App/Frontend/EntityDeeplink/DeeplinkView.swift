import Shared
import SwiftUI

struct DeeplinkView: View {
    @StateObject private var viewModel: DeeplinkViewModel
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
                    Text(viewModel.deeplink)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .textSelection(.enabled)
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

                Section(footer: Text(L10n.Deeplink.IncludeServer.subtitle(viewModel.serverName))) {
                    Toggle(L10n.Deeplink.IncludeServer.title, isOn: $viewModel.includeServer.animation())
                        .onChange(of: viewModel.includeServer) { _ in
                            viewModel.includeServerChanged()
                        }
                }

                if viewModel.includeServer {
                    Section {
                        Button {
                            viewModel.copyToClipboard()
                        } label: {
                            Text(L10n.Deeplink.copyToClipboard)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.primaryButton)
                        .listRowBackground(Color.clear)
                    }
                }
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

#Preview {
    DeeplinkView(viewModel: DeeplinkViewModel(entityId: "light.mesa_de_jantar", serverName: "Home"))
}
