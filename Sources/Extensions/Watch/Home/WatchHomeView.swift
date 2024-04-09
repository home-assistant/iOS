import Shared
import SwiftUI
import UIKit

struct WatchHomeView<ViewModel>: View where ViewModel: WatchHomeViewModelProtocol {
    @StateObject private var viewModel: ViewModel

    private let stateIconSize: CGSize = .init(width: 60, height: 60)
    private let stateIconColor: UIColor = .white
    private let interfaceDevice = WKInterfaceDevice.current()

    init(viewModel: ViewModel) {
        self._viewModel = .init(wrappedValue: viewModel)
        MaterialDesignIcons.register()
    }

    var body: some View {
        ZStack {
            list
            noActionsView
            stateView
        }
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }

    @ViewBuilder
    private var stateView: some View {
        VStack {
            switch viewModel.state {
            case .loading:
                ProgressView()
                    .progressViewStyle(.circular)
            case .success:
                Image(uiImage: MaterialDesignIcons.checkCircleIcon.image(ofSize: stateIconSize, color: stateIconColor))
                    .onAppear {
                        interfaceDevice.play(.success)
                    }
            case .failure:
                Image(uiImage: MaterialDesignIcons.closeIcon.image(ofSize: stateIconSize, color: stateIconColor))
                    .onAppear {
                        interfaceDevice.play(.failure)
                    }
            case .idle:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(stateViewBackground)
        .opacity(viewModel.state != .idle ? 1 : 0)
    }

    private var stateViewBackground: some ShapeStyle {
        if #available(watchOS 10, *) {
            return .regularMaterial
        } else {
            return Color.black.opacity(0.6)
        }
    }

    private var list: some View {
        List(viewModel.actions, id: \.id) { action in
            Button {
                viewModel.runActionId(action.id)
            } label: {
                HStack(spacing: Spaces.one) {
                    Image(uiImage: MaterialDesignIcons(named: action.iconName).image(
                        ofSize: .init(width: 24, height: 24),
                        color: .init(hex: action.iconColor)
                    ))
                    Text(action.name)
                        .foregroundStyle(Color(uiColor: .init(hex: action.textColor)))
                }
            }
            .listRowBackground(
                Color(uiColor: .init(hex: action.backgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            )
        }
        .animation(.easeInOut, value: viewModel.actions)
    }

    private var noActionsView: some View {
        Text(L10n.Watch.Labels.noAction)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut, value: viewModel.actions)
            .opacity(viewModel.actions.isEmpty ? 1 : 0)
    }
}

#if DEBUG
#Preview {
    WatchHomeView(viewModel: MockWatchHomeViewModel())
}

final class MockWatchHomeViewModel: WatchHomeViewModelProtocol {
    func runActionId(_ actionId: String) {
        DispatchQueue.main.async {
            self.state = .loading
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.state = .success
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.state = .failure
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.state = .idle
        }
    }

    @Published var actions: [WatchActionItem] = []
    @Published var state: WatchHomeViewState = .idle

    func onAppear() {
        actions = [
            .init(
                id: "1",
                name: "Hello",
                iconName: "ab_testing",
                backgroundColor: "#34eba8",
                iconColor: "#4479b3",
                textColor: "#4479b3"
            ),
        ]
    }

    func onDisappear() {}
}
#endif
