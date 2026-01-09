import Combine
import Shared
import SwiftUI
import UIKit

// MARK: - Status Overlay View

/// A floating overlay bar showing connection status, time, battery, and HA entities
public struct StatusOverlayView: View {
    @ObservedObject private var manager = KioskModeManager.shared
    @State private var isVisible = true
    @State private var hideTimer: Timer?
    @State private var batteryLevel: Float = 0
    @State private var batteryState: UIDevice.BatteryState = .unknown
    @State private var currentTime = Date()

    private let timeTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    public init() {}

    public var body: some View {
        if shouldShow {
            overlayContent
                .transition(.opacity.combined(with: .move(edge: position == .top ? .top : .bottom)))
                .animation(.easeInOut(duration: 0.3), value: isVisible)
                .onAppear {
                    UIDevice.current.isBatteryMonitoringEnabled = true
                }
                .onDisappear {
                    hideTimer?.invalidate()
                    hideTimer = nil
                    UIDevice.current.isBatteryMonitoringEnabled = false
                }
        }
    }

    private var shouldShow: Bool {
        manager.isKioskModeActive &&
        manager.settings.statusOverlayEnabled &&
        isVisible
    }

    private var position: OverlayPosition {
        manager.settings.statusOverlayPosition
    }

    @ViewBuilder
    private var overlayContent: some View {
        HStack(spacing: 12) {
            // Connection Status
            if manager.settings.showConnectionStatus {
                connectionStatusView
            }

            Spacer()

            // Time
            if manager.settings.showTime {
                timeView
            }

            // Battery
            if manager.settings.showBattery {
                batteryView
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(overlayBackground)
        .onAppear {
            updateBattery()
            startAutoHideTimerIfNeeded()
        }
        .onReceive(timeTimer) { _ in
            currentTime = Date()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)) { _ in
            updateBattery()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification)) { _ in
            updateBattery()
        }
    }

    private var overlayBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.ultraThinMaterial)
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }

    // MARK: - Connection Status

    @ViewBuilder
    private var connectionStatusView: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(connectionColor)
                .frame(width: 8, height: 8)

            Text(connectionText)
                .font(.caption)
                .foregroundColor(.primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(KioskConstants.Accessibility.connectionStatus)
        .accessibilityValue(connectionText)
    }

    private var connectionColor: Color {
        manager.isConnectedToHA ? .green : .red
    }

    private var connectionText: String {
        manager.isConnectedToHA ? "Connected" : "Disconnected"
    }

    // MARK: - Time View

    @ViewBuilder
    private var timeView: some View {
        Text(timeString)
            .font(.caption.monospacedDigit())
            .foregroundColor(.primary)
            .accessibilityLabel(KioskConstants.Accessibility.timeDisplay)
            .accessibilityValue(timeString)
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: currentTime)
    }

    // MARK: - Battery View

    @ViewBuilder
    private var batteryView: some View {
        HStack(spacing: 4) {
            Image(systemName: batteryIcon)
                .foregroundColor(batteryColor)

            Text("\(Int(batteryLevel * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundColor(.primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(KioskConstants.Accessibility.batteryStatus)
        .accessibilityValue("\(Int(batteryLevel * 100)) percent\(batteryState == .charging ? ", charging" : "")")
    }

    private var batteryIcon: String {
        switch batteryState {
        case .charging, .full:
            return "battery.100.bolt"
        case .unplugged:
            if batteryLevel > 0.75 {
                return "battery.100"
            } else if batteryLevel > 0.50 {
                return "battery.75"
            } else if batteryLevel > 0.25 {
                return "battery.50"
            } else {
                return "battery.25"
            }
        case .unknown:
            return "battery.0"
        @unknown default:
            return "battery.0"
        }
    }

    private var batteryColor: Color {
        if batteryState == .charging || batteryState == .full {
            return .green
        } else if batteryLevel <= 0.20 {
            return .red
        } else {
            return .primary
        }
    }

    private func updateBattery() {
        batteryLevel = UIDevice.current.batteryLevel
        batteryState = UIDevice.current.batteryState
    }

    // MARK: - Auto-Hide Timer

    private func startAutoHideTimerIfNeeded() {
        guard manager.settings.statusOverlayAutoHide > 0 else { return }
        resetAutoHideTimer()
    }

    private func resetAutoHideTimer() {
        hideTimer?.invalidate()

        let timeout = manager.settings.statusOverlayAutoHide
        guard timeout > 0 else {
            isVisible = true
            return
        }

        isVisible = true

        hideTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
            withAnimation {
                isVisible = false
            }
        }
    }
}

// MARK: - Status Overlay Container View

/// A container view that positions the status overlay at the top or bottom
public struct StatusOverlayContainerView: View {
    @ObservedObject private var manager = KioskModeManager.shared

    public init() {}

    public var body: some View {
        GeometryReader { geometry in
            VStack {
                if manager.settings.statusOverlayPosition == .top {
                    StatusOverlayView()
                        .padding(.top, geometry.safeAreaInsets.top + 8)
                        .padding(.horizontal, 16)
                    Spacer()
                } else {
                    Spacer()
                    StatusOverlayView()
                        .padding(.bottom, geometry.safeAreaInsets.bottom + 8)
                        .padding(.horizontal, 16)
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
        .allowsHitTesting(false)
    }
}

// MARK: - UIKit Hosting Controller

/// A UIViewController that hosts the status overlay
public final class StatusOverlayViewController: UIViewController {
    private var hostingController: UIHostingController<StatusOverlayContainerView>?
    private var cancellables = Set<AnyCancellable>()

    public override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear
        // Don't intercept touches - let them pass through to web view
        view.isUserInteractionEnabled = false

        let overlayView = StatusOverlayContainerView()
        hostingController = UIHostingController(rootView: overlayView)
        hostingController?.view.backgroundColor = .clear
        hostingController?.view.isUserInteractionEnabled = false

        guard let hostingController, let hostingView = hostingController.view else { return }

        addChild(hostingController)
        view.addSubview(hostingView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: view.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        hostingController.didMove(toParent: self)

        // Listen for kiosk mode changes
        setupObservers()
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateVisibility),
            name: KioskModeManager.kioskModeDidChangeNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateVisibility),
            name: KioskModeManager.settingsDidChangeNotification,
            object: nil
        )

        // Initial visibility
        updateVisibility()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func updateVisibility() {
        let manager = KioskModeManager.shared
        let shouldShow = manager.isKioskModeActive && manager.settings.statusOverlayEnabled

        UIView.animate(withDuration: 0.3) {
            self.view.alpha = shouldShow ? 1 : 0
        }
    }

}

// MARK: - Status Overlay Passthrough View

/// Custom view that passes through touches outside of content
final class StatusOverlayPassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Only intercept touches on the actual overlay content
        let hitView = super.hitTest(point, with: event)

        // Pass through touches that don't hit our content
        if hitView === self {
            return nil
        }

        return hitView
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview {
    StatusOverlayContainerView()
}
