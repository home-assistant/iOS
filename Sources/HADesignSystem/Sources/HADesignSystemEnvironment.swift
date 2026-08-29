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
        /// The bold word `HATipView` puts before its message.
        public var tipPrefix = "Tip"
        /// Accessibility label for `HAAlertView`'s dismiss button.
        public var dismissAlert = "Dismiss alert"
        /// Accessibility label for `HAInputChip`'s remove button.
        public var removeChip = "Remove"
        /// Accessibility label for `HAEnergyPeriodSelector`'s back arrow.
        public var previousPeriod = "Previous period"
        /// Accessibility label for `HAEnergyPeriodSelector`'s forward arrow.
        public var nextPeriod = "Next period"
        /// Label of `HAEnergyPeriodSelector`'s comparison toggle.
        public var compareWithPreviousPeriod = "Compare with previous period"
        /// Accessibility label for `HALightCard`'s overflow button.
        public var moreInformation = "More information"
        /// Accessibility label for the clear button on `HABaseTimeInput` and `HADateInput`.
        public var clearValue = "Clear"
        /// What `HAAbsoluteTime` shows when it has no timestamp.
        public var never = "Never"
        /// Accessibility label for `HAQRCode`.
        public var qrCode = "QR code"
        /// Shown by `HAQRCode` when the string cannot be encoded.
        public var qrCodeFailed = "Could not generate the QR code"
        /// Title of the retry button on `HAQRScanner`'s error alert.
        public var retry = "Retry"
        /// Label of `HAQRScanner`'s fallback text field, shown when there is no camera.
        public var enterCodeManually = "Enter the code manually"
        /// Title of `HAQRScanner`'s manual-entry submit button.
        public var submit = "Submit"
        /// How `HACalendarCard` writes an event with no time of its own.
        public var allDay = "All day"
        /// Expands `HADistributionCard`'s collapsed legend.
        public var showMore = "Show more"
        /// Collapses `HADistributionCard`'s legend again.
        public var showLess = "Show less"

        public init() {}
    }
}
