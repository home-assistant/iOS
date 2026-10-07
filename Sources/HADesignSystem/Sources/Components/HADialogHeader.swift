#if !os(watchOS)
import SwiftUI

/// A dialog's top bar: a close button, a title with an optional subtitle, and room for an action on
/// the trailing edge. The SwiftUI counterpart of the frontend's `ha-dialog-header`.
///
/// For a sheet presented the platform way, `.navigationTitle` and a toolbar do this. Use this where
/// the app draws its own dialog chrome, which is why the frontend has the element at all.
public struct HADialogHeader<Actions: View>: View {
    private let title: String
    private let subtitle: String?
    private let onClose: (() -> Void)?
    private let actions: Actions

    public init(
        title: String,
        subtitle: String? = nil,
        onClose: (() -> Void)? = nil,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.subtitle = subtitle
        self.onClose = onClose
        self.actions = actions()
    }

    public var body: some View {
        HStack(alignment: .center, spacing: DesignSystem.Spaces.one) {
            if let onClose {
                CloseButton(size: .medium, alternativeAction: onClose)
            }
            VStack(alignment: .leading, spacing: .zero) {
                Text(title)
                    .font(DesignSystem.Font.headline)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: DesignSystem.Spaces.one)
            actions
        }
        .padding(.horizontal, DesignSystem.Spaces.two)
        .frame(minHeight: 56)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.haDivider)
                .frame(height: DesignSystem.Border.Width.default)
        }
    }
}

public extension HADialogHeader where Actions == EmptyView {
    /// A header with nothing on its trailing edge.
    init(title: String, subtitle: String? = nil, onClose: (() -> Void)? = nil) {
        self.init(title: title, subtitle: subtitle, onClose: onClose) { EmptyView() }
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.three) {
        HADialogHeader(title: "Settings", onClose: {})
        HADialogHeader(title: "Ceiling light", subtitle: "Living room", onClose: {})
        HADialogHeader(title: "With an action", onClose: {}) {
            Button("Save") {}
                .buttonStyle(.textButton)
        }
        HADialogHeader(title: "No close button")
    }
    .padding(.vertical)
}

extension HADialogHeader: FrontendComponent {
    public static var frontendComponentName: String { "ha-dialog-header" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
