import Shared
import SwiftUI

struct WatchActionButtonView<ViewModel>: View where ViewModel: WatchHomeViewModelProtocol {
    enum ActionState {
        case idle
        case loading
        case success
        case failure
    }

    @EnvironmentObject private var homeViewModel: ViewModel

    let action: WatchActionItem

    @State private var state: ActionState = .idle

    var body: some View {
        content
            .onChange(of: state) { newValue in
                // On watchOS 10 this can be replaced by '.sensoryFeedback' modifier
                let currentDevice = WKInterfaceDevice.current()
                switch newValue {
                case .success:
                    currentDevice.play(.success)
                case .failure:
                    currentDevice.play(.failure)
                case .loading:
                    currentDevice.play(.click)
                default:
                    break
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        Button {
            state = .loading
            homeViewModel.runActionId(action.id) { success in
                state = success ? .success : .failure
                resetState()
            }
        } label: {
            HStack(spacing: Spaces.one) {
                iconToDisplay
                    .animation(.easeInOut, value: state)
                Text(action.name)
                    .foregroundStyle(Color(uiColor: .init(hex: action.textColor)))
            }
        }
        .disabled(state != .idle)
        .listRowBackground(
            Color(uiColor: .init(hex: action.backgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        )
    }

    private func resetState() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            state = .idle
        }
    }

    private var iconToDisplay: some View {
        VStack {
            switch state {
            case .idle:
                Image(uiImage: MaterialDesignIcons(named: action.iconName).image(
                    ofSize: .init(width: 24, height: 24),
                    color: .init(hex: action.iconColor)
                ))
            case .loading:
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(width: 24, height: 24)
                    .tint(.black)
                    .shadow(color: .white, radius: 10)
            case .success:
                makeActionImage(iconName: MaterialDesignIcons.checkIcon.name)
            case .failure:
                makeActionImage(iconName: MaterialDesignIcons.closeThickIcon.name)
            }
        }
    }

    private func makeActionImage(iconName: String) -> some View {
        Image(uiImage: MaterialDesignIcons(named: iconName).image(
            ofSize: .init(width: 24, height: 24),
            color: .init(hex: action.iconColor)
        ))
    }
}
