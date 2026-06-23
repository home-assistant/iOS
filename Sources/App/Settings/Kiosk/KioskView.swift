import Shared
import SwiftUI

struct ConditionalContainerView: View {
    @StateObject private var kiosk = Current.kiosk

    var body: some View {
        if kiosk.settings.enabled {
            KioskView()
        } else {
            ContainerView()
        }
    }
}

struct KioskView: View {
    var body: some View {
        ContainerView()
            .overlay(alignment: .bottomLeading) {
                if Current.isDebug {
                    debugWatermark
                }
            }
    }

    private var debugWatermark: some View {
        Text(verbatim: "KIOSK MODE")
            .font(.caption2.weight(.bold))
            .foregroundColor(.white)
            .padding(.horizontal, DesignSystem.Spaces.one)
            .padding(.vertical, DesignSystem.Spaces.half)
            .background(Color.red.opacity(0.75))
            .clipShape(Capsule())
            .padding(DesignSystem.Spaces.two)
            .allowsHitTesting(false)
    }
}
