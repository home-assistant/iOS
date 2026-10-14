#if !os(watchOS)
import SwiftUI

/// The more-info dialog's chrome: a header with the close button, the area-and-device breadcrumb
/// over the entity's name and the dialog's actions, and the domain's content scrolling under it. The
/// SwiftUI counterpart of the frontend's `ha-more-info-dialog` with `ha-more-info-info`.
///
/// The content is any of the `HAMoreInfo*` domain views. What the header's actions do (history,
/// settings, the overflow menu) is the app's business, so they come in as a builder.
public struct HAMoreInfoDialog<Content: View, Actions: View, Footer: View>: View {
    @Environment(\.layoutDirection) private var layoutDirection
    private let title: String
    private let breadcrumb: [String]
    private let onClose: (() -> Void)?
    private let actions: Actions
    private let content: Content
    private let footer: Footer

    /// - Parameters:
    ///   - title: The entity's name.
    ///   - breadcrumb: Area, then device, shown over the title and joined by a pointer.
    ///   - actions: Trailing header buttons.
    ///   - footer: Under the content, edge to edge, where a domain without its own design shows
    ///     history and logbook.
    public init(
        title: String,
        breadcrumb: [String] = [],
        onClose: (() -> Void)? = nil,
        @ViewBuilder actions: () -> Actions,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.title = title
        self.breadcrumb = breadcrumb
        self.onClose = onClose
        self.actions = actions()
        self.content = content()
        self.footer = footer()
    }

    private var overline: String? {
        breadcrumb.isEmpty ? nil : breadcrumb.joined(separator: layoutDirection == .rightToLeft ? " ◂ " : " ▸ ")
    }

    public var body: some View {
        VStack(spacing: .zero) {
            HADialogHeader(title: title, overline: overline, onClose: onClose) {
                HStack(spacing: DesignSystem.Spaces.half) {
                    actions
                }
            }
            ScrollView {
                VStack(spacing: DesignSystem.Spaces.two) {
                    content
                        .padding(DesignSystem.Spaces.three)
                    footer
                }
            }
        }
        .background(Color.haCardBackground)
    }
}

public extension HAMoreInfoDialog where Footer == EmptyView {
    init(
        title: String,
        breadcrumb: [String] = [],
        onClose: (() -> Void)? = nil,
        @ViewBuilder actions: () -> Actions,
        @ViewBuilder content: () -> Content
    ) {
        self.init(title: title, breadcrumb: breadcrumb, onClose: onClose, actions: actions, content: content) {
            EmptyView()
        }
    }
}

#Preview {
    HAMoreInfoDialog(title: "Ceiling light", breadcrumb: ["Living room", "Hue bridge"], onClose: {}) {
        Button {} label: {
            MaterialDesignIconsImage(icon: .chartBoxOutlineIcon, size: 24)
        }
        Button {} label: {
            MaterialDesignIconsImage(icon: .cogOutlineIcon, size: 24)
        }
        Button {} label: {
            MaterialDesignIconsImage(icon: .dotsVerticalIcon, size: 24)
        }
    } content: {
        HAMoreInfoLight(
            state: "78%",
            lastChanged: Date(timeIntervalSinceNow: -540),
            now: Date(),
            isOn: .constant(true),
            color: FrontendColors.stateLightActiveColor.color,
            brightness: .constant(78)
        )
    }
    .buttonStyle(.plain)
}

extension HAMoreInfoDialog: FrontendComponent {
    public static var frontendComponentName: String { "ha-more-info-dialog" }
    public static var frontendComponentVersion: String { "2026-10-12" }
}

#endif
