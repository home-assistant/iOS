import Foundation

/// Stable identifiers for the elements UI tests drive.
///
/// This file is compiled into both the app and the UI test bundle, so the tests never hardcode a
/// string the app can rename out from under them, and never depend on user-facing copy that
/// translation or a wording change would break.
enum AccessibilityIdentifier: String {
    case onboardingWelcomeContinue = "onboarding.welcome.continue"
    case onboardingServersManualEntry = "onboarding.servers.manualEntry"
    case onboardingManualEntryConnect = "onboarding.manualEntry.connect"
    case onboardingDeviceNameSave = "onboarding.deviceName.save"
    case onboardingLocalOnlyDisclaimerContinue = "onboarding.localOnlyDisclaimer.continue"
    case onboardingLocationShare = "onboarding.location.share"
    case onboardingLocationSkip = "onboarding.location.skip"
    case onboardingLocalAccessSecureOption = "onboarding.localAccess.option.secure"
    case onboardingLocalAccessLessSecureOption = "onboarding.localAccess.option.lessSecure"
    case onboardingLocalAccessNext = "onboarding.localAccess.next"
    case onboardingHomeNetworkNext = "onboarding.homeNetwork.next"
    case notificationPermissionRequestPrimary = "notificationPermission.request.primary"
    case notificationPermissionRequestSecondary = "notificationPermission.request.secondary"
    case settingsList = "settings.list"
}
