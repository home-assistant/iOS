import CoreGraphics
import Foundation

// MARK: - Kiosk Constants

/// Centralized constants for the kiosk mode
public enum KioskConstants {
    // MARK: - Animation Durations

    public enum Animation {
        /// Standard transition animation duration
        public static let standard: TimeInterval = 0.3
        /// Quick animation for subtle transitions
        public static let quick: TimeInterval = 0.2
        /// Slow animation for screensaver transitions
        public static let slow: TimeInterval = 0.5
        /// Pixel shift animation duration
        public static let pixelShift: TimeInterval = 1.0
        /// Spring animation response
        public static let springResponse: Double = 0.4
    }

    // MARK: - Timing Intervals

    public enum Timing {
        /// Motion detection cooldown period
        public static let motionCooldown: TimeInterval = 2.0
        /// Recently fired trigger display duration (nanoseconds)
        public static let recentlyFiredDuration: UInt64 = 3_000_000_000
        /// Network reconnect delay before refresh
        public static let networkReconnectDelay: TimeInterval = 2.0
        /// Panel dismiss delay before app launch
        public static let panelDismissDelay: TimeInterval = 0.2
        /// Feedback display duration
        public static let feedbackDuration: TimeInterval = 1.5
        /// Schedule check interval
        public static let scheduleCheckInterval: TimeInterval = 60
    }

    // MARK: - Motion Detection

    public enum Motion {
        /// Low sensitivity threshold
        public static let lowThreshold: Float = 0.05
        /// Medium sensitivity threshold
        public static let mediumThreshold: Float = 0.02
        /// High sensitivity threshold
        public static let highThreshold: Float = 0.008
        /// Frame rate for motion detection (fps)
        public static let frameRate: Int32 = 5
    }

    // MARK: - Audio Detection

    public enum Audio {
        /// Default loud audio threshold in dB
        public static let loudThresholdDB: Float = -20
        /// Default quiet threshold in dB
        public static let quietThresholdDB: Float = -50
        /// Sample interval for metering
        public static let sampleInterval: TimeInterval = 0.1
        /// Consecutive samples needed to confirm loud audio
        public static let loudSampleThreshold: Int = 3
    }

    // MARK: - Battery

    public enum Battery {
        /// Critical battery level (20%)
        public static let criticalLevel: Float = 0.20
        /// Low battery level (25%)
        public static let lowLevel: Float = 0.25
        /// Medium battery level (50%)
        public static let mediumLevel: Float = 0.50
        /// High battery level (75%)
        public static let highLevel: Float = 0.75
    }

    // MARK: - UI Dimensions

    public enum UI {
        /// Edge gesture detection size
        public static let edgeGestureSize: CGFloat = 30
        /// Swipe gesture threshold
        public static let swipeThreshold: CGFloat = 50
        /// Standard corner radius
        public static let cornerRadius: CGFloat = 12
        /// Small corner radius
        public static let smallCornerRadius: CGFloat = 8
        /// Standard padding
        public static let standardPadding: CGFloat = 16
        /// Small padding
        public static let smallPadding: CGFloat = 8
        /// Large clock font size
        public static let largeClockFontSize: CGFloat = 120
        /// Minimal clock font size
        public static let minimalClockFontSize: CGFloat = 80
        /// Digital clock font size
        public static let digitalClockFontSize: CGFloat = 100
        /// Analog clock size
        public static let analogClockSize: CGFloat = 300
        /// Header height
        public static let headerHeight: CGFloat = 60
        /// Icon size for app shortcuts
        public static let appIconSize: CGFloat = 50
        /// Camera pip size
        public static let cameraPipWidth: CGFloat = 300
        /// Camera pip height
        public static let cameraPipHeight: CGFloat = 225
    }

    // MARK: - Panel Sizes

    public enum Panel {
        /// Maximum panel width ratio
        public static let maxWidthRatio: CGFloat = 0.9
        /// Maximum panel width absolute
        public static let maxWidth: CGFloat = 400
        /// Maximum panel height ratio
        public static let maxHeightRatio: CGFloat = 0.6
        /// Maximum panel height absolute
        public static let maxHeight: CGFloat = 500
        /// Minimum shortcuts before showing search
        public static let searchThreshold: Int = 6
    }

    // MARK: - Shadows

    public enum Shadow {
        /// Standard shadow opacity
        public static let opacity: Double = 0.2
        /// Standard shadow radius
        public static let radius: CGFloat = 4
        /// Panel shadow opacity
        public static let panelOpacity: Double = 0.3
        /// Panel shadow radius
        public static let panelRadius: CGFloat = 10
    }

    // MARK: - Accessibility

    public enum Accessibility {
        /// Connection status label
        public static let connectionStatus = "Connection Status"
        /// Connected hint
        public static let connectedHint = "Connected to Home Assistant"
        /// Disconnected hint
        public static let disconnectedHint = "Disconnected from Home Assistant"
        /// Battery status label
        public static let batteryStatus = "Battery Status"
        /// Time display label
        public static let timeDisplay = "Current Time"
        /// Close button label
        public static let closeButton = "Close"
        /// Search field label
        public static let searchField = "Search apps"
        /// App shortcut label format
        public static func appShortcut(_ name: String) -> String {
            "Launch \(name)"
        }
    }
}
