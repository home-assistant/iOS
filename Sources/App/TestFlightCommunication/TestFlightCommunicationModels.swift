import Foundation
import Shared

/// Stable identifier for a TestFlight message used to track seen state.
/// Define message IDs as static constants on this type:
///
/// ```swift
/// extension TestFlightMessageId {
///     static let betaFeedbackRequest = TestFlightMessageId("beta-feedback-request-2026-06")
/// }
/// ```
struct TestFlightMessageId: RawRepresentable, Hashable {
    let rawValue: String
    init(_ rawValue: String) { self.rawValue = rawValue }
    init(rawValue: String) { self.rawValue = rawValue }
}

extension TestFlightMessageId {
    static let includeEmailWhenReporting = TestFlightMessageId("include-email-when-reporting-2026-06")
}

struct TestFlightMessage: Identifiable, Equatable {
    struct CallToAction: Equatable {
        let title: String
        let url: URL
    }

    let id: TestFlightMessageId
    let title: String
    let items: [WhatsNewItem]
    let targetPlatforms: [WhatsNewTargetPlatform]
    let callToAction: CallToAction?

    init(
        id: TestFlightMessageId,
        title: String,
        items: [WhatsNewItem],
        targetPlatforms: [WhatsNewTargetPlatform] = [.iPhone, .iPad, .mac],
        callToAction: CallToAction? = nil
    ) {
        precondition(!items.isEmpty)
        precondition(!targetPlatforms.isEmpty)
        self.id = id
        self.title = title
        self.items = items
        self.targetPlatforms = targetPlatforms
        self.callToAction = callToAction
    }
}
