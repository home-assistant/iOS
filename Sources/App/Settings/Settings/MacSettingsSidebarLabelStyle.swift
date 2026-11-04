import Shared
import SwiftUI

struct MacSettingsSidebarLabelStyle: LabelStyle {
    static let iconSize: CGFloat = 18

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: DesignSystem.Spaces.one) {
            configuration.icon
                .foregroundStyle(Color.haPrimary)
                .frame(width: Self.iconSize, height: Self.iconSize)
            configuration.title
        }
    }
}
