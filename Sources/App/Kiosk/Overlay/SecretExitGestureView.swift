import Combine
import SwiftUI
import UIKit

// MARK: - Secret Exit Gesture View

/// An invisible overlay that detects multi-tap gestures in a corner to access kiosk settings
/// This provides an escape hatch when navigation is locked down
public struct SecretExitGestureView: View {
    @ObservedObject private var kioskManager = KioskModeManager.shared
    @Binding var showSettings: Bool

    /// Size of the tap target area in the corner
    private let cornerTapSize: CGFloat = 80

    public init(showSettings: Binding<Bool>) {
        _showSettings = showSettings
    }

    public var body: some View {
        Group {
            if kioskManager.isKioskModeActive && kioskManager.settings.secretExitGestureEnabled {
                cornerTapArea
            }
        }
    }

    @ViewBuilder
    private var cornerTapArea: some View {
        let corner = kioskManager.settings.secretExitGestureCorner
        let requiredTaps = kioskManager.settings.secretExitGestureTaps
        let alignment = alignmentForCorner(corner)

        // Use a frame with alignment to position the tap area in the corner
        // The tap area is the only thing that receives touches
        VStack {
            if corner == .bottomLeft || corner == .bottomRight {
                Spacer(minLength: 0)
            }
            HStack {
                if corner == .topRight || corner == .bottomRight {
                    Spacer(minLength: 0)
                }
                SecretTapArea(requiredTaps: requiredTaps) {
                    showSettings = true
                }
                .frame(width: cornerTapSize, height: cornerTapSize)
                if corner == .topLeft || corner == .bottomLeft {
                    Spacer(minLength: 0)
                }
            }
            if corner == .topLeft || corner == .topRight {
                Spacer(minLength: 0)
            }
        }
        .allowsHitTesting(true)
    }

    private func alignmentForCorner(_ corner: ScreenCorner) -> Alignment {
        switch corner {
        case .topLeft: return .topLeading
        case .topRight: return .topTrailing
        case .bottomLeft: return .bottomLeading
        case .bottomRight: return .bottomTrailing
        }
    }
}

// MARK: - Secret Tap Area

/// A view that detects multiple rapid taps and triggers an action
private struct SecretTapArea: View {
    let requiredTaps: Int
    let onTriggered: () -> Void

    @State private var tapCount = 0
    @State private var resetTimer: Timer?

    /// Time window for completing all taps (seconds)
    private let tapWindow: TimeInterval = 2.0

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture {
                handleTap()
            }
    }

    private func handleTap() {
        // Cancel existing timer
        resetTimer?.invalidate()

        tapCount += 1

        if tapCount >= requiredTaps {
            // Success - trigger action
            tapCount = 0
            resetTimer = nil

            // Provide haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()

            onTriggered()
        } else {
            // Provide subtle feedback for each tap
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()

            // Reset tap count if no more taps within window
            resetTimer = Timer.scheduledTimer(withTimeInterval: tapWindow, repeats: false) { _ in
                tapCount = 0
            }
        }
    }
}

// MARK: - UIKit Integration

/// A passthrough view that only intercepts touches in corner regions
private class CornerTapPassthroughView: UIView {
    /// Size of the corner tap region
    var cornerSize: CGFloat = 80
    /// Which corner is active
    var activeCorner: ScreenCorner = .topLeft
    /// Whether the gesture is enabled
    var isGestureEnabled: Bool = true

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // If gesture is disabled, pass through everything
        guard isGestureEnabled else { return nil }

        // Check if the point is in the active corner
        let cornerRect = rectForCorner(activeCorner)
        if cornerRect.contains(point) {
            // Let the subview (SwiftUI) handle this tap
            return super.hitTest(point, with: event)
        }

        // Pass through touches outside the corner
        return nil
    }

    private func rectForCorner(_ corner: ScreenCorner) -> CGRect {
        switch corner {
        case .topLeft:
            return CGRect(x: 0, y: 0, width: cornerSize, height: cornerSize)
        case .topRight:
            return CGRect(x: bounds.width - cornerSize, y: 0, width: cornerSize, height: cornerSize)
        case .bottomLeft:
            return CGRect(x: 0, y: bounds.height - cornerSize, width: cornerSize, height: cornerSize)
        case .bottomRight:
            return CGRect(x: bounds.width - cornerSize, y: bounds.height - cornerSize, width: cornerSize, height: cornerSize)
        }
    }
}

/// A UIView wrapper for the secret exit gesture that can be added to UIKit view controllers
public class SecretExitGestureViewController: UIViewController {
    private var hostingController: UIHostingController<SecretExitGestureWrapper>?
    private var cancellables = Set<AnyCancellable>()
    private var passthroughView: CornerTapPassthroughView?

    /// Callback when settings should be shown
    public var onShowSettings: (() -> Void)?

    public override func loadView() {
        let passthrough = CornerTapPassthroughView()
        passthrough.backgroundColor = .clear
        self.view = passthrough
        self.passthroughView = passthrough
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupGestureView()
        setupSettingsObserver()
    }

    private func setupGestureView() {
        let wrapper = SecretExitGestureWrapper { [weak self] in
            self?.onShowSettings?()
        }

        let hosting = UIHostingController(rootView: wrapper)
        hosting.view.backgroundColor = .clear

        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        hosting.didMove(toParent: self)
        hostingController = hosting

        // Initial settings sync
        updatePassthroughSettings()
    }

    private func setupSettingsObserver() {
        // Observe kiosk settings changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: KioskModeManager.settingsDidChangeNotification,
            object: nil
        )

        // Also observe kiosk mode state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: KioskModeManager.kioskModeDidChangeNotification,
            object: nil
        )
    }

    @objc private func settingsDidChange() {
        updatePassthroughSettings()
    }

    private func updatePassthroughSettings() {
        let settings = KioskModeManager.shared.settings
        passthroughView?.isGestureEnabled = settings.secretExitGestureEnabled && KioskModeManager.shared.isKioskModeActive
        passthroughView?.activeCorner = settings.secretExitGestureCorner
        passthroughView?.cornerSize = 80
    }
}

/// Internal wrapper that converts the binding-based API to a closure-based one
private struct SecretExitGestureWrapper: View {
    let onShowSettings: () -> Void
    @State private var showSettings = false

    var body: some View {
        SecretExitGestureView(showSettings: $showSettings)
            .onChange(of: showSettings) { newValue in
                if newValue {
                    showSettings = false
                    onShowSettings()
                }
            }
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview {
    ZStack {
        Color.blue.opacity(0.3)
        Text("Tap top-left corner 3 times")

        SecretExitGestureView(showSettings: .constant(false))
    }
}
