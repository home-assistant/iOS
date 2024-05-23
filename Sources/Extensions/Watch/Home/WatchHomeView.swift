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
        }
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
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
        List(viewModel.actions, id: \.id) { action in
            WatchActionButtonView<ViewModel>(action: action)
                .environmentObject(viewModel)
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
#endif
