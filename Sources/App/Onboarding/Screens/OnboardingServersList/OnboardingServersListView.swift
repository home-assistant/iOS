import Combine
import Shared
import SwiftUI

struct OnboardingServersListView: View {
    @ObservedObject private var viewModel = OnboardingScanningViewModel()
    @State private var showDocumentation = false
    @State private var showManualInput = false

    var body: some View {
        List {
            Section {
                ServersScanAnimationView()
                    .listRowBackground(Color.clear)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            ForEach(viewModel.discoveredInstances, id: \.uuid) { instance in
                if #available(iOS 17, *) {
                    Section {
                        serverRow(instance: instance)
                    }
                    .listSectionSpacing(.compact)
                } else {
                    serverRow(instance: instance)
                }
            }
            .disabled(viewModel.currentlyInstanceLoading != nil)
        }
        .animation(.easeInOut, value: viewModel.discoveredInstances.count)
        .safeAreaInset(edge: .bottom) {
            bottomButtons
        }
        .navigationTitle(L10n.Onboarding.Scanning.title)
        .toolbar(content: {
            ToolbarItem(placement: .topBarTrailing) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .opacity(viewModel.isLoading ? 1 : 0)
                    .animation(.easeInOut, value: viewModel.isLoading)
            }
        })
        .onAppear {
            viewModel.startDiscovery()
        }
        .onDisappear {
            viewModel.stopDiscovery()
            viewModel.currentlyInstanceLoading = nil
        }
        .sheet(isPresented: $showManualInput, content: {
            ManualURLEntryView { connectURL in
                viewModel.isLoading = true
                viewModel.selectInstance(.init(manualURL: connectURL))
            }
        })
        .fullScreenCover(isPresented: $showDocumentation) {
            SafariWebView(url: AppConstants.WebURLs.homeAssistantGetStarted)
        }
        .sheet(isPresented: .init(get: {
            if case .error = viewModel.nextDestination {
                return true
            } else {
                return false
            }
        }, set: { newValue in
            if !newValue {
                viewModel.resetFlow()
            }
        })) {
            switch viewModel.nextDestination {
            case .next, .none:
                // This scenarios are handlded in full screen
                EmptyView()
            case let .error(error):
                ConnectionErrorDetailsView(
                    server: ServerFixture.standard,
                    error: error,
                    showSettingsEntry: false,
                    expandMoreDetails: true
                )
            }
        }
        .fullScreenCover(isPresented: .init(get: {
            if case .next = viewModel.nextDestination {
                return true
            } else {
                return false
            }
        }, set: { newValue in
            if !newValue {
                viewModel.resetFlow()
            }
        })) {
            switch viewModel.nextDestination {
            case let .next(server):
                NavigationView {
                    AnyView(OnboardinSuccessController(server: server))
                }
                .navigationViewStyle(.stack)
            case .error, .none:
                // This scenarios are handlded in sheet
                EmptyView()
            }
        }
    }

    private func serverRow(instance: DiscoveredHomeAssistant) -> some View {
        OnboardingScanningInstanceRow(
            name: instance.locationName,
            internalURLString: instance.internalURL?.absoluteString,
            externalURLString: instance.externalURL?.absoluteString,
            internalOrExternalURLString: instance.internalOrExternalURL.absoluteString,
            isLoading: instance == viewModel.currentlyInstanceLoading
        )
        .onTapGesture {
            viewModel.selectInstance(instance)
        }
    }

    private var bottomButtons: some View {
        VStack {
            Button(action: {
                showManualInput = true
            }) {
                Text(L10n.Onboarding.Scanning.manual)
            }
            .buttonStyle(.primaryButton)
            Button(action: {
                showDocumentation = true
            }) {
                Text(L10n.Onboarding.Servers.Docs.read)
            }
            .buttonStyle(.secondaryButton)
        }
        .padding([.horizontal, .top])
        .background(.ultraThinMaterial)
    }
}
