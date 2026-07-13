import Foundation

/// The few app-owned values design-system components need but the package cannot reach (importing
/// `Shared` would be a dependency cycle). `Shared` populates `HADesignSystemEnvironment.current` once
/// at launch (`AppEnvironment.setup()`); until then every member has an English/default fallback so
/// the package renders sensibly standalone (previews, tests). This mirrors `HANetworkingEnvironment`.
public struct HADesignSystemEnvironment {
    public static var current = HADesignSystemEnvironment()

    /// Localized strings used inside components. `Shared` wires these to `L10n`.
    public var strings = Strings()

    /// Where `LabsLabel`'s report-issue button points. `Shared` wires this to `AppConstants.WebURLs.issues`.
    public var reportIssueURL = URL(string: "https://companion.home-assistant.io/app/ios/issues")!

    public init() {}

    public struct Strings {
        /// Accessibility label/hint for a `CollapsibleView` that is expanded.
        public var collapsibleViewCollapse = "Collapse"
        /// Accessibility label/hint for a `CollapsibleView` that is collapsed.
        public var collapsibleViewExpand = "Expand"
        /// Badge title on `PrivacyNoteView`.
        public var privacyLabel = "Privacy"
        /// Title of `LabsLabel`'s report-issue button.
        public var reportIssueButtonTitle = "Report issue"

        public init() {}
    }
}
