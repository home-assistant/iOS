#if DEBUG
import Foundation

final class MockWatchHomeViewModel: WatchHomeViewModelProtocol {
    @Published var assistService: WatchAssistService = .init()
    @Published var actions: [WatchActionItem] = []
    @Published var state: WatchHomeViewState = .idle

    func runActionId(_ actionId: String, completion: @escaping (Bool) -> Void) {}

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
