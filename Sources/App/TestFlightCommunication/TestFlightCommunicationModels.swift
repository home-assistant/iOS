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
    /// Optional app version. When set, the message is only shown on this exact app version.
    let version: WhatsNewAppVersion?
    /// Optional operating-system constraints. When set, the message is only shown to OS versions within the
    /// range; when `nil`, every OS version of the target platforms qualifies.
    let osRequirements: WhatsNewOSRequirements?
    let callToAction: CallToAction?

    init(
        id: TestFlightMessageId,
        title: String,
        items: [WhatsNewItem],
        targetPlatforms: [WhatsNewTargetPlatform] = [.iPhone, .iPad, .mac],
        version: WhatsNewAppVersion? = nil,
        osRequirements: WhatsNewOSRequirements? = nil,
        callToAction: CallToAction? = nil
    ) {
        precondition(!items.isEmpty)
        precondition(!targetPlatforms.isEmpty)
        self.id = id
        self.title = title
        self.items = items
        self.targetPlatforms = targetPlatforms
        self.version = version
        self.osRequirements = osRequirements
        self.callToAction = callToAction
    }

    /// Whether this message may be shown for the given platform, app version, and OS version. Unset `version`
    /// or `osRequirements` constraints are treated as always satisfied.
    func matches(
        platform: WhatsNewTargetPlatform,
        appVersion: WhatsNewAppVersion,
        osVersion: WhatsNewOSVersion
    ) -> Bool {
        guard targetPlatforms.contains(platform) else {
            return false
        }
        if let version, version != appVersion {
            return false
        }
        if let osRequirements, !osRequirements.allows(platform: platform, osVersion: osVersion) {
            return false
        }
        return true
    }
}
