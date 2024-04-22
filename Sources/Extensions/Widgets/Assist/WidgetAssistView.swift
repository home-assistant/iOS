import Shared
import SwiftUI

struct WidgetAssistView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    let entry: WidgetAssistEntry

    private var subtitle: String {
        // Even though server is not visible, show ".unknownConfiguration"
        // so user knows it needs to be set
        if entry.pipeline == nil || entry.server == nil {
            return L10n.Widgets.Assist.unknownConfiguration
        }

        return entry.pipeline?.displayString ?? L10n.Widgets.Assist.unknownConfiguration
    }

    var body: some View {
        content
    }

    @ViewBuilder
    private var content: some View {
        switch widgetFamily {
        case .accessoryCircular:
            accessoryCircular
        default:
            singleHomeScreenItem
        }
    }

    private var accessoryCircular: some View {
        VStack(spacing: 2) {
            Image(uiImage: MaterialDesignIcons.messageProcessingOutlineIcon.image(
                ofSize: .init(width: 24, height: 24),
                color: .white
            ))
            .foregroundStyle(.ultraThickMaterial)
            Image(imageAsset: Asset.SharedAssets.logo)
                .resizable()
                .frame(width: 10, height: 10)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(Circle())
    }

    private var singleHomeScreenItem: some View {
        VStack(spacing: Spaces.two) {
            Spacer()
            Image(uiImage: MaterialDesignIcons.messageProcessingOutlineIcon.image(
                ofSize: .init(width: 56, height: 56),
                color: UIColor(asset: Asset.Colors.haPrimary)
            ))
            .foregroundStyle(.ultraThickMaterial)
            VStack(spacing: .zero) {
                Group {
                    Text(L10n.Widgets.Assist.actionTitle)
                        .font(.footnote.bold())
                        .foregroundColor(Color(uiColor: .label))
                    Text(subtitle)
                        .font(.footnote.weight(.light))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.center)
                }
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spaces.two)
        .background(Color(uiColor: .systemBackground))
    }
}
