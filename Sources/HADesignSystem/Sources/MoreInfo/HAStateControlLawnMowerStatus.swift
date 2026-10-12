#if !os(watchOS)
import SwiftUI

/// A robot lawn mower drawn in its state's colour: D-shaped shell, bumper, rear wheels and, while it
/// mows, the blade disc underneath. The SwiftUI counterpart of the frontend's
/// `ha-state-control-lawn_mower-status`, drawn on ``HAStateControlRobotStatus``.
public struct HAStateControlLawnMowerStatus: View {
    private let state: HARobotVisualState
    private let color: Color

    public init(state: HARobotVisualState, color: Color) {
        self.state = state
        self.color = color
    }

    private var bladeOpacity: Double {
        switch state {
        case .active: 0.15
        case .returning: 0.06
        case .paused: 0.04
        case .idle, .docked, .error: 0
        }
    }

    public var body: some View {
        HAStateControlRobotStatus(
            state: state,
            color: color,
            dock: CGRect(x: 80, y: 188, width: 80, height: 24),
            dockCornerRadius: 7,
            returnArrow: [CGPoint(x: 120, y: 220), CGPoint(x: 110, y: 208), CGPoint(x: 130, y: 208)]
        ) { context, color in
            if bladeOpacity > 0 {
                var blades = context
                blades.opacity = bladeOpacity
                blades.stroke(
                    circle(120, 130, 46),
                    with: .color(color),
                    style: StrokeStyle(lineWidth: 1.5, dash: [8, 6])
                )
                blades.fill(circle(120, 130, 6), with: .color(color))
                var arms = Path()
                for end in [CGPoint(x: 120, y: 88), CGPoint(x: 156, y: 151), CGPoint(x: 84, y: 151)] {
                    arms.move(to: CGPoint(x: 120, y: 130))
                    arms.addLine(to: end)
                }
                blades.stroke(arms, with: .color(color), lineWidth: 2)
            }

            for x in [CGFloat(50), 178] {
                let wheel = Path(roundedRect: CGRect(x: x, y: 144, width: 12, height: 40), cornerRadius: 5)
                context.fill(wheel, with: .color(.haCardBackground))
                context.stroke(wheel, with: .color(color.opacity(0.7)), lineWidth: 1.5)
                var tread = Path()
                tread.move(to: CGPoint(x: x + 6, y: 148))
                tread.addLine(to: CGPoint(x: x + 6, y: 180))
                context.stroke(tread, with: .color(color.opacity(0.12)), style: StrokeStyle(lineWidth: 6, dash: [3, 3]))
            }

            let shell = dShape(left: 64, right: 176, top: 98, control: 50, bottom: 186, corner: 18)
            context.fill(shell, with: .color(.haCardBackground))
            context.stroke(shell, with: .color(color), lineWidth: 2)
            context.stroke(
                dShape(left: 74, right: 166, top: 102, control: 60, bottom: 176, corner: 14),
                with: .color(color.opacity(0.2)),
                lineWidth: 0.8
            )

            context.stroke(
                arch(left: 64, right: 176, base: 102, control: 52),
                with: .color(color),
                style: StrokeStyle(lineWidth: 4, lineCap: .round)
            )
            context.stroke(
                arch(left: 72, right: 168, base: 100, control: 58),
                with: .color(color.opacity(0.15)),
                lineWidth: 1
            )

            for point in [CGPoint(x: 92, y: 68), CGPoint(x: 120, y: 60), CGPoint(x: 148, y: 68)] {
                context.fill(circle(point.x, point.y, 1.5), with: .color(color.opacity(0.15)))
            }
            context.fill(circle(120, 78, 4), with: .color(color.opacity(0.08)))
            context.fill(circle(120, 78, 2.5), with: .color(color.opacity(0.5)))
            context.fill(circle(120, 148, 8), with: .color(color.opacity(0.06)))
            context.fill(circle(120, 148, 4), with: .color(color.opacity(0.2)))
        }
    }

    private func circle(_ x: CGFloat, _ y: CGFloat, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
    }

    private func arch(left: CGFloat, right: CGFloat, base: CGFloat, control: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: left, y: base))
        path.addCurve(
            to: CGPoint(x: right, y: base),
            control1: CGPoint(x: left, y: control),
            control2: CGPoint(x: right, y: control)
        )
        return path
    }

    private func dShape(
        left: CGFloat,
        right: CGFloat,
        top: CGFloat,
        control: CGFloat,
        bottom: CGFloat,
        corner: CGFloat
    ) -> Path {
        var path = arch(left: left, right: right, base: top, control: control)
        path.addLine(to: CGPoint(x: right, y: bottom - corner))
        path.addCurve(
            to: CGPoint(x: right - corner, y: bottom),
            control1: CGPoint(x: right, y: bottom - corner / 3),
            control2: CGPoint(x: right - corner / 3, y: bottom)
        )
        path.addLine(to: CGPoint(x: left + corner, y: bottom))
        path.addCurve(
            to: CGPoint(x: left, y: bottom - corner),
            control1: CGPoint(x: left + corner / 3, y: bottom),
            control2: CGPoint(x: left, y: bottom - corner / 3)
        )
        path.closeSubpath()
        return path
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(), GridItem()]) {
        ForEach(HARobotVisualState.allCases, id: \.self) { state in
            HAStateControlLawnMowerStatus(
                state: state,
                color: state == .error ? FrontendColors.stateLawnMowerErrorColor.color
                    : FrontendColors.stateLawnMowerActiveColor.color
            )
            .scaleEffect(0.7)
        }
    }
}

extension HAStateControlLawnMowerStatus: FrontendComponent {
    public static var frontendComponentName: String { "ha-state-control-lawn_mower-status" }
    public static var frontendComponentVersion: String { "2026-10-12" }
}

#endif
