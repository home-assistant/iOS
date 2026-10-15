#if !os(watchOS)
import SwiftUI

/// A robot vacuum drawn in its state's colour: round shell, bumper, lidar turret and side brush. The
/// SwiftUI counterpart of the frontend's `ha-state-control-vacuum-status`, drawn on
/// ``HAStateControlRobotStatus``.
public struct HAStateControlVacuumStatus: View {
    private let state: HARobotVisualState
    private let color: Color

    public init(state: HARobotVisualState, color: Color) {
        self.state = state
        self.color = color
    }

    public var body: some View {
        HAStateControlRobotStatus(
            state: state,
            color: color,
            dock: CGRect(x: 76, y: 188, width: 88, height: 28),
            dockCornerRadius: 8,
            returnArrow: [CGPoint(x: 120, y: 220), CGPoint(x: 110, y: 206), CGPoint(x: 130, y: 206)]
        ) { context, color in
            let brushOpacity: Double = switch state {
            case .idle, .returning: 0.4
            case .docked: 0.5
            default: 1
            }
            var brush = Path()
            for (dx, dy) in [(0.0, -12.0), (0.0, 12.0), (-12.0, 0.0), (12.0, 0.0)] {
                brush.move(to: CGPoint(x: 174, y: 76))
                brush.addLine(to: CGPoint(x: 174 + dx, y: 76 + dy))
            }
            context.stroke(
                brush,
                with: .color(color.opacity(0.5 * brushOpacity)),
                style: StrokeStyle(lineWidth: 1.2, lineCap: .round)
            )
            context.fill(circle(174, 76, 2), with: .color(color.opacity(0.5 * brushOpacity)))

            context.fill(circle(120, 120, 72), with: .color(.haCardBackground))
            context.stroke(circle(120, 120, 72), with: .color(color), lineWidth: 2)
            context.stroke(circle(120, 120, 66), with: .color(color.opacity(0.2)), lineWidth: 0.8)

            var bumper = Path()
            bumper.addArc(
                center: CGPoint(x: 120, y: 126),
                radius: 68,
                startAngle: .degrees(208.07),
                endAngle: .degrees(331.93),
                clockwise: false
            )
            context.stroke(bumper, with: .color(color), style: StrokeStyle(lineWidth: 3, lineCap: .round))

            var navigation = Path()
            navigation.move(to: CGPoint(x: 120, y: 56))
            navigation.addLine(to: CGPoint(x: 120, y: 74))
            navigation.move(to: CGPoint(x: 88, y: 63))
            navigation.addLine(to: CGPoint(x: 96, y: 78))
            navigation.move(to: CGPoint(x: 152, y: 63))
            navigation.addLine(to: CGPoint(x: 144, y: 78))
            context.stroke(navigation, with: .color(color.opacity(state == .active ? 0.3 : 0.15)), lineWidth: 1.5)

            context.fill(circle(120, 108, 14), with: .color(.haCardBackground))
            context.stroke(circle(120, 108, 14), with: .color(color), lineWidth: 2)
            context.stroke(circle(120, 108, 9), with: .color(color.opacity(0.25)), lineWidth: 0.8)

            context.fill(circle(120, 140, 8), with: .color(color.opacity(0.08)))
            context.fill(circle(120, 140, 4), with: .color(color.opacity(0.25)))
        }
    }

    private func circle(_ x: CGFloat, _ y: CGFloat, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(), GridItem()]) {
        ForEach(HARobotVisualState.allCases, id: \.self) { state in
            HAStateControlVacuumStatus(
                state: state,
                color: state == .error ? FrontendColors.stateVacuumErrorColor.color
                    : FrontendColors.stateVacuumActiveColor.color
            )
            .scaleEffect(0.7)
        }
    }
}

extension HAStateControlVacuumStatus: FrontendComponent {
    public static var frontendComponentName: String { "ha-state-control-vacuum-status" }
    public static var frontendComponentVersion: String { "2026-10-12" }
}

#endif
