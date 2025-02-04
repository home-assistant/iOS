import AppIntents
import Foundation
import Shared
import SwiftUI

struct WidgetBasicButtonView: WidgetBasicViewInterface {
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
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading) {
                Group {
                    switch sizeStyle {
                    case .regular, .condensed, .compressed:
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
                .modify { view in
                    if #available(iOS 18, *) {
                        view.widgetAccentable()
                    } else {
                        view
                    }
                }
            }
            .tileCardStyle(sizeStyle: sizeStyle, model: model, tinted: tinted)
            .opacity(model.disabled ? 0.3 : 1)
            progressIndicator
        }
    }

    @ViewBuilder
    private var progressIndicator: some View {
        Group {
            let success = model.progress == 100
            let failure = model.progress == -1
            RingProgressView(progress: model.progress)
                .opacity((model.showProgress && !success && !failure) ? 1 : 0)
                .offset(x: -2, y: 2)
            Image(systemSymbol: success ? .checkmarkCircleFill : .xmarkCircleFill)
                .resizable()
                .frame(width: 19, height: 19, alignment: .topTrailing)
                .foregroundStyle(.white, success ? Color.asset(Asset.Colors.haPrimary) : .red)
                .opacity((success || failure) ? 1 : 0)
        }
        .padding([.top, .trailing], Spaces.one)
    }
}

struct RingProgressView: View {
    var progress: Int

    private let lineWidth: CGFloat = 4
    private let size: CGFloat = 15

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.0, to: CGFloat(progress) / 100)
                .stroke(
                    AngularGradient(gradient: Gradient(colors: [Color.asset(Asset.Colors.haPrimary)]), center: .center),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size, alignment: .topTrailing)
    }
}
