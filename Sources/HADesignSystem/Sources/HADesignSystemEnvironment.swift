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
        /// Accessibility label for `HAMediaControlCard`'s previous-track button.
        public var previousTrack = "Previous"
        /// Accessibility label for `HAMediaControlCard`'s next-track button.
        public var nextTrack = "Next"
        /// Accessibility label for `HAMediaControlCard`'s transport button while stopped.
        public var play = "Play"
        /// Accessibility label for `HAMediaControlCard`'s transport button while playing.
        public var pause = "Pause"
        /// Accessibility label for `HAAlarmPanelCard`'s delete key.
        public var deleteDigit = "Delete"
        /// Named accessibility action raising `HAHSColorPicker`'s saturation.
        public var moreSaturation = "More saturation"
        /// Named accessibility action lowering `HAHSColorPicker`'s saturation.
        public var lessSaturation = "Less saturation"
        /// Named accessibility action selecting a dual dial's lower target.
        public var adjustLowerTarget = "Adjust lower target"
        /// Named accessibility action selecting a dual dial's upper target.
        public var adjustUpperTarget = "Adjust upper target"
        /// Accessibility label for the minus button under a more-info dial.
        public var decrease = "Decrease"
        /// Accessibility label for the plus button under a more-info dial.
        public var increase = "Increase"
        /// Accessibility label for `HAStateControlToggle`'s switch.
        public var toggle = "Toggle"
        /// Accessibility label for `HAStateControlToggle`'s on button, shown for an assumed state.
        public var turnOn = "Turn on"
        /// Accessibility label for `HAStateControlToggle`'s off button, shown for an assumed state.
        public var turnOff = "Turn off"
        /// What `HAMoreInfoLock` locks with.
        public var lock = "Lock"
        /// What `HAMoreInfoLock` unlocks with.
        public var unlock = "Unlock"
        /// `HAMoreInfoLock`'s open button.
        public var openDoor = "Open door"
        /// `HAMoreInfoLock`'s open button once tapped, asking for a second tap.
        public var openDoorConfirm = "Really open?"
        /// What `HAMoreInfoLock` says once the door has been opened.
        public var openDoorDone = "Door open"
        /// Accessibility label for `HAMoreInfoMediaPlayer`'s shuffle button.
        public var shuffle = "Shuffle"
        /// Accessibility label for `HAMoreInfoMediaPlayer`'s repeat button.
        public var repeatMode = "Repeat"
        /// Accessibility value of `HAMoreInfoMediaPlayer`'s repeat button with repeat off.
        public var repeatOff = "Off"
        /// Accessibility value of `HAMoreInfoMediaPlayer`'s repeat button repeating everything.
        public var repeatAll = "All"
        /// Accessibility value of `HAMoreInfoMediaPlayer`'s repeat button repeating one track.
        public var repeatOne = "One"
        /// Accessibility label for `HAMoreInfoMediaPlayer`'s stop button.
        public var stop = "Stop"
        /// Accessibility label for `HAMoreInfoMediaPlayer`'s mute button.
        public var mute = "Mute"
        /// Accessibility label for `HAMoreInfoMediaPlayer`'s unmute button.
        public var unmute = "Unmute"
        /// Accessibility label for `HAMoreInfoMediaPlayer`'s volume slider.
        public var volume = "Volume"
        /// Accessibility label for `HAMoreInfoMediaPlayer`'s volume-down button.
        public var volumeDown = "Volume down"
        /// Accessibility label for `HAMoreInfoMediaPlayer`'s volume-up button.
        public var volumeUp = "Volume up"
        /// Accessibility label for `HAMoreInfoMediaPlayer`'s position slider.
        public var trackPosition = "Track position"
        /// `HAMoreInfoTimer`'s start action.
        public var timerStart = "Start"
        /// `HAMoreInfoTimer`'s action restarting a running timer with the entered duration.
        public var timerSet = "Set"
        /// `HAMoreInfoTimer`'s pause action.
        public var timerPause = "Pause"
        /// `HAMoreInfoTimer`'s cancel action.
        public var timerCancel = "Cancel"
        /// `HAMoreInfoTimer`'s finish action.
        public var timerFinish = "Finish"
        /// `HAMoreInfoUpdate`'s install button.
        public var updateInstall = "Update"
        /// `HAMoreInfoUpdate`'s skip button.
        public var updateSkip = "Skip"
        /// `HAMoreInfoUpdate`'s button undoing a skip.
        public var updateClearSkipped = "Clear skipped"
        /// `HAMoreInfoUpdate`'s link to the release notes.
        public var updateReleaseAnnouncement = "Read release announcement"
        /// `HAMoreInfoCover`'s toggle to the position sliders.
        public var coverPositionMode = "Position"
        /// `HAMoreInfoCover`'s toggle to the open/stop/close buttons.
        public var coverButtonsMode = "Buttons"
        /// `HAMoreInfoLight`'s toggle to the brightness slider.
        public var lightBrightness = "Brightness"
        /// `HAMoreInfoLight`'s toggle to the colour wheel.
        public var lightColor = "Color"
        /// `HAMoreInfoLight`'s toggle to the colour-temperature slider.
        public var lightColorTemperature = "Color temperature"
        /// `HAMoreInfoLight`'s button switching a colour light back to white.
        public var lightSetWhite = "Set white"
        /// `HAMoreInfoScene`'s button.
        public var sceneActivate = "Activate"
        /// The vacuum's clean-by-area entry in `HAMoreInfoVacuum`.
        public var vacuumCleaning = "Cleaning"
        /// The value under `vacuumCleaning`.
        public var vacuumByArea = "By area"

        public init() {}
    }
}
