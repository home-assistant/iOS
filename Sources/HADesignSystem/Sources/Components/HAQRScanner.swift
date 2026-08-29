#if !os(watchOS)
import SwiftUI

/// Scans a QR code with the camera, falling back to typing it in. The SwiftUI counterpart of the
/// frontend's `ha-qr-scanner`.
///
/// The chrome is here and the capture is ``HACameraPreview``, the same split the frontend makes
/// between its `render` and the `qr-scanner` library it drives. Which state to show is the
/// caller's call — see ``HAQRScannerStatus`` — because whether a camera exists and whether the user
/// allowed it are questions the app answers, not the design system.
public struct HAQRScanner: View {
    @State private var manualEntry = ""
    private let status: HAQRScannerStatus
    private let title: String?
    private let descriptionText: String?
    private let viewfinderSize: CGFloat
    private let onScan: (String) -> Void
    private let onRetry: (() -> Void)?

    /// - Parameters:
    ///   - viewfinderSize: The side of the square camera view. Explicit rather than derived from
    ///     the available width, because `aspectRatio` collapses to its minimum when the height
    ///     proposal is unbounded — the same reason ``HAGauge`` takes a diameter.
    ///   - onScan: Called with the decoded string, whether it came from the camera or was typed
    ///     into the fallback field.
    ///   - onRetry: Backs the retry button on the error alert. Without one the button is hidden,
    ///     matching the frontend, which only offers a retry when there is something to retry.
    public init(
        status: HAQRScannerStatus = .scanning,
        title: String? = nil,
        description descriptionText: String? = nil,
        viewfinderSize: CGFloat = 240,
        onScan: @escaping (String) -> Void,
        onRetry: (() -> Void)? = nil
    ) {
        self.status = status
        self.title = title
        self.descriptionText = descriptionText
        self.viewfinderSize = viewfinderSize
        self.onScan = onScan
        self.onRetry = onRetry
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
            if let title {
                Text(title)
                    .font(DesignSystem.Font.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let descriptionText {
                Text(descriptionText)
                    .font(DesignSystem.Font.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            switch status {
            case .scanning:
                viewfinder { HACameraPreview(onScan: onScan) }
            case .loading:
                viewfinder { HAProgressView() }
            case let .failed(message):
                errorAlert(message)
                viewfinder { HACameraPreview(onScan: onScan) }
            case let .unavailable(message):
                HAAlertView(message, alertType: .warning)
                manualEntryFallback
            }
        }
    }

    /// A square, like the frontend's `#canvas-container`: a viewfinder that changed shape with its
    /// content would make the frame jump as the camera starts.
    private func viewfinder(@ViewBuilder content: () -> some View) -> some View {
        ZStack {
            Color.black
            content()
        }
        .frame(width: viewfinderSize, height: viewfinderSize)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.one))
    }

    private func errorAlert(_ message: String) -> some View {
        HAAlertView(alertType: .error) {
            Text(message)
        } action: {
            if let onRetry {
                Button(HADesignSystemEnvironment.current.strings.retry, action: onRetry)
            }
        }
    }

    /// The frontend offers a text field when it cannot open a camera, so an unsupported browser is
    /// not a dead end. Same here for a denied permission or a device without a camera.
    private var manualEntryFallback: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            Text(HADesignSystemEnvironment.current.strings.enterCodeManually)
                .font(DesignSystem.Font.body)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: DesignSystem.Spaces.one) {
                // No placeholder: the line above already asks for the code, and repeating it in a
                // field this narrow only truncates.
                HATextField(placeholder: "", text: $manualEntry)
                Button(HADesignSystemEnvironment.current.strings.submit) {
                    onScan(manualEntry)
                }
                .buttonStyle(HAButtonStyle())
                .disabled(manualEntry.isEmpty)
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: DesignSystem.Spaces.three) {
            HAQRScanner(
                status: .loading,
                title: "Scan the code",
                description: "Point the camera at the QR code on the device.",
                onScan: { _ in }
            )
            HAQRScanner(status: .failed("That code was not recognised."), onScan: { _ in }, onRetry: {})
            HAQRScanner(status: .unavailable("This device has no camera."), onScan: { _ in })
        }
        .padding()
    }
}

extension HAQRScanner: FrontendComponent {
    public static var frontendComponentName: String { "ha-qr-scanner" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
