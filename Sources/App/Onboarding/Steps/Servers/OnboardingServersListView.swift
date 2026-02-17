import Combine
import Shared
import SwiftUI

struct OnboardingServersListView: View {
    enum Constants {
        static let initialDelayUntilDismissCenterLoader: TimeInterval = 3
        static let minimumDelayUntilDismissCenterLoader: TimeInterval = 1.5
        static let delayUntilAutoconnect: TimeInterval = 2
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @EnvironmentObject var hostingProvider: ViewControllerProvider

    @StateObject private var viewModel: OnboardingServersListViewModel

    @State private var showDocumentation = false
    @State private var showManualInput = false
    @State private var screenLoaded = false
    @State private var autoConnectWorkItem: DispatchWorkItem?
    @State private var autoConnectInstance: DiscoveredHomeAssistant?
    @State private var autoConnectBottomSheetState: AppleLikeBottomSheetViewState?

    private var presentingViewController: UIViewController {
        if let providedController = hostingProvider.viewController, Current.isCatalyst {
            return providedController
        } else if let hostingViewController = hostingProvider.viewController {
            switch onboardingStyle {
            case .initial, .required:
                return hostingViewController
            case .secondary:
                return hostingViewController.presentedViewController ?? hostingViewController
            }
        } else {
            fatalError("No controller provided for onboarding")
        }
    }

    private let prefillURL: URL?
    private let onboardingStyle: OnboardingStyle

    init(prefillURL: URL? = nil, shouldDismissOnSuccess: Bool = false, onboardingStyle: OnboardingStyle) {
        self.prefillURL = prefillURL
        self
            ._viewModel =
            .init(wrappedValue: OnboardingServersListViewModel(shouldDismissOnSuccess: shouldDismissOnSuccess))
        self.onboardingStyle = onboardingStyle
    }

    var body: some View {
        ZStack {
            content
            centerLoader
            autoConnectView
        }
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, content: {
            if autoConnectInstance == nil {
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
        }
        .sheet(isPresented: $showManualInput) {
            ManualURLEntryView { connectURL in
                viewModel.manualInputLoading = true
                viewModel.selectInstance(.init(manualURL: connectURL), presentingController: presentingViewController)
            }
        }
        .fullScreenCover(isPresented: .init(get: {
            viewModel.showPermissionsFlow && viewModel.onboardingServer != nil
        }, set: { newValue in
            viewModel.showPermissionsFlow = newValue
        })) {
            // isPresented guarantees onboardingServer
            // swiftlint:disable:next force_unwrapping
            OnboardingPermissionsNavigationView(onboardingServer: viewModel.onboardingServer!)
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
                viewModel.selectInstance(instance, presentingController: presentingViewController)
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

    private var toolbarItems: some ToolbarContent {
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
        ScrollView {
            VStack(spacing: DesignSystem.Spaces.two) {
                if let prefillURL {
                    prefillURLHeader(url: prefillURL)
                } else {
                    if let inviteURL = Current.appSessionValues.inviteURL {
                        prefillURLHeader(url: inviteURL)
                        Text(L10n.Onboarding.Invitation.otherOptions)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .font(DesignSystem.Font.headline)
                            .padding(.top, DesignSystem.Spaces.two)
                    } else {
                        headerView
                    }
                    list
                        .opacity(viewModel.showCenterLoader ? 0 : 1)
                        .animation(.easeInOut, value: viewModel.showCenterLoader)
                }
            }
            .padding(.horizontal, DesignSystem.Spaces.two)
        }
    }

    private func onAppear() {
        if !screenLoaded {
            screenLoaded = true
            if let prefillURL {
                viewModel.selectInstance(.init(manualURL: prefillURL), presentingController: presentingViewController)
            } else {
                viewModel.startDiscovery()
            }
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

    @ViewBuilder
    private func prefillURLHeader(url: URL) -> some View {
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
        .onAppear {
            // No need for center loader logic neither auto connect in invitation context
            cancelAutoConnect()
            hideCenterLoader()
        }
        Button {
            viewModel.selectInstance(.init(manualURL: url), presentingController: presentingViewController)
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
            viewModel.selectInstance(instance, presentingController: presentingViewController)
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
    NavigationView {
        OnboardingServersListView(prefillURL: nil, onboardingStyle: .secondary)
    }
}
