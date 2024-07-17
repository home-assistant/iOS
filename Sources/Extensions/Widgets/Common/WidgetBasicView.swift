import AppIntents
import Foundation
import Shared
import SwiftUI

struct WidgetBasicViewModel: Identifiable, Hashable, Encodable {
    init(
        id: String,
        title: String,
        subtitle: String?,
        interactionType: InteractionType,
        icon: MaterialDesignIcons,
        showsChevron: Bool = false,
        textColor: Color = Color.black,
        iconColor: Color = Color.black,
        backgroundColor: Color = Color.white
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.interactionType = interactionType
        self.textColor = textColor
        self.icon = icon
        self.showsChevron = showsChevron
        self.iconColor = iconColor
        self.backgroundColor = backgroundColor
    }

    var id: String

    var title: String
    var subtitle: String?
    var interactionType: InteractionType

    var icon: MaterialDesignIcons
    var showsChevron: Bool

    var backgroundColor: Color
    var textColor: Color
    var iconColor: Color

    enum InteractionType: Hashable, Encodable {
        case widgetURL(URL)
        case appIntent(WidgetIntentType)
    }

    enum WidgetIntentType: Hashable, Encodable {
        case action(id: String, name: String)
    }
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
            size = 32
        case .regular:
            size = 20
        case .condensed:
            size = 14
        }

        return .custom(MaterialDesignIcons.familyName, size: size)
    }
}

struct WidgetBasicView: View {
    @Environment(\.widgetFamily) private var widgetFamily

    private let model: WidgetBasicViewModel
    private let sizeStyle: WidgetBasicSizeStyle

    init(model: WidgetBasicViewModel, sizeStyle: WidgetBasicSizeStyle) {
        self.model = model
        self.sizeStyle = sizeStyle
    }

    var body: some View {
        switch widgetFamily {
        case .accessoryCircular, .accessoryRectangular:
            WidgetCircularView(icon: model.icon)
        case .accessoryInline:
            Label {
                Text(model.title)
            } icon: {
                Image(uiImage: model.icon.image(ofSize: .init(width: 10, height: 10), color: .white))
            }
        default:
            tileView
        }
    }

    private var text: some View {
        Text(verbatim: model.title)
           .font(sizeStyle.textFont)
           .fontWeight(.semibold)
           .multilineTextAlignment(.leading)
           .foregroundStyle(Color(uiColor: .label))
           .lineLimit(2)
           .minimumScaleFactor(0.5)
    }

    @ViewBuilder
    private var subtext: some View {
        if let subtitle = model.subtitle {
            Text(verbatim: subtitle)
                .font(sizeStyle.subtextFont)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var icon: some View {
        VStack {
            Text(verbatim: model.icon.unicode)
                .font(sizeStyle.iconFont)
                .minimumScaleFactor(0.2)
                .foregroundColor(model.backgroundColor)
                .fixedSize(horizontal: false, vertical: false)
                .padding(Spaces.one)
        }
        .background(model.backgroundColor.opacity(0.3))
        .clipShape(Circle())
        .overlay(
            Circle().stroke(model.backgroundColor, lineWidth: 2)
        )
    }

    private var tileView: some View {
        VStack(alignment: .leading) {
            switch sizeStyle {
            case .regular, .condensed:
                HStack(alignment: .center, spacing: Spaces.two) {
                    icon
                    VStack(alignment: .leading, spacing: -2) {
                        text
                        subtext
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding([.leading, .trailing], Spaces.two)
            case .single, .expanded:
                VStack(alignment: .leading, spacing: 0) {
                    icon
                    Spacer()
                    text
                    subtext
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.vertical, sizeStyle == .regular ? 10 : /* use default */ nil)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
