import Shared
import SwiftUI

struct WidgetAssistView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    let entry: WidgetAssistEntry

    var body: some View {
        content
    }

    @ViewBuilder
    private var content: some View {
        switch widgetFamily {
        case .accessoryCircular:
            VStack {
                Image(uiImage: MaterialDesignIcons.microphoneMessageIcon.image(
                    ofSize: .init(width: 40, height: 40),
                    color: UIColor(asset: Asset.Colors.haPrimary)
                ))
                .foregroundStyle(.ultraThickMaterial)
                .padding(Spaces.one)
            }
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(Circle())
        default:
            VStack(alignment: .leading) {
                Image(uiImage: MaterialDesignIcons.microphoneMessageIcon.image(
                    ofSize: .init(width: 40, height: 40),
                    color: UIColor(asset: Asset.Colors.haPrimary)
                ))
                .foregroundStyle(.ultraThickMaterial)
                .padding(Spaces.one)
                Spacer()
                Group {
                    Text(entry.server?.displayString ?? "Unknown")
                        .font(.footnote.bold())
                    Text(entry.pipeline?.displayString ?? "Unknown")
                        .font(.footnote.weight(.light))
                }
                .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(uiColor: .systemBackground))
        }
    }
}
