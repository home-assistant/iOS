#if !os(watchOS)
import SwiftUI

/// The stage a robot's status illustration is drawn on: the soft glow behind it, the dock it sits on
/// once docked, the arrow it follows home, and the robot itself turned around while returning.
///
/// Frontend counterpart: the parts `ha-state-control-vacuum-status` and
/// `ha-state-control-lawn_mower-status` share, in their reduced-motion form. The frontend animates
/// the robot wandering, its brush spinning and debris flying; a snapshot could only ever catch that
/// mid-move, so this draws the still frame the frontend falls back to under
/// `prefers-reduced-motion`.
public struct HAStateControlRobotStatus: View {
    private let state: HARobotVisualState
    private let color: Color
    private let dock: CGRect
    private let dockCornerRadius: CGFloat
    private let returnArrow: [CGPoint]
    private let drawBody: (inout GraphicsContext, Color) -> Void

    private static let canvasSize: CGFloat = 240
    private static let displaySize: CGFloat = 200

    /// - Parameters:
    ///   - dock: The dock plate, in the 240-point space both illustrations are drawn in.
    ///   - returnArrow: The triangle under the robot while it heads home, in the same space.
    ///   - drawBody: Draws the robot in that space, in the colour given.
    public init(
        state: HARobotVisualState,
        color: Color,
        dock: CGRect,
        dockCornerRadius: CGFloat,
        returnArrow: [CGPoint],
        drawBody: @escaping (inout GraphicsContext, Color) -> Void
    ) {
        self.state = state
        self.color = color
        self.dock = dock
        self.dockCornerRadius = dockCornerRadius
        self.returnArrow = returnArrow
        self.drawBody = drawBody
    }

    public var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / Self.canvasSize, y: size.height / Self.canvasSize)
            let centre = CGPoint(x: Self.canvasSize / 2, y: Self.canvasSize / 2)

            context.fill(
                Path(ellipseIn: CGRect(x: centre.x - 110, y: centre.y - 110, width: 220, height: 220)),
                with: .color(color.opacity(state.glowOpacity))
            )

            if state == .docked {
                let plate = Path(roundedRect: dock, cornerRadius: dockCornerRadius)
                context.fill(plate, with: .color(.haCardBackground))
                context.stroke(plate, with: .color(color), lineWidth: 2)
            }

            if state == .returning, let first = returnArrow.first {
                var arrow = Path()
                arrow.move(to: first)
                returnArrow.dropFirst().forEach { arrow.addLine(to: $0) }
                arrow.closeSubpath()
                context.fill(arrow, with: .color(color.opacity(0.55)))
            }

            var robot = context
            robot.opacity = state.bodyOpacity
            if state == .returning {
                robot.translateBy(x: centre.x, y: centre.y)
                robot.rotate(by: .degrees(180))
                robot.translateBy(x: -centre.x, y: -centre.y)
            }
            drawBody(&robot, color)
        }
        .frame(width: Self.displaySize, height: Self.displaySize)
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        HAStateControlVacuumStatus(state: .docked, color: .secondary)
        HAStateControlLawnMowerStatus(state: .returning, color: FrontendColors.stateLawnMowerActiveColor.color)
    }
}
#endif
