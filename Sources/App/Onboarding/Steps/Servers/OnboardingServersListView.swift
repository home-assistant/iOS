import Combine
import Shared
import SwiftUI

struct OnboardingServersListView: View {
    enum Constants {
        static let initialDelayUntilDismissCenterLoader: TimeInterval = 3
        static let minimumDelayUntilDismissCenterLoader: TimeInterval = 1.5
        static let delayUntilAutoconnect: TimeInterval = 2

        enum MacSheetSize {
            static let errorDetailsMinWidth: CGFloat = 760
            static let errorDetailsMinHeight: CGFloat = 680
            static let manualInputMinWidth: CGFloat = 720
            static let manualInputMinHeight: CGFloat = 600
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass

    @StateObject private var viewModel: OnboardingServersListViewModel
    /// Owned by `OnboardingNavigationView`; the auth flow pushes its pages onto its navigation path.
    @ObservedObject private var presenter: OnboardingAuthPresenter

    @State private var showDocumentation = false
    @State private var showManualInput = false
    @State private var screenLoaded = false
    @State private var autoConnectWorkItem: DispatchWorkItem?
    @State private var autoConnectInstance: DiscoveredHomeAssistant?
    @State private var autoConnectBottomSheetState: AppleLikeBottomSheetViewState?
    @State private var rejectedInvitation = false

    private let prefillURL: URL?
    private let onboardingStyle: OnboardingStyle

    private var invitationURL: URL? {
        prefillURL ?? Current.appSessionValues.inviteURL
    }

    private var shouldShowInvitation: Bool {
        invitationURL != nil && !rejectedInvitation
    }

    init(
        prefillURL: URL? = nil,
        shouldDismissOnSuccess: Bool = false,
        onboardingStyle: OnboardingStyle,
        presenter: OnboardingAuthPresenter
    ) {
        self.prefillURL = prefillURL
        self
            ._viewModel =
            .init(wrappedValue: OnboardingServersListViewModel(shouldDismissOnSuccess: shouldDismissOnSuccess))
        self.onboardingStyle = onboardingStyle
        self.presenter = presenter
    }

    var body: some View {
        ZStack {
            content
            if !shouldShowInvitation {
                centerLoader
                autoConnectView
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, content: {
            if autoConnectInstance == nil, !shouldShowInvitation {
                manualInputButton
            }
        })
        .toolbar(content: {
            toolbarItems
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
        .onChange(of: viewModel.discoveredInstances) { newValue in
            if newValue.count == 1 {
                scheduleAutoConnect()
            } else if newValue.count > 1 {
                cancelAutoConnect()
                // We display the loader a bit after instances are discovered
                // if there is just 1 server available we connect to it automatically
                // otherwise we display the list of servers
                scheduleCenterLoaderDimiss(
                    amountOfTimeToWaitToDismissCenterLoader: Constants
                        .minimumDelayUntilDismissCenterLoader
                )
            }
        }
        .sheet(isPresented: $viewModel.showError) {
            errorView
                .macOnboardingSheetFrame(
                    minWidth: Constants.MacSheetSize.errorDetailsMinWidth,
                    minHeight: Constants.MacSheetSize.errorDetailsMinHeight
                )
        }
        .sheet(isPresented: $showManualInput) {
            ManualURLEntryView { connectURL in
                viewModel.manualInputLoading = true
                viewModel.selectInstance(.init(manualURL: connectURL), presenter: presenter)
            }
            .macOnboardingSheetFrame(
                minWidth: Constants.MacSheetSize.manualInputMinWidth,
                minHeight: Constants.MacSheetSize.manualInputMinHeight
            )
        }
    }

    @ViewBuilder
    private var autoConnectView: some View {
        if autoConnectInstance != nil {
            AppleLikeBottomSheet(
                title: autoConnectInstance?.bonjourName ?? autoConnectInstance?.locationName ?? L10n.unknownLabel,
                content: {
                    autoConnectViewContent(instance: autoConnectInstance)
                },
                state: $autoConnectBottomSheetState,
                customDismiss: {
                    autoConnectInstance = nil
                },
                willDismiss: {
                    autoConnectInstance = nil
                }
            )
            .onDisappear {
                hideCenterLoader()
            }
        }
    }

    private func hideCenterLoader() {
        viewModel.showCenterLoader = false
    }

    private func autoConnectViewContent(instance: DiscoveredHomeAssistant?) -> some View {
        VStack(spacing: DesignSystem.Spaces.three) {
            Spacer()
            Image(systemSymbol: .externaldriveConnectedToLineBelow)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 240, height: 100)
                .foregroundStyle(.haPrimary)
                .padding(.bottom, DesignSystem.Spaces.four)
            Text(instance?.internalOrExternalURL.absoluteString ?? "--")
                .font(DesignSystem.Font.body.weight(.light))
                .foregroundStyle(.secondary)
                .screenCaptureProtected()
            Button {
                autoConnectInstance = nil
                guard let instance else { return }
                viewModel.selectInstance(instance, presenter: presenter)
            } label: {
                Text(L10n.Onboarding.Servers.AutoConnect.button)
            }
            .buttonStyle(.primaryButton)
        }
    }

    private func scheduleAutoConnect() {
        autoConnectWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak viewModel] in
            guard let viewModel else { return }
            if viewModel.discoveredInstances.count == 1 {
                autoConnectInstance = viewModel.discoveredInstances.first
            } else if viewModel.discoveredInstances.count > 1 {
                hideCenterLoader()
            }
        }
        autoConnectWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.delayUntilAutoconnect, execute: workItem)
    }

    private func cancelAutoConnect() {
        autoConnectWorkItem?.cancel()
        autoConnectWorkItem = nil
    }

    private func scheduleCenterLoaderDimiss(amountOfTimeToWaitToDismissCenterLoader: CGFloat) {
        DispatchQueue.main.asyncAfter(deadline: .now() + amountOfTimeToWaitToDismissCenterLoader) {
            hideCenterLoader()
        }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        // Cancel for the add-server sheet lives here (not on the onboarding container) so it isn't
        // shown on top of the auth flow's pages, which bring their own chrome.
        if onboardingStyle.insertsCancelButton, !Current.isCatalyst {
            ToolbarItem(placement: .topBarLeading) {
                Button(L10n.cancelLabel) {
                    dismiss()
                }
            }
        }
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
                    if Current.isCatalyst {
                        URLOpener.shared.open(
                            AppConstants.WebURLs.homeAssistantGetStarted,
                            options: [:],
                            completionHandler: nil
                        )
                    } else {
                        showDocumentation = true
                    }
                }, label: {
                    Image(systemSymbol: .questionmark)
                })
                .sheet(isPresented: $showDocumentation) {
                    SafariWebView(url: AppConstants.WebURLs.homeAssistantCompanionGetStarted)
                }
            }
        }
    }

    private var content: some View {
        Group {
            if shouldShowInvitation, let invitationURL {
                InvitationView(
                    invitationURL: invitationURL,
                    isAccepting: viewModel.invitationLoading,
                    onAccept: {
                        acceptInvitation(url: invitationURL)
                    },
                    onReject: {
                        rejectInvitation()
                    }
                )
                .onAppear {
                    // No need for center loader logic or auto connect in invitation context.
                    cancelAutoConnect()
                    hideCenterLoader()
                }
            } else {
                ScrollView {
                    VStack(spacing: DesignSystem.Spaces.two) {
                        headerView
                        list
                            .opacity(viewModel.showCenterLoader ? 0 : 1)
                            .animation(.easeInOut, value: viewModel.showCenterLoader)
                    }
                    .padding(.horizontal, DesignSystem.Spaces.two)
                }
            }
        }
    }

    private func onAppear() {
        if !screenLoaded {
            screenLoaded = true
            startDiscoveryIfNeeded()
        } else if !shouldShowInvitation {
            // Reappearing after an auth flow page above was popped — being covered stopped
            // discovery, so resume it without clearing what was already found.
            viewModel.resumeDiscovery()
        }
    }

    private func onDisappear() {
        viewModel.stopDiscovery()
        viewModel.currentlyInstanceLoading = nil
    }

    private var centerLoader: some View {
        SearchingServersAnimationView(text: L10n.Onboarding.Servers.Search.Loader.text)
            .padding(.horizontal)
            .offset(y: autoConnectInstance == nil ? 0 : -100)
            .opacity(viewModel.showCenterLoader && !viewModel.invitationLoading ? 1 : 0)
            .animation(.easeInOut, value: viewModel.showCenterLoader)
            .animation(.easeInOut, value: autoConnectInstance)
    }

    private func startDiscoveryIfNeeded() {
        guard !shouldShowInvitation else { return }
        viewModel.startDiscovery()
    }

    private func acceptInvitation(url: URL) {
        viewModel.invitationLoading = true
        viewModel.selectInstance(.init(manualURL: url), presenter: presenter)
    }

    private func rejectInvitation() {
        if onboardingStyle == .secondary {
            dismiss()
            return
        }
        rejectedInvitation = true
        Current.appSessionValues.inviteURL = nil
        viewModel.showCenterLoader = true
        viewModel.startDiscovery()
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

    @ViewBuilder
    private var list: some View {
        ForEach(viewModel.discoveredInstances, id: \.uuid) { instance in
            serverRow(instance: instance)
        }
        .disabled(viewModel.currentlyInstanceLoading != nil)
        if !viewModel.discoveredInstances.isEmpty {
            listLoader
                .padding(.top, DesignSystem.Spaces.one)
        }
    }

    private var listLoader: some View {
        HAProgressView()
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var headerView: some View {
        Text(L10n.Onboarding.Servers.title)
            .font(DesignSystem.Font.largeTitle.bold())
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, DesignSystem.Spaces.four)
    }

    private func serverRow(instance: DiscoveredHomeAssistant) -> some View {
        Button(action: {
            viewModel.selectInstance(instance, presenter: presenter)
        }, label: {
            OnboardingScanningInstanceRow(
                name: instance.bonjourName ?? instance.locationName,
                internalURLString: instance.internalURL?.absoluteString,
                externalURLString: instance.externalURL?.absoluteString,
                internalOrExternalURLString: instance.internalOrExternalURL.absoluteString,
                isLoading: instance == viewModel.currentlyInstanceLoading
            )
            // To make button tappable in any part of it
            .contentShape(Rectangle())
        })
        .tint(Color(uiColor: .label))
        .buttonStyle(.plain)
        .frame(maxWidth: DesignSystem.List.rowMaxWidth)
    }

    private var manualInputButton: some View {
        Button(action: {
            showManualInput = true
        }) {
            Text(L10n.Onboarding.Scanning.Manual.Button.title)
        }
        .buttonStyle(.secondaryButton)
        .padding()
        // A little bit of opacity to indicate items behind it
        .background(Color(uiColor: .systemBackground).opacity(0.9))
    }

    // Divider between the list and manual input button providing alternative
    private var orDivider: some View {
        HStack {
            line()
            Text(L10n.Onboarding.Scanning.Manual.Button.Divider.title)
                .foregroundColor(Color(uiColor: .secondaryLabel))
            line()
        }
        .padding(.vertical, DesignSystem.Spaces.one)
        .opacity(0.5)
    }

    private func line() -> some View {
        Rectangle()
            .frame(maxWidth: .infinity)
            .frame(height: 1)
            .foregroundStyle(Color(uiColor: .secondaryLabel))
    }
}

#Preview {
    NavigationStack {
        OnboardingServersListView(
            prefillURL: nil,
            onboardingStyle: .secondary,
            presenter: OnboardingAuthPresenter()
        )
    }
}
