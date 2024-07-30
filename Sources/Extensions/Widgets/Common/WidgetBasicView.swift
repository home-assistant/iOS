import AppIntents
import Foundation
import Shared
import SwiftUI

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
            .foregroundStyle(model.useCustomColors ? model.textColor : Color(uiColor: .label))
            .lineLimit(2)
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
                .foregroundColor(model.iconColor)
                .fixedSize(horizontal: false, vertical: false)
        }
        .frame(width: sizeStyle.iconCircleSize.width, height: sizeStyle.iconCircleSize.height)
        .background(model.iconColor.opacity(0.3))
        .clipShape(Circle())
    }

    private var tileView: some View {
        VStack(alignment: .leading) {
            switch sizeStyle {
            case .regular, .condensed:
                HStack(alignment: .center, spacing: Spaces.oneAndHalf) {
                    icon
                    VStack(alignment: .leading, spacing: .zero) {
                        text
                        subtext
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding([.leading, .trailing], Spaces.oneAndHalf)
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
        .background(model.useCustomColors ? model.backgroundColor : Color.asset(Asset.Colors.tileBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.asset(Asset.Colors.tileBorder), lineWidth: sizeStyle == .single ? 0 : 1)
        }
    }
}
