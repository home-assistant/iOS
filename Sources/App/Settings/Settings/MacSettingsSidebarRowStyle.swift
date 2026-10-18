import Shared
import SwiftUI

struct MacSettingsSidebarRowStyle: ViewModifier {
    private enum Constants {
        static let selectedFillOpacity: CGFloat = 0.12
        static let hoverFillOpacity: CGFloat = 0.06
    }

    let isSelected: Bool

    @State private var isHovering = false

    func body(content: Content) -> some View {
        if Current.isCatalyst {
            content
                .onHover { isHovering = $0 }
                .listRowInsets(EdgeInsets(
                    top: 0,
                    leading: DesignSystem.Spaces.two,
                    bottom: 0,
                    trailing: DesignSystem.Spaces.two
                ))
                .listRowSeparator(.hidden)
                .listRowBackground(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.one, style: .continuous)
                        .fill(Color.primary.opacity(fillOpacity))
                        .padding(.horizontal, DesignSystem.Spaces.one)
                        .padding(.vertical, DesignSystem.Spaces.micro / 2)
                )
        } else {
            content
        }
    }

    private var fillOpacity: CGFloat {
        if isSelected {
            return Constants.selectedFillOpacity
        } else if isHovering {
            return Constants.hoverFillOpacity
        } else {
            return 0
        }
    }
}

extension View {
    func macSettingsSidebarRow(isSelected: Bool = false) -> some View {
        modifier(MacSettingsSidebarRowStyle(isSelected: isSelected))
    }
}
