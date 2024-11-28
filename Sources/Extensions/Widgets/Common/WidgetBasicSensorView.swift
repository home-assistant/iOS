import AppIntents
import Foundation
import Shared
import SwiftUI

struct WidgetBasicSensorView: WidgetBasicViewInterface {
    @Environment(\.widgetFamily) private var widgetFamily

    let model: WidgetBasicViewModel
    let sizeStyle: WidgetBasicSizeStyle
    let tinted: Bool

    init(model: WidgetBasicViewModel, sizeStyle: WidgetBasicSizeStyle, tinted: Bool) {
        self.model = model
        self.sizeStyle = sizeStyle
        self.tinted = tinted
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
            .lineLimit(1)
    }

    @ViewBuilder
    private var subtext: some View {
        if let subtitle = model.subtitle {
            Text(verbatim: subtitle)
                .font(sizeStyle.subtextFont)
                .foregroundStyle(model.useCustomColors ? model.textColor : Color(uiColor: .label))
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private var icon: some View {
        VStack {
            Text(verbatim: model.icon.unicode)
                .font(sizeStyle.iconFont)
                .foregroundColor(model.iconColor)
                .fixedSize(horizontal: false, vertical: false)
        }
    }

    private var tileView: some View {
        VStack(alignment: .leading) {
            Group {
                switch sizeStyle {
                case .regular, .condensed, .compressed:
                    HStack(alignment: .center, spacing: Spaces.oneAndHalf) {
                        VStack(alignment: .leading, spacing: .zero) {
                            subtext
                            text
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        icon
                            .offset(y: -10)
                    }
                    .padding([.leading, .trailing], Spaces.oneAndHalf)
                case .single, .expanded:
                    VStack(alignment: .leading, spacing: 0) {
                        icon
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        Spacer()
                        subtext
                        text
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, sizeStyle == .regular ? 10 : /* use default */ nil)
                }
            }
            .modify { view in
                if #available(iOS 18, *) {
                    view.widgetAccentable()
                } else {
                    view
                }
            }
        }
        .tileCardStyle(sizeStyle: sizeStyle, model: model, tinted: tinted)
    }
}
