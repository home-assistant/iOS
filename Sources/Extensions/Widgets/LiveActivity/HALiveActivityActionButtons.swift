#if os(iOS) && !targetEnvironment(macCatalyst)
import AppIntents
import SFSafeSymbols
import Shared
import SwiftUI
import UIKit

@available(iOS 17.2, *)
struct HALiveActivityActionButtons: View {
    let activityID: String
    let actions: [HALiveActivityAction]

    var body: some View {
        HStack(spacing: DesignSystem.Spaces.one) {
            ForEach(actions) { action in
                Button(intent: HALiveActivityActionIntent(activityID: activityID, actionID: action.id)) {
                    HStack(spacing: DesignSystem.Spaces.half) {
                        if let symbol = action.systemImage, UIImage(systemName: symbol) != nil {
                            Image(systemSymbol: SFSymbol(rawValue: symbol))
                                .accessibilityHidden(true)
                        }
                        Text(verbatim: action.title)
                            .lineLimit(1)
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(.primary.opacity(0.12), in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

@available(iOS 17.2, *)
#Preview {
    HALiveActivityActionButtons(activityID: "preview", actions: [
        .init(id: "PLAY", title: "Play", icon: "sfsymbols:play.fill"),
        .init(id: "PAUSE", title: "Pause", icon: "sfsymbols:pause.fill"),
        .init(id: "NEXT", title: "Next", icon: "sfsymbols:forward.end.fill"),
    ])
    .padding()
}
#endif
