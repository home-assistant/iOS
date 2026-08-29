import Foundation

/// What ``HAQRScanner`` is currently doing. Mirrors the branches of `ha-qr-scanner`'s `render`,
/// which shows an alert, a spinner, the camera, or a manual-entry fallback depending on how the
/// camera is getting on.
///
/// The status is the caller's rather than the view's: whether a camera exists, whether the user
/// granted access and whether a scan was rejected are all answered outside the design system, and
/// passing the answer in is what lets every state be previewed and snapshotted.
public enum HAQRScannerStatus: Equatable, Sendable {
    /// The camera is live and looking for a code.
    case scanning
    /// Starting the camera up.
    case loading
    /// A scan failed or the camera errored. Shown as an error alert with a retry button, as the
    /// frontend does.
    case failed(String)
    /// No camera to use — the frontend's `not_supported` and `only_https_supported` branches, which
    /// fall back to typing the code in by hand.
    case unavailable(String)
}

extension HAQRScannerStatus: FrontendComponent {
    public static var frontendComponentName: String { "ha-qr-scanner" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}
