import Foundation
import SwiftUI

public struct RoundedCorner: Shape {
    public var radius: CGFloat = .infinity
    public var corners: UIRectCorner = .allCorners

    public init(radius: CGFloat = .infinity, corners: UIRectCorner = .allCorners) {
        self.radius = radius
        self.corners = corners
    }

    public func path(in rect: CGRect) -> Path {
        #if os(macOS)
        let radius = min(radius, min(rect.width, rect.height) / 2)
        return UnevenRoundedRectangle(
            topLeadingRadius: corners.contains(.topLeft) ? radius : 0,
            bottomLeadingRadius: corners.contains(.bottomLeft) ? radius : 0,
            bottomTrailingRadius: corners.contains(.bottomRight) ? radius : 0,
            topTrailingRadius: corners.contains(.topRight) ? radius : 0
        ).path(in: rect)
        #else
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
        #endif
    }
}

public extension View {
    func roundedCorner(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}
