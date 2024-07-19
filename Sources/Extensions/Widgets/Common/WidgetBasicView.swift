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
    }

    private var tileView: some View {
        VStack(alignment: .leading) {
            switch sizeStyle {
            case .regular, .condensed:
                HStack(alignment: .center, spacing: Spaces.two) {
                    icon
                    VStack(alignment: .leading, spacing: Spaces.half) {
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
        .background(Color.asset(Asset.Colors.tileBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.asset(Asset.Colors.tileBorder), lineWidth: 1)
        }
    }
}
