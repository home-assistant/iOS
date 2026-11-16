#if os(iOS) && !targetEnvironment(macCatalyst)
import ActivityKit
import Shared

@available(iOS 17.2, *)
struct ActivitySnapshot: Identifiable {
    let id: String
    let tag: String
    let title: String
    let message: String

    init(activity: Activity<HALiveActivityAttributes>) {
        self.init(id: activity.id, attributes: activity.attributes, state: activity.content.state)
    }

    init(id: String, attributes: HALiveActivityAttributes, state: HALiveActivityAttributes.ContentState) {
        self.id = id
        self.tag = attributes.tag
        self.title = attributes.displayTitle(for: state)
        self.message = state.message
    }
}
#endif
