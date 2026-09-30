import Foundation
import HAKit
import Shared

enum StatusItemTitleRenderer {
    static func subscribe(
        api: HomeAssistantAPI,
        template: String,
        update: @escaping (String) -> Void
    ) -> HACancellable {
        let state = TitleState()
        let cancellable = CompositeHACancellable()

        cancellable.append(api.connection.send(.init(
            type: .rest(.post, "template"),
            data: ["template": template],
            shouldRetry: true
        )) { result in
            switch result {
            case let .success(data):
                guard !state.hasReceivedLiveUpdate else {
                    return
                }

                state.hasRenderedTitle = true
                update(renderedTitle(from: data))
            case let .failure(error):
                Current.Log.error("Failed to render status item title via REST fallback: \(error)")
            }
        })

        cancellable.append(api.connection.subscribe(
            to: .renderTemplate(template),
            initiated: { result in
                guard case let .failure(error) = result else {
                    return
                }

                Current.Log.error("Failed to subscribe to status item title updates: \(error)")

                if !state.hasRenderedTitle {
                    update(L10n.errorLabel)
                }
            },
            handler: { _, response in
                state.hasRenderedTitle = true
                state.hasReceivedLiveUpdate = true
                update(String(describing: response.result))
            }
        ))

        return cancellable
    }

    private static func renderedTitle(from data: HAData) -> String {
        switch data {
        case let .primitive(value):
            return String(describing: value)
        case let .dictionary(value):
            return String(describing: value)
        case let .array(value):
            return String(describing: value)
        case .empty:
            return ""
        }
    }

    private final class CompositeHACancellable: HACancellable {
        private var cancellables: [HACancellable]

        init(_ cancellables: [HACancellable] = []) {
            self.cancellables = cancellables
        }

        func append(_ cancellable: HACancellable) {
            cancellables.append(cancellable)
        }

        func cancel() {
            let activeCancellables = cancellables
            cancellables.removeAll()
            activeCancellables.forEach { $0.cancel() }
        }
    }

    private final class TitleState {
        var hasRenderedTitle = false
        var hasReceivedLiveUpdate = false
    }
}
