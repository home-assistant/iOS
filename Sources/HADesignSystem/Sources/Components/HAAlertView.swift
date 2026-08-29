#if !os(watchOS)
import HAIconic
import SwiftUI

/// An inline alert: a tinted strip carrying an icon, an optional bold title, a message and an
/// optional trailing action. The SwiftUI counterpart of the frontend's `ha-alert`.
///
/// The four severities come from ``HAAlertType``, which supplies the icon and the colour. The strip
/// is that colour at 12% — the frontend paints the same wash with an `::after` overlay.
public struct HAAlertView<Content: View, Action: View>: View {
    private let title: String?
    private let alertType: HAAlertType
    private let narrow: Bool
    private let icon: MaterialDesignIcons?
    private let onDismiss: (() -> Void)?
    private let content: Content
    private let action: Action

    /// - Parameters:
    ///   - title: Shown in bold above the message. Without one the icon centres on the message,
    ///     matching `ha-alert`'s `.icon.no-title`.
    ///   - icon: Overrides the icon ``HAAlertType`` would supply, for `ha-alert`'s `icon` slot.
    ///   - narrow: Stacks the action under the message instead of beside it, for tight columns.
    ///   - onDismiss: Adds a close button. The frontend fires `alert-dismissed-clicked` and leaves
    ///     removing the alert to the caller; so does this.
    ///   - action: A custom trailing control, for `ha-alert`'s `action` slot. Drawn before the
    ///     close button, so an alert normally has one or the other.
    public init(
        title: String? = nil,
        alertType: HAAlertType = .info,
        narrow: Bool = false,
        icon: MaterialDesignIcons? = nil,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder action: () -> Action
    ) {
        self.title = title
        self.alertType = alertType
        self.narrow = narrow
        self.icon = icon
        self.onDismiss = onDismiss
        self.content = content()
        self.action = action()
    }

    /// `.content` in the frontend: message and action side by side, or stacked with the action
    /// pushed to the trailing edge when `narrow` is set.
    private var messageAndActionLayout: AnyLayout {
        narrow
            ? AnyLayout(VStackLayout(alignment: .trailing, spacing: DesignSystem.Spaces.one))
            : AnyLayout(HStackLayout(alignment: .center, spacing: DesignSystem.Spaces.one))
    }

    public var body: some View {
        HStack(alignment: title == nil ? .center : .top, spacing: DesignSystem.Spaces.one) {
            MaterialDesignIconsImage(icon: icon ?? alertType.icon, size: 24)
                .foregroundStyle(alertType.color)
            messageAndActionLayout {
                VStack(alignment: .leading, spacing: DesignSystem.Spaces.micro) {
                    if let title {
                        Text(title)
                            .font(DesignSystem.Font.body.bold())
                    }
                    content
                        .font(DesignSystem.Font.body)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: DesignSystem.Spaces.one) {
                    action
                    if let onDismiss {
                        // The frontend's `ha-icon-button` with `mdiClose`, not the package's
                        // `CloseButton` — that one is built for modals and renders as a labelled
                        // system close button, which is too heavy to sit inside a strip of text.
                        Button(action: onDismiss) {
                            MaterialDesignIconsImage(icon: .closeIcon, size: 20)
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(HADesignSystemEnvironment.current.strings.dismissAlert))
                    }
                }
            }
        }
        .padding(DesignSystem.Spaces.one)
        .background(alertType.color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.half))
        .accessibilityElement(children: .contain)
    }
}

public extension HAAlertView where Action == EmptyView {
    /// An alert with no custom trailing control.
    init(
        title: String? = nil,
        alertType: HAAlertType = .info,
        narrow: Bool = false,
        icon: MaterialDesignIcons? = nil,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title,
            alertType: alertType,
            narrow: narrow,
            icon: icon,
            onDismiss: onDismiss,
            content: content,
            action: { EmptyView() }
        )
    }
}

public extension HAAlertView where Content == Text, Action == EmptyView {
    /// An alert whose message is plain text — the common case.
    init(
        _ message: String,
        title: String? = nil,
        alertType: HAAlertType = .info,
        narrow: Bool = false,
        icon: MaterialDesignIcons? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.init(
            title: title,
            alertType: alertType,
            narrow: narrow,
            icon: icon,
            onDismiss: onDismiss,
            content: { Text(message) },
            action: { EmptyView() }
        )
    }
}

#Preview("Types") {
    VStack(spacing: DesignSystem.Spaces.one) {
        ForEach(HAAlertType.allCases) { type in
            HAAlertView("Something happened that you should know about.", alertType: type)
        }
    }
    .padding()
}

#Preview("Title, dismiss and action") {
    VStack(spacing: DesignSystem.Spaces.one) {
        HAAlertView("The connection dropped and was restored.", title: "Reconnected", alertType: .success)
        HAAlertView("Your token expires tomorrow.", alertType: .warning, onDismiss: {})
        HAAlertView(alertType: .error, content: {
            Text("The server refused the request.")
        }, action: {
            Button("Retry") {}
                .buttonStyle(.textButton)
        })
        HAAlertView(alertType: .info, narrow: true, content: {
            Text("Narrow puts the action on its own line.")
        }, action: {
            Button("Details") {}
                .buttonStyle(.textButton)
        })
    }
    .padding()
}

extension HAAlertView: FrontendComponent {
    public static var frontendComponentName: String { "ha-alert" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
