import CoreGraphics
import Foundation
import Shared

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
    }

    // MARK: - UI Dimensions

    public enum UI {
        /// Standard corner radius (uses DesignSystem)
        public static let cornerRadius: CGFloat = DesignSystem.CornerRadius.oneAndHalf
        /// Small corner radius (uses DesignSystem)
        public static let smallCornerRadius: CGFloat = DesignSystem.CornerRadius.one
        /// Large clock font size
        public static let largeClockFontSize: CGFloat = 120
        /// Minimal clock font size
        public static let minimalClockFontSize: CGFloat = 80
        /// Digital clock font size
        public static let digitalClockFontSize: CGFloat = 100
        /// Analog clock size
        public static let analogClockSize: CGFloat = 300
    }
}
