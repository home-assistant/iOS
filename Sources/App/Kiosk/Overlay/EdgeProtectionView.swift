import Shared
import SwiftUI
import UIKit

// MARK: - Edge Protection View

/// An overlay that blocks accidental touches near screen edges
public struct EdgeProtectionView: View {
    @ObservedObject private var manager = KioskModeManager.shared

    @State private var blockedTouch: CGPoint?
    @State private var showBlockedIndicator = false

    public init() {}

    private var isEnabled: Bool {
        manager.isKioskModeActive && manager.settings.edgeProtection
    }

    private var inset: CGFloat {
        manager.settings.edgeProtectionInset
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Edge protection zones (invisible hit areas)
                if isEnabled {
                    edgeProtectionOverlay(in: geometry)
                }

                // Blocked touch indicator
                if showBlockedIndicator, let point = blockedTouch {
                    blockedTouchIndicator
                        .position(point)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .animation(.easeOut(duration: KioskConstants.Animation.quick), value: showBlockedIndicator)
    }

    // MARK: - Edge Protection Overlay

    @ViewBuilder
    private func edgeProtectionOverlay(in geometry: GeometryProxy) -> some View {
        // Top edge
        Rectangle()
            .fill(Color.clear)
            .frame(height: inset)
            .frame(maxWidth: .infinity)
            .position(x: geometry.size.width / 2, y: inset / 2)
            .contentShape(Rectangle())
            .onTapGesture {
                handleBlockedTouch(at: CGPoint(x: geometry.size.width / 2, y: inset / 2))
            }

        // Bottom edge
        Rectangle()
            .fill(Color.clear)
            .frame(height: inset)
            .frame(maxWidth: .infinity)
            .position(x: geometry.size.width / 2, y: geometry.size.height - inset / 2)
            .contentShape(Rectangle())
            .onTapGesture {
                handleBlockedTouch(at: CGPoint(x: geometry.size.width / 2, y: geometry.size.height - inset / 2))
            }

        // Left edge
        Rectangle()
            .fill(Color.clear)
            .frame(width: inset)
            .frame(maxHeight: .infinity)
            .position(x: inset / 2, y: geometry.size.height / 2)
            .contentShape(Rectangle())
            .onTapGesture {
                handleBlockedTouch(at: CGPoint(x: inset / 2, y: geometry.size.height / 2))
            }

        // Right edge
        Rectangle()
            .fill(Color.clear)
            .frame(width: inset)
            .frame(maxHeight: .infinity)
            .position(x: geometry.size.width - inset / 2, y: geometry.size.height / 2)
            .contentShape(Rectangle())
            .onTapGesture {
                handleBlockedTouch(at: CGPoint(x: geometry.size.width - inset / 2, y: geometry.size.height / 2))
            }
    }

    // MARK: - Blocked Touch Indicator

    private var blockedTouchIndicator: some View {
        Circle()
            .fill(Color.red.opacity(0.3))
            .frame(width: 44, height: 44)
            .overlay(
                Image(systemName: "hand.raised.slash")
                    .foregroundColor(.red)
            )
    }

    // MARK: - Touch Handling

    private func handleBlockedTouch(at point: CGPoint) {
        blockedTouch = point
        showBlockedIndicator = true

        // Play warning feedback
        TouchFeedbackManager.shared.playFeedback(for: .warning)

        // Hide indicator after a short delay
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            await MainActor.run {
                withAnimation {
                    showBlockedIndicator = false
                }
            }
        }

        Current.Log.verbose("Edge protection blocked touch at: \(point)")
    }
}

// MARK: - Edge Protection UIKit View Controller

/// UIKit view controller for edge protection overlay
public final class EdgeProtectionViewController: UIViewController {
    private var hostingController: UIHostingController<EdgeProtectionView>?

    public override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true

        let edgeView = EdgeProtectionView()
        hostingController = UIHostingController(rootView: edgeView)
        hostingController?.view.backgroundColor = .clear

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
    }

}

// MARK: - Edge Protection Passthrough View

/// Custom view that passes through touches in the safe zone
final class EdgeProtectionPassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let manager = KioskModeManager.shared

        // Only intercept if edge protection is enabled
        guard manager.isKioskModeActive && manager.settings.edgeProtection else {
            return nil
        }

        let inset = manager.settings.edgeProtectionInset

        // Check if touch is in edge zone
        if point.x < inset || point.x > bounds.width - inset ||
           point.y < inset || point.y > bounds.height - inset {
            // Return self to capture the touch
            return self
        }

        // Pass through touches in the safe zone
        return nil
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview {
    ZStack {
        Color.blue.opacity(0.3)
            .ignoresSafeArea()

        Text("Content Area")

        EdgeProtectionView()
    }
}
