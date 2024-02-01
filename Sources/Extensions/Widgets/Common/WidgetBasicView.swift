import Foundation
import Shared
import SwiftUI

struct WidgetBasicViewModel: Identifiable, Hashable {
    init(
        id: String,
        title: String,
        subtitle: String?,
        widgetURL: URL,
        icon: MaterialDesignIcons,
        showsChevron: Bool = false,
        textColor: Color = Color.black,
        iconColor: Color = Color.black,
        backgroundColor: Color = Color.white
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.widgetURL = widgetURL
        self.textColor = textColor
        self.icon = icon
        self.showsChevron = showsChevron
        self.iconColor = iconColor
        self.backgroundColor = backgroundColor
    }

    var id: String

    var title: String
    var subtitle: String?
    var widgetURL: URL

    var icon: MaterialDesignIcons
    var showsChevron: Bool

    var backgroundColor: Color
    var textColor: Color
    var iconColor: Color
}

enum WidgetBasicSizeStyle {
    case single
    case expanded
    case condensed
    case regular

    var textFont: Font {
        switch self {
        case .single, .expanded:
            return .subheadline
        case .condensed, .regular:
            return .footnote
        }
    }

    var subtextFont: Font {
        switch self {
        case .single, .expanded:
            return .footnote
        case .regular, .condensed:
            return .system(size: 12)
        }
    }

    var iconFont: Font {
        let size: CGFloat

        switch self {
        case .single, .expanded:
            size = 38
        case .regular:
            size = 28
        case .condensed:
            size = 18
        }

        return .custom(MaterialDesignIcons.familyName, size: size)
    }

    var chevronFont: Font {
        let size: CGFloat

        switch self {
        case .single, .expanded:
            size = 18
        case .regular:
            size = 14
        case .condensed:
            size = 9
        }

        return .system(size: size, weight: .bold)
    }
}

struct WidgetBasicView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    private let model: WidgetBasicViewModel
    private let sizeStyle: WidgetBasicSizeStyle

    init(model: WidgetBasicViewModel, sizeStyle: WidgetBasicSizeStyle) {
        self.model = model
        self.sizeStyle = sizeStyle
        MaterialDesignIcons.register()
    }

    var body: some View {
        if #available(iOS 16, *) {
            switch widgetFamily {
            case .accessoryCircular:
                mainContentWithBackground
                    .clipShape(Circle())
            case .accessoryRectangular:
                mainContent
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            default:
                mainContentWithBackground
            }
        } else {
            mainContentWithBackground
        }
    }

    private var mainContentWithBackground: some View {
        mainContent
            .background(model.backgroundColor)
    }

    private var mainContent: some View {
        ZStack(alignment: .leading) {
            backgroundView
            switch sizeStyle {
            case .regular, .condensed:
                regularOrCondensedView
            case .single, .expanded:
                singleOrExpandedView
            }
        }
    }

    private var regularOrCondensedView: some View {
        HStack(alignment: .center, spacing: 6.0) {
            iconView
            if model.subtitle != nil {
                VStack(alignment: .leading, spacing: -2) {
                    textView
                    subtext
                }
            } else {
                textView
            }
            Spacer()
        }.padding(
            .leading, 12
        )
    }

    private var singleOrExpandedView: some View {
        VStack(alignment: .leading, spacing: 0) {
            iconView
            if #available(iOS 16, *) {
                if widgetFamily != .accessoryCircular {
                    textContent
                }
            } else {
                textContent
            }
        }
        .padding(
            [.leading, .trailing]
        ).padding(
            [.top, .bottom],
            sizeStyle == .regular ? 10 : /* use default */ nil
        )
    }

    @ViewBuilder
    private var iconView: some View {
        if #available(iOS 16, *), widgetFamily == .accessoryCircular {
            ZStack {
                iconUnicodeView
                pageIconImage
                    .background(Color.red)
                    .cornerRadius(10)
                    .offset(x: 10, y: -10)
            }
        } else {
            HStack(alignment: .top, spacing: -1) {
                iconUnicodeView
                openPageIcon
            }
        }
    }

    private var iconUnicodeView: some View {
        Text(verbatim: model.icon.unicode)
            .font(sizeStyle.iconFont)
            .minimumScaleFactor(0.2)
            .foregroundColor(model.iconColor)
            .fixedSize(horizontal: false, vertical: false)
    }

    private var textView: some View {
        Text(verbatim: model.title)
            .font(sizeStyle.textFont)
            .fontWeight(.semibold)
            .multilineTextAlignment(.leading)
            .foregroundColor(model.textColor)
            .lineLimit(nil)
            .minimumScaleFactor(0.5)
    }

    @ViewBuilder
    private var subtext: some View {
        if let subtitle = model.subtitle {
            Text(verbatim: subtitle)
                .font(sizeStyle.subtextFont)
                .foregroundColor(model.textColor.opacity(0.7))
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var backgroundView: some View {
        Rectangle().fill(
            LinearGradient(
                gradient: .init(colors: [.white.opacity(0.06), .black.opacity(0.06)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    @ViewBuilder
    private var openPageIcon: some View {
        if model.showsChevron {
            if #available(iOS 16, *), widgetFamily == .accessoryCircular {
                pageIconImage
            } else {
                pageIconImage
                    .font(sizeStyle.chevronFont)
                    .foregroundColor(model.iconColor)
            }
        }
    }

    private var pageIconImage: some View {
        // this sfsymbols is a little more legible at smaller size than mdi:open-in-new
        Image(systemName: "arrow.up.forward.app")
    }

    @ViewBuilder
    private var textContent: some View {
        Spacer()
        textView
        subtext
    }
}
