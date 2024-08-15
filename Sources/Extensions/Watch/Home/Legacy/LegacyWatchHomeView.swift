import Shared
import SwiftUI
import UIKit

/// Old home where we presented all Actions and scenes
struct LegacyWatchHomeView<ViewModel>: View where ViewModel: LegacyWatchHomeViewModelProtocol {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: ViewModel
    @State private var showAssist = false

    private let stateIconSize: CGSize = .init(width: 60, height: 60)
    private let stateIconColor: UIColor = .white
    private let interfaceDevice = WKInterfaceDevice.current()

    init(viewModel: ViewModel) {
        self._viewModel = .init(wrappedValue: viewModel)
    }

    var body: some View {
        content
            .onAppear {
                viewModel.onAppear()
            }
            .onDisappear {
                viewModel.onDisappear()
            }
            .fullScreenCover(isPresented: $showAssist, content: {
                WatchAssistView.build()
            })
            .onReceive(NotificationCenter.default.publisher(for: AssistDefaultComplication.launchNotification)) { _ in
                showAssist = true
            }
            .onChange(of: scenePhase) { newScenePhase in
                switch newScenePhase {
                case .active:
                    viewModel.fetchNetworkInfo(completion: nil)
                default:
                    break
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        list
            .navigationTitle("")
            .modify {
                if #available(watchOS 10, *) {
                    $0.toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: {
                                showAssist = true
                            }, label: {
                                Image(uiImage: MaterialDesignIcons.messageProcessingOutlineIcon.image(
                                    ofSize: .init(width: 24, height: 24),
                                    color: Asset.Colors.haPrimary.color
                                ))
                            })
                        }
                    }
                } else {
                    $0
                }
            }
    }

    private var stateViewBackground: some ShapeStyle {
        if #available(watchOS 10, *) {
            return .regularMaterial
        } else {
            return Color.black.opacity(0.6)
        }
    }

    private var list: some View {
        List {
            ForEach(viewModel.actions, id: \.id) { action in
                WatchActionButtonView<ViewModel>(action: action)
                    .environmentObject(viewModel)
            }
            if viewModel.actions.isEmpty {
                noActionsView
            }
        }
        .animation(.easeInOut, value: viewModel.actions)
        // This improves how the overlayed assist view looks
        .opacity(showAssist ? 0.5 : 1)
    }

    private var noActionsView: some View {
        Text(L10n.Watch.Labels.noAction)
            .font(.footnote)
            .padding(.vertical)
    }
}

#if DEBUG
#Preview {
    LegacyWatchHomeView(viewModel: MockWatchHomeViewModel())
}
#endif
