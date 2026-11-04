import SwiftUI

/// The resolved, target-agnostic rendering inputs for the inline complication.
///
/// Inline is a single line of text with no icon or custom colors — watchOS renders it in the face's
/// tint. Both the on-watch `WatchWidgetComplicationSnapshot` and the in-app editor's
/// `ComplicationRenderContext` resolve the whole line into `text`, so `InlineComplicationContentView`
/// renders identically in the real complication and the preview.
public struct InlineComplicationRenderModel {
    /// The whole resolved line (e.g. the title slot's "{name} - {value}" formula).
    public var text: String

    public init(text: String = "") {
        self.text = text
    }
}
