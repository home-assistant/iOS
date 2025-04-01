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
        .fullScreenCover(isPresented: .init(get: {
            viewModel.nextDestination != nil
        }, set: { newValue in
            if !newValue {
                viewModel.resetFlow()
            }
        })) {
            switch viewModel.nextDestination {
            case .next:
                EmptyView()
            case let .error(error):
                VStack {
                    CloseButton {
                        viewModel.resetFlow()
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding()
                    OnboardingErrorView(error: error)
                }
            case .none:
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
