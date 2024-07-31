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
                // TODO: On watchOS 10 this can be replaced by '.sensoryFeedback' modifier
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
            HStack(spacing: Spaces.two) {
                iconToDisplay
                    .frame(width: 30, height: 30)
                    .animation(.easeInOut, value: state)
                Text(action.name)
                    .foregroundStyle(action.useCustomColors ? Color(uiColor: .init(hex: action.textColor)) : .white)
            }
        }
        .disabled(state != .idle)
        .modify { view in
            if action.useCustomColors {
                view.listRowBackground(
                    Color(uiColor: .init(hex: action.backgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                )
            } else {
                view
            }
        }
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
                VStack {
                    Image(uiImage: MaterialDesignIcons(named: action.iconName).image(
                        ofSize: .init(width: 24, height: 24),
                        color: .init(hex: action.iconColor)
                    ))
                    .foregroundColor(Color(uiColor: .init(hex: action.iconColor)))
                    .padding(Spaces.one)
                }
                .background(Color(uiColor: .init(hex: action.iconColor)).opacity(0.3))
                .clipShape(Circle())
            case .loading:
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(width: 24, height: 24)
                    .shadow(color: .white, radius: 10)
            case .success:
                makeActionImage(systemName: "checkmark.circle.fill")
            case .failure:
                makeActionImage(systemName: "xmark.circle")
            }
        }
    }

    private func makeActionImage(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 24))
            .foregroundStyle(.white)
    }
}
