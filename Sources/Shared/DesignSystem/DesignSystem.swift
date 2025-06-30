import Foundation
import SwiftUICore

public enum DesignSystem {
    // TODO: Use HA design system font sizes when ready
    public enum Font {
        /// Large Title (34pt)
        public static let largeTitle: SwiftUICore.Font = .largeTitle
        /// Title (28pt)
        public static let title: SwiftUICore.Font = .title
        /// Title2 (22pt)
        public static let title2: SwiftUICore.Font = .title2
        /// Title3 (20pt)
        public static let title3: SwiftUICore.Font = .title3
        /// Headline (17pt, semibold)
        public static let headline: SwiftUICore.Font = .headline
        /// Subheadline (15pt)
        public static let subheadline: SwiftUICore.Font = .subheadline
        /// Body (17pt)
        public static let body: SwiftUICore.Font = .body
        /// Callout (16pt)
        public static let callout: SwiftUICore.Font = .callout
        /// Footnote (13pt)
        public static let footnote: SwiftUICore.Font = .footnote
        /// Caption (12pt)
        public static let caption: SwiftUICore.Font = .caption
        /// Caption2 (11pt)
        public static let caption2: SwiftUICore.Font = .caption2
    }

    public enum Spaces {
        public static let half: CGFloat = 4
        public static let one: CGFloat = 8
        public static let oneAndHalf: CGFloat = 12
        public static let two: CGFloat = 16
        public static let three: CGFloat = 24
        public static let four: CGFloat = 32
        public static let five: CGFloat = 40
        public static let six: CGFloat = 48
    }
}
