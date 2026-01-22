import ActivityKit
import Shared
import SwiftUI
import WidgetKit

@available(iOS 16.2, *)
struct AppIntentConfirmationLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AppIntentConfirmationAttributes.self) { context in
            // Lock screen/banner UI
            AppIntentConfirmationBannerView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded view
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.isSuccess ? "checkmark.seal.fill" : "xmark.seal.fill")
                        .font(.title)
                        .foregroundStyle(.white, context.state.isSuccess ? .green : .red)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    EmptyView()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.title)
                        .font(.body)
                        .lineLimit(2)
                }
            } compactLeading: {
                Image(systemName: context.state.isSuccess ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white, context.state.isSuccess ? .green : .red)
            } compactTrailing: {
                EmptyView()
            } minimal: {
                Image(systemName: context.state.isSuccess ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white, context.state.isSuccess ? .green : .red)
            }
        }
    }
}

@available(iOS 16.2, *)
private struct AppIntentConfirmationBannerView: View {
    let context: ActivityViewContext<AppIntentConfirmationAttributes>

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: context.state.isSuccess ? "checkmark.seal.fill" : "xmark.seal.fill")
                .font(.title2)
                .foregroundStyle(.white, context.state.isSuccess ? .green : .red)

            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)

                Text(context.state.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .activityBackgroundTint(Color(.systemBackground))
//        .activitySystemActionForegroundColor(.label)
    }
}
