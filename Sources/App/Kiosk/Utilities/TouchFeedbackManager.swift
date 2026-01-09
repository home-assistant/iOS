import AudioToolbox
import AVFoundation
import Shared
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

    // MARK: - Private Properties

    private var settings: KioskSettings { KioskModeManager.shared.settings }

    // Haptic generators (lazy initialized for performance)
    private lazy var lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    private lazy var mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private lazy var heavyImpactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private lazy var selectionGenerator = UISelectionFeedbackGenerator()
    private lazy var notificationGenerator = UINotificationFeedbackGenerator()

    // Sound player
    private var audioPlayer: AVAudioPlayer?

    // MARK: - Initialization

    private init() {
        prepareGenerators()
    }

    // MARK: - Public Methods

    /// Play feedback for a given type
    public func playFeedback(for type: FeedbackType) {
        if settings.touchHapticEnabled {
            playHaptic(for: type)
        }

        if settings.touchSoundEnabled {
            playSound(for: type)
        }
    }

    /// Play haptic feedback only
    public func playHaptic(for type: FeedbackType) {
        guard settings.touchHapticEnabled else { return }

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
        guard settings.touchSoundEnabled else { return }

        let soundID: SystemSoundID

        switch type {
        case .tap:
            soundID = 1104 // Tock
        case .selection:
            soundID = 1105 // Tink
        case .action:
            soundID = 1306 // Key pressed
        case .success:
            soundID = 1025 // Payment success (Bloom)
        case .warning:
            soundID = 1255 // Tone
        case .error:
            soundID = 1257 // Negative tone
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

import SwiftUI

extension View {
    /// Add touch feedback to a view
    public func touchFeedback(_ type: TouchFeedbackManager.FeedbackType = .tap) -> some View {
        modifier(TouchFeedbackModifier(feedbackType: type))
    }
}

// MARK: - UIKit Integration

extension TouchFeedbackManager {
    /// Add touch feedback to a UIButton
    public func addFeedback(to button: UIButton, type: FeedbackType = .tap) {
        button.addTarget(self, action: #selector(handleButtonTouch), for: .touchUpInside)
        // Store the feedback type as associated object
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

private var feedbackTypeKey: UInt8 = 0
