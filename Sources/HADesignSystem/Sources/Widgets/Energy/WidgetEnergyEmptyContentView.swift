#if !os(watchOS)
import SFSafeSymbols
import SwiftUI

/// The home screen Energy card when the widget can't read anything at all: no server URL to reach,
/// no energy dashboard, or a load that failed.
@available(iOS 17, *)
public struct WidgetEnergyEmptyContentView: View {
    /// Wraps a rendered label in the control that runs it.
    public typealias ControlContent = (AnyView) -> AnyView

    private let message: String
    /// The retry control, when retrying could help. A missing energy dashboard is the one empty
    /// state a reload can't fix, so it doesn't offer one.
    private let retryControl: ControlContent?

    public init(message: String, retryControl: ControlContent? = nil) {
        self.message = message
        self.retryControl = retryControl
    }

    public var body: some View {
        VStack(spacing: DesignSystem.Spaces.one) {
            Text(verbatim: message)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
                .foregroundStyle(WidgetEnergyPalette.secondaryText)
            if let retryControl {
                retryControl(AnyView(
                    Image(systemSymbol: .arrowClockwiseCircle)
                        .foregroundStyle(.secondary)
                        .font(DesignSystem.Font.title)
                ))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetBackground(WidgetEnergyPalette.background)
    }
}

@available(iOS 17, *)
#Preview {
    WidgetEnergyEmptyContentView(message: "No energy data", retryControl: { $0 })
        .frame(width: 158, height: 158)
}
#endif
