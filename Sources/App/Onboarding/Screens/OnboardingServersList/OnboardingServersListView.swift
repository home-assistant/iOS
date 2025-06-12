import Combine
import Shared
import SwiftUI

struct OnboardingServersListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass

    @EnvironmentObject var hostingProvider: ViewControllerProvider
    @StateObject private var viewModel: OnboardingServersListViewModel

    @State private var showDocumentation = false
    @State private var showManualInput = false
    @State private var screenLoaded = false
    @State private var showHeaderView = false
    @State private var showManualInputButton = false

    let prefillURL: URL?

    init(prefillURL: URL? = nil, shouldDismissOnSuccess: Bool = false) {
        self.prefillURL = prefillURL
        self
            ._viewModel =
            .init(wrappedValue: OnboardingServersListViewModel(shouldDismissOnSuccess: shouldDismissOnSuccess))
    }

    var body: some View {
        List {
            if let prefillURL {
                prefillURLHeader(url: prefillURL)
            } else {
                if let inviteURL = Current.appSessionValues.inviteURL {
                    prefillURLHeader(url: inviteURL)
                    Text(L10n.Onboarding.Invitation.otherOptions)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                } else {
                    if showHeaderView, viewModel.discoveredInstances.isEmpty {
                        headerView
                    }
                }
                list

                if showManualInputButton {
                    manualInputButton
                }
            }
        }
        .animation(.easeInOut, value: viewModel.discoveredInstances.count)
        .navigationTitle(prefillURL == nil ? L10n.Onboarding.Scanning.title : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(content: {
            ToolbarItem(placement: .topBarTrailing) {
                if prefillURL != nil {
                    CloseButton {
                        dismiss()
                    }
                } else if viewModel.manualInputLoading {
                    // Loading happens when URL is manually inputed by user
                    ProgressView()
                        .progressViewStyle(.circular)
                } else {
                    Button(action: {
                        showDocumentation = true
                    }, label: {
                        Image(uiImage: MaterialDesignIcons.helpCircleOutlineIcon.image(
                            ofSize: .init(width: 25, height: 25),
                            color: .accent
                        ))
                    })
                    .fullScreenCover(isPresented: $showDocumentation) {
                        SafariWebView(url: AppConstants.WebURLs.homeAssistantGetStarted)
                    }
                }
            }
        })
        .onAppear {
            onAppear()
        }
        .onDisappear {
            onDisappear()
        }
        .onChange(of: viewModel.shouldDismiss) { newValue in
            if newValue {
                dismiss()
            }
        }
        .sheet(isPresented: $viewModel.showError) {
            errorView
        }
        .sheet(isPresented: $showManualInput) {
            ManualURLEntryView { connectURL in
                viewModel.manualInputLoading = true
                viewModel.selectInstance(
                    .init(manualURL: connectURL),
                    controller: hostingProvider.viewController
                )
            }
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
            if let prefillURL {
                viewModel.selectInstance(
                    .init(manualURL: prefillURL),
                    controller: hostingProvider.viewController
                )
            } else {
                viewModel.startDiscovery()
            }
        }

        // Only displays magnifying glass animation if no servers are found after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if viewModel.discoveredInstances.isEmpty {
                showHeaderView = true
            }

            showManualInputButton = true
        }
    }

    private func onDisappear() {
        viewModel.stopDiscovery()
        viewModel.currentlyInstanceLoading = nil
    }

    @ViewBuilder
    private func prefillURLHeader(url: URL) -> some View {
        Section {
            AppleLikeListTopRowHeader(
                image: nil,
                headerImageAlternativeView: AnyView(
                    Image(uiImage: Asset.logo.image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                ),
                title: L10n.Onboarding.Invitation.title,
                subtitle: url.absoluteString
            )
            Button {
                viewModel.selectInstance(.init(manualURL: url), controller: hostingProvider.viewController)
                viewModel.invitationLoading = true
            } label: {
                ZStack {
                    HAProgressView(colorType: .light)
                        .opacity(viewModel.invitationLoading ? 1 : 0)
                    Text(L10n.Onboarding.Invitation.acceptButton)
                        .opacity(viewModel.invitationLoading ? 0 : 1)
                }
            }
            .buttonStyle(.primaryButton)
            .disabled(viewModel.invitationLoading)
        }
        .listRowSeparator(.hidden)
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
                .onAppear {
                    assertionFailure("Unmapped onboarding flow (1)")
                }
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

    private var manualInputButton: some View {
        VStack {
            if !viewModel.discoveredInstances.isEmpty {
                orDivider
            }
            Button(action: {
                showManualInput = true
            }) {
                Text(L10n.Onboarding.Scanning.Manual.Button.title)
            }
            .buttonStyle(.linkButton)
            .padding()
        }
        .listRowBackground(Color.clear)
    }

    // Divider between the list and manual input button providing alternative
    private var orDivider: some View {
        HStack {
            line()
            Text(L10n.Onboarding.Scanning.Manual.Button.Divider.title)
                .foregroundColor(Color(uiColor: .secondaryLabel))
            line()
        }
        .padding(.vertical, Spaces.one)
        .opacity(0.5)
    }

    private func line() -> some View {
        Rectangle()
            .frame(maxWidth: .infinity)
            .frame(height: 1)
            .foregroundStyle(Color(uiColor: .secondaryLabel))
    }
}
