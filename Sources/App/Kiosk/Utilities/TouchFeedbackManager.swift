import AudioToolbox
import AVFoundation
import ObjectiveC
import UIKit

// MARK: - Touch Feedback Manager

/// Manages haptic and sound feedback for touch interactions
@MainActor
public final class TouchFeedbackManager {
    // MARK: - Singleton

    public static let shared = TouchFeedbackManager()

    // MARK: - Feedback Types

    public enum FeedbackType {
        /// Light tap feedback (button taps)
        case tap
        /// Medium impact feedback (selections, toggles)
        case selection
        /// Heavy impact feedback (important actions)
        case action
        /// Success feedback (completed actions)
        case success
        /// Warning feedback (alerts, confirmations)
        case warning
        /// Error feedback (failures)
        case error
    }

    // MARK: - Configuration

    /// Whether haptic feedback is enabled
    public var isHapticEnabled: Bool = true

    /// Whether sound feedback is enabled
    public var isSoundEnabled: Bool = false

    // Haptic generators (lazy initialized for performance)
    private lazy var lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    private lazy var mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private lazy var heavyImpactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private lazy var selectionGenerator = UISelectionFeedbackGenerator()
    private lazy var notificationGenerator = UINotificationFeedbackGenerator()

    // MARK: - System Sound IDs

    // These are documented system sounds available on iOS

    private enum SystemSound {
        /// Light tock sound
        static let tock: SystemSoundID = 1104
        /// Light tink sound
        static let tink: SystemSoundID = 1105
        /// Key press sound
        static let keyPressed: SystemSoundID = 1306
        /// Success/payment sound (Bloom)
        static let success: SystemSoundID = 1025
        /// Neutral tone
        static let tone: SystemSoundID = 1255
        /// Negative tone
        static let negativeTone: SystemSoundID = 1257
    }

    // MARK: - Initialization

    private init() {
        prepareGenerators()
    }

    // MARK: - Configuration from KioskSettings

    /// Update configuration from kiosk settings
    public func configure(from settings: KioskSettings) {
        isHapticEnabled = settings.touchHapticEnabled
        isSoundEnabled = settings.touchSoundEnabled
    }

    // MARK: - Public Methods

    /// Play feedback for a given type
    public func playFeedback(for type: FeedbackType) {
        if isHapticEnabled {
            playHaptic(for: type)
        }

        if isSoundEnabled {
            playSound(for: type)
        }
    }

    /// Play haptic feedback only
    public func playHaptic(for type: FeedbackType) {
        guard isHapticEnabled else { return }

        switch type {
        case .tap:
            lightImpactGenerator.impactOccurred()

        case .selection:
            selectionGenerator.selectionChanged()

        case .action:
            mediumImpactGenerator.impactOccurred()

        case .success:
            notificationGenerator.notificationOccurred(.success)

        case .warning:
            notificationGenerator.notificationOccurred(.warning)

        case .error:
            notificationGenerator.notificationOccurred(.error)
        }
    }

    /// Play sound feedback only
    public func playSound(for type: FeedbackType) {
        guard isSoundEnabled else { return }

        let soundID: SystemSoundID

        switch type {
        case .tap:
            soundID = SystemSound.tock
        case .selection:
            soundID = SystemSound.tink
        case .action:
            soundID = SystemSound.keyPressed
        case .success:
            soundID = SystemSound.success
        case .warning:
            soundID = SystemSound.tone
        case .error:
            soundID = SystemSound.negativeTone
        }

        AudioServicesPlaySystemSound(soundID)
    }

    /// Prepare haptic generators for responsiveness
    public func prepareGenerators() {
        lightImpactGenerator.prepare()
        mediumImpactGenerator.prepare()
        heavyImpactGenerator.prepare()
        selectionGenerator.prepare()
        notificationGenerator.prepare()
    }

    // MARK: - Convenience Methods

    /// Play tap feedback (for button touches)
    public func tap() {
        playFeedback(for: .tap)
    }

    /// Play selection feedback (for toggles, selections)
    public func selection() {
        playFeedback(for: .selection)
    }

    /// Play action feedback (for executing commands)
    public func action() {
        playFeedback(for: .action)
    }

    /// Play success feedback
    public func success() {
        playFeedback(for: .success)
    }

    /// Play warning feedback
    public func warning() {
        playFeedback(for: .warning)
    }

    /// Play error feedback
    public func error() {
        playFeedback(for: .error)
    }
}

// MARK: - SwiftUI View Modifier

import SwiftUI

/// View modifier that adds touch feedback to any view
public struct TouchFeedbackModifier: ViewModifier {
    let feedbackType: TouchFeedbackManager.FeedbackType

    public func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                TapGesture()
                    .onEnded { _ in
                        TouchFeedbackManager.shared.playFeedback(for: feedbackType)
                    }
            )
    }
}

// MARK: - View Extension

public extension View {
    /// Add touch feedback to a view
    func touchFeedback(_ type: TouchFeedbackManager.FeedbackType = .tap) -> some View {
        modifier(TouchFeedbackModifier(feedbackType: type))
    }
}

// MARK: - UIKit Integration

private var feedbackTypeKey: UInt8 = 0

extension TouchFeedbackManager {
    /// Add touch feedback to a UIButton
    public func addFeedback(to button: UIButton, type: FeedbackType = .tap) {
        button.addTarget(self, action: #selector(handleButtonTouch), for: .touchUpInside)
        objc_setAssociatedObject(button, &feedbackTypeKey, type, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    @objc private func handleButtonTouch(_ sender: UIButton) {
        if let type = objc_getAssociatedObject(sender, &feedbackTypeKey) as? FeedbackType {
            playFeedback(for: type)
        } else {
            playFeedback(for: .tap)
        }
    }
}
