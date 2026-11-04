import SwiftUI

/// The inline complication's on-face content: a single line of text. On the watch the system renders
/// this in the face's tint and there is no icon or custom color, so the shared view is just the line.
///
/// This is the single source of truth shared by the real watch complication (`InlineComplicationView`)
/// and the in-app editor preview (`InlineComplicationPreview`); both only build an
/// `InlineComplicationRenderModel`.
@available(iOS 16.0, watchOS 10.0, *)
public struct InlineComplicationContentView: View {
    public let model: InlineComplicationRenderModel

    public init(model: InlineComplicationRenderModel) {
        self.model = model
    }

    public var body: some View {
        Text(verbatim: model.text)
            .lineLimit(1)
    }
}

#if DEBUG
@available(iOS 16.0, watchOS 10.0, *)
public extension InlineComplicationRenderModel {
    /// Sample model for previews and snapshot tests.
    static func sample(text: String = "Battery - 68%") -> InlineComplicationRenderModel {
        InlineComplicationRenderModel(text: text)
    }
}

/// Renders on a dark rounded "watch face" so the default white text is legible, matching the watch's
/// black face.
@available(iOS 16.0, watchOS 10.0, *)
private func face(_ model: InlineComplicationRenderModel) -> some View {
    InlineComplicationContentView(model: model)
        .font(.system(size: 15))
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.black, in: .capsule)
        .environment(\.colorScheme, .dark)
}

@available(iOS 16.0, watchOS 10.0, *)
#Preview("Name + value") {
    face(.sample()).padding()
}

@available(iOS 16.0, watchOS 10.0, *)
#Preview("Long line") {
    face(.sample(text: "Basement Dehumidifier - 1234 L")).padding()
}
#endif
