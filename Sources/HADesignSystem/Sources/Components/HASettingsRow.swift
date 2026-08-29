#if !os(watchOS)
import SwiftUI

/// A settings line: a heading with an optional secondary line, and a control on the trailing edge.
/// The SwiftUI counterpart of the frontend's `ha-settings-row`.
public struct HASettingsRow<Prefix: View, Content: View>: View {
    private let heading: String
    private let description: String?
    private let narrow: Bool
    private let slim: Bool
    private let threeLine: Bool
    private let prefix: Prefix
    private let content: Content

    /// - Parameters:
    ///   - narrow: Stacks the control under the text instead of beside it, for a phone-width column.
    ///     The frontend also draws a divider above the row in this mode.
    ///   - slim: Strips the padding and minimum height, for a row inside an already-padded container.
    ///   - threeLine: Reserves room for a description running to three lines.
    ///   - prefix: Content ahead of the heading, usually an icon.
    public init(
        heading: String,
        description: String? = nil,
        narrow: Bool = false,
        slim: Bool = false,
        threeLine: Bool = false,
        @ViewBuilder prefix: () -> Prefix,
        @ViewBuilder content: () -> Content
    ) {
        self.heading = heading
        self.description = description
        self.narrow = narrow
        self.slim = slim
        self.threeLine = threeLine
        self.prefix = prefix()
        self.content = content()
    }

    /// `ha-settings-row` grows the row as lines are added: 56pt with a description, 88pt for three.
    private var minHeight: CGFloat {
        if slim {
            .zero
        } else if threeLine {
            88
        } else if description != nil {
            56
        } else {
            .zero
        }
    }

    private var rowLayout: AnyLayout {
        narrow
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignSystem.Spaces.one))
            : AnyLayout(HStackLayout(alignment: .center, spacing: DesignSystem.Spaces.two))
    }

    public var body: some View {
        VStack(spacing: .zero) {
            // Part of the layout rather than an overlay: drawn over the row it would cross the
            // heading, since a narrow row starts its text at the very top.
            if narrow {
                Rectangle()
                    .fill(Color.haDivider)
                    .frame(height: DesignSystem.Border.Width.default)
            }
            rowContent
        }
    }

    private var rowContent: some View {
        rowLayout {
            HStack(spacing: DesignSystem.Spaces.two) {
                prefix
                VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                    Text(heading)
                        .font(DesignSystem.Font.body)
                    if let description {
                        Text(description)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            content
                .frame(maxWidth: narrow ? .infinity : nil, alignment: narrow ? .leading : .trailing)
        }
        .padding(.horizontal, slim ? .zero : DesignSystem.Spaces.two)
        .padding(.vertical, slim ? .zero : DesignSystem.Spaces.one)
        // A narrow row sits directly under the divider above it; the frontend adds bottom padding
        // in this mode, and the heading needs the same clearance at the top.
        .padding(.top, narrow && !slim ? DesignSystem.Spaces.one : .zero)
        .frame(minHeight: minHeight)
    }
}

public extension HASettingsRow where Prefix == EmptyView {
    /// A row with nothing ahead of its heading.
    init(
        heading: String,
        description: String? = nil,
        narrow: Bool = false,
        slim: Bool = false,
        threeLine: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            heading: heading,
            description: description,
            narrow: narrow,
            slim: slim,
            threeLine: threeLine,
            prefix: { EmptyView() },
            content: content
        )
    }
}

#Preview {
    VStack(spacing: .zero) {
        HASettingsRow(heading: "Location") {
            Toggle("", isOn: .constant(true)).labelsHidden()
        }
        HASettingsRow(heading: "Background refresh", description: "Keeps sensors up to date.") {
            Toggle("", isOn: .constant(false)).labelsHidden()
        }
        HASettingsRow(heading: "With prefix", description: "An icon ahead of the heading.") {
            MaterialDesignIconsImage(icon: .cogIcon, size: 24)
        } content: {
            Toggle("", isOn: .constant(true)).labelsHidden()
        }
        HASettingsRow(heading: "Narrow", description: "The control moves below.", narrow: true) {
            Toggle("", isOn: .constant(true)).labelsHidden()
        }
        HASettingsRow(heading: "Slim", slim: true) {
            Toggle("", isOn: .constant(false)).labelsHidden()
        }
    }
    .padding()
}

extension HASettingsRow: FrontendComponent {
    public static var frontendComponentName: String { "ha-settings-row" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
