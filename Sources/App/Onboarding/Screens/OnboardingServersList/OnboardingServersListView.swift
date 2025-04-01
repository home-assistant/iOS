import Combine
import Shared
import SwiftUI

struct OnboardingServersListView: View {
    @ObservedObject private var viewModel = OnboardingScanningViewModel()
    @State private var isLoading = false
    @State private var showDocumentation = false

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
        }
        .animation(.easeInOut, value: viewModel.discoveredInstances.count)
        .safeAreaInset(edge: .bottom) {
            bottomsButtons
        }
        .navigationTitle(L10n.Onboarding.Scanning.title)
        .toolbar(content: {
            ToolbarItem(placement: .topBarTrailing) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .opacity(isLoading ? 1 : 0)
                    .animation(.easeInOut, value: isLoading)
            }
        })
        .onAppear {
            viewModel.startDiscovery()
        }
        .onDisappear {
            viewModel.stopDiscovery()
        }
        .fullScreenCover(isPresented: $showDocumentation) {
            SafariWebView(url: AppConstants.WebURLs.homeAssistantGetStarted)
        }
    }

    private func serverRow(instance: DiscoveredHomeAssistant) -> some View {
        OnboardingScanningInstanceRow(
            name: instance.locationName,
            internalURLString: instance.internalURL?.absoluteString,
            externalURLString: instance.externalURL?.absoluteString,
            internalOrExternalURLString: instance.internalOrExternalURL.absoluteString,
            isLoading: $isLoading
        )
        .onTapGesture {
            viewModel.selectInstance(instance)
        }
    }

    private var bottomsButtons: some View {
        VStack {
            Button(action: {}) {
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
        .background(.regularMaterial)
    }
}
