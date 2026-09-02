#if !os(watchOS)
import Foundation
import HAIconic
import SFSafeSymbols
import SwiftUI

/// The "are you sure?" a tile turns into before it runs something destructive enough to warrant
/// asking. Cancel on the leading edge, confirm on the trailing one, in whatever shape the tile's
/// ``WidgetTileSizeStyle`` leaves room for.
///
/// The two halves are handed back to the caller to wrap, because what a widget's controls actually
/// are — an App Intent button, a deep link — is the widget's business, not the design system's.
public struct WidgetTileConfirmationView: View {
    /// Wraps a rendered label in the control that runs it.
    public typealias ActionWrapper = (AnyView) -> AnyView

    private let title: String
    private let sizeStyle: WidgetTileSizeStyle
    /// Whether the confirm half is a button, which brings its own chrome. A link doesn't, so the
    /// checkmark has to draw the filled pill itself to match the one beside it.
    private let confirmIsButton: Bool
    private let cancel: ActionWrapper
    private let confirm: ActionWrapper

    private static let confirmationColor: Color = .haPrimary

    public init(
        title: String,
        sizeStyle: WidgetTileSizeStyle,
        confirmIsButton: Bool,
        cancel: @escaping ActionWrapper,
        confirm: @escaping ActionWrapper
    ) {
        self.title = title
        self.sizeStyle = sizeStyle
        self.confirmIsButton = confirmIsButton
        self.cancel = cancel
        self.confirm = confirm
    }

    public var body: some View {
        switch sizeStyle {
        case .compressed:
            compressedForm
        case .compact:
            condensedForm
        case .single, .expanded, .regular:
            defaultForm
        }
    }

    private var cancelImage: some View {
        Image(systemSymbol: .xmark)
    }

    @ViewBuilder
    private var confirmImage: some View {
        let checkmark = Image(systemSymbol: .checkmark)
        if confirmIsButton {
            checkmark
                .frame(maxWidth: .infinity)
        } else {
            checkmark
                .foregroundStyle(Self.confirmationColor)
                .frame(maxWidth: .infinity)
                // Mimic default widget button style
                .frame(height: 30)
                .background(sizeStyle == .compressed ? nil : Self.confirmationColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.twoAndHalf))
        }
    }

    private var titleText: some View {
        Text(verbatim: title)
            .font(.footnote.bold())
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var defaultForm: some View {
        VStack {
            titleText
            Spacer()
            HStack {
                cancel(AnyView(cancelImage.frame(maxWidth: .infinity)))
                    .tint(.red)
                Spacer()
                confirm(AnyView(confirmImage.frame(maxWidth: .infinity)))
                    .tint(Self.confirmationColor)
            }
        }
        .padding()
    }

    private var condensedForm: some View {
        VStack(spacing: .zero) {
            titleText
                .padding([.horizontal, .top], DesignSystem.Spaces.one)
            Spacer()
            HStack {
                cancel(AnyView(cancelImage.frame(maxWidth: .infinity)))
                    .tint(.red)
                confirm(AnyView(confirmImage.frame(maxWidth: .infinity)))
                    .tint(Self.confirmationColor)
            }
        }
    }

    private var compressedForm: some View {
        HStack(spacing: .zero) {
            cancel(AnyView(
                cancelImage
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundStyle(.red)
                    .padding(DesignSystem.Spaces.half)
                    .background(.red.opacity(0.2))
            ))
            .buttonStyle(.plain)
            confirm(AnyView(
                confirmImage
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundStyle(Self.confirmationColor)
                    .padding(DesignSystem.Spaces.half)
                    .background(Self.confirmationColor.opacity(0.2))
            ))
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    VStack {
        ForEach(Array(WidgetTileSizeStyle.allCases.enumerated()), id: \.offset) { _, style in
            WidgetTileConfirmationView(
                title: "Are you sure?",
                sizeStyle: style,
                confirmIsButton: true,
                cancel: { label in AnyView(Button(action: {}, label: { label })) },
                confirm: { label in AnyView(Button(action: {}, label: { label })) }
            )
            .frame(height: 80)
            .widgetTileCardStyle(
                sizeStyle: style,
                model: .init(id: "preview", title: "", icon: .abTestingIcon),
                tinted: false
            )
        }
    }
    .padding()
}
#endif
