#if !os(watchOS)
import SwiftUI

/// The column every more-info dialog is laid out in: a header, the main controls centred under it,
/// and whatever sits at the bottom, usually the mode pickers.
///
/// Frontend counterpart: `more-info-control-style.ts`, the stylesheet the more-info controls share
/// for exactly this arrangement.
public struct HAMoreInfoLayout<Header: View, Controls: View, Footer: View>: View {
    private let header: Header
    private let controls: Controls
    private let footer: Footer

    public init(
        @ViewBuilder header: () -> Header,
        @ViewBuilder controls: () -> Controls,
        @ViewBuilder footer: () -> Footer
    ) {
        self.header = header()
        self.controls = controls()
        self.footer = footer()
    }

    public var body: some View {
        VStack(spacing: .zero) {
            header
            VStack(spacing: DesignSystem.Spaces.three) {
                controls
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, DesignSystem.Spaces.three)
            footer
        }
        .frame(maxWidth: .infinity)
    }
}

public extension HAMoreInfoLayout where Footer == EmptyView {
    init(@ViewBuilder header: () -> Header, @ViewBuilder controls: () -> Controls) {
        self.init(header: header, controls: controls) { EmptyView() }
    }
}

#Preview {
    HAMoreInfoLayout {
        HAMoreInfoStateHeader(state: "On", lastChanged: Date(timeIntervalSinceNow: -120), now: Date())
    } controls: {
        HAControlSwitch(
            isOn: .constant(true),
            vertical: true,
            reversed: true,
            thickness: DesignSystem.StateControl.thickness,
            cornerRadius: DesignSystem.StateControl.cornerRadius
        )
        .frame(height: DesignSystem.StateControl.length)
    }
    .padding()
}

extension HAMoreInfoLayout: FrontendComponent {
    public static var frontendComponentName: String { "more-info-control-style" }
    public static var frontendComponentVersion: String { "2026-10-12" }
}

#endif
