import Combine
import Shared
import SwiftUI

struct OnboardingServersListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass

    @EnvironmentObject var hostingProvider: ViewControllerProvider
    @StateObject private var viewModel = OnboardingServersListViewModel()

    @State private var showDocumentation = false
    @State private var showManualInput = false
    @State private var screenLoaded = false

    @Binding var shouldDismissOnboarding: Bool

    var body: some View {
        List {
            headerView
            list
        }
        .animation(.easeInOut, value: viewModel.discoveredInstances.count)
        .safeAreaInset(edge: .bottom) {
            bottomButtons
        }
        .navigationTitle(L10n.Onboarding.Scanning.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(content: {
            ToolbarItem(placement: .topBarTrailing) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .opacity(viewModel.isLoading ? 1 : 0)
                    .animation(.easeInOut, value: viewModel.isLoading)
            }
        })
        .onAppear {
            onAppear()
        }
        .onDisappear {
            onDisappear()
        }
        .sheet(isPresented: $viewModel.showError) {
            errorView
        }
        .fullScreenCover(isPresented: .init(get: {
            viewModel.showPermissionsFlow && viewModel.onboardingServer != nil
        }, set: { newValue in
            viewModel.showPermissionsFlow = newValue
        })) {
            OnboardingPermissionsNavigationView(onboardingServer: viewModel.onboardingServer)
        }
    }

    private func onAppear() {
        if !screenLoaded {
            screenLoaded = true
            viewModel.startDiscovery()
        }
    }

    private func onDisappear() {
        viewModel.stopDiscovery()
        viewModel.currentlyInstanceLoading = nil
    }

    @ViewBuilder
    private var errorView: some View {
        if let error = viewModel.error {
            ConnectionErrorDetailsView(
                server: nil,
                error: error,
                showSettingsEntry: false,
                expandMoreDetails: true
            )
            .onDisappear {
                viewModel.resetFlow()
            }
        } else {
            Text("Unmapped onboarding flow (1)")
        }
    }

    private var list: some View {
        ForEach(viewModel.discoveredInstances, id: \.uuid) { instance in
            if #available(iOS 17, *) {
                Section {
                    serverRow(instance: instance)
                }
                .frame(minHeight: Current.isCatalyst ? 60 : nil)
                .listSectionSpacing(.compact)
            } else {
                serverRow(instance: instance)
            }
        }
        .disabled(viewModel.currentlyInstanceLoading != nil)
    }

    private var headerView: some View {
        Section {
            ServersScanAnimationView()
                .listRowBackground(Color.clear)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func serverRow(instance: DiscoveredHomeAssistant) -> some View {
        Button(action: {
            viewModel.selectInstance(instance, controller: hostingProvider.viewController)
        }, label: {
            OnboardingScanningInstanceRow(
                name: instance.locationName,
                internalURLString: instance.internalURL?.absoluteString,
                externalURLString: instance.externalURL?.absoluteString,
                internalOrExternalURLString: instance.internalOrExternalURL.absoluteString,
                isLoading: instance == viewModel.currentlyInstanceLoading
            )
        })
        .tint(Color(uiColor: .label))
    }

    private var bottomButtons: some View {
        VStack {
            VStack {
                Button(action: {
                    showManualInput = true
                }) {
                    Text(L10n.Onboarding.Scanning.Manual.Button.title)
                }
                .buttonStyle(.primaryButton)
                .sheet(isPresented: $showManualInput) {
                    ManualURLEntryView { connectURL in
                        viewModel.isLoading = true
                        viewModel.selectInstance(
                            .init(manualURL: connectURL),
                            controller: hostingProvider.viewController
                        )
                    }
                }
                Button(action: {
                    showDocumentation = true
                }) {
                    Text(L10n.Onboarding.Servers.Docs.read)
                }
                .buttonStyle(.secondaryButton)
                .fullScreenCover(isPresented: $showDocumentation) {
                    SafariWebView(url: AppConstants.WebURLs.homeAssistantGetStarted)
                }
            }
            .frame(maxWidth: Sizes.maxWidthForLargerScreens)
        }
        .frame(maxWidth: .infinity)
        .padding([.horizontal, .top])
        .background(.ultraThinMaterial)
    }
}
