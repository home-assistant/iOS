#if !os(watchOS)
import SwiftUI

/// A flow diagram: boxes in columns, joined by ribbons whose thickness is how much passes between
/// them. The SwiftUI counterpart of the frontend's `ha-sankey-chart`.
///
/// The arithmetic is in ``HASankeyLayout``; this draws what that works out.
public struct HASankeyChart: View {
    private let nodes: [HASankeyNode]
    private let links: [HASankeyLink]
    private let height: CGFloat
    private let showsLabels: Bool

    public init(
        nodes: [HASankeyNode],
        links: [HASankeyLink],
        height: CGFloat = 220,
        showsLabels: Bool = true
    ) {
        self.nodes = nodes
        self.links = links
        self.height = height
        self.showsLabels = showsLabels
    }

    private var colorsByID: [String: Color] {
        Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0.color) })
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            GeometryReader { proxy in
                let layout = HASankeyLayout(nodes: nodes, links: links, size: proxy.size)
                let colors = colorsByID
                Canvas { context, _ in
                    for ribbon in layout.ribbons {
                        var path = Path()
                        let midX = (ribbon.start.minX + ribbon.end.minX) / 2
                        path.move(to: CGPoint(x: ribbon.start.minX, y: ribbon.start.minY))
                        // Two horizontal control points at the midpoint: the ribbon leaves and
                        // arrives level, so it reads as a flow rather than a diagonal.
                        path.addCurve(
                            to: CGPoint(x: ribbon.end.minX, y: ribbon.end.minY),
                            control1: CGPoint(x: midX, y: ribbon.start.minY),
                            control2: CGPoint(x: midX, y: ribbon.end.minY)
                        )
                        path.addLine(to: CGPoint(x: ribbon.end.minX, y: ribbon.end.maxY))
                        path.addCurve(
                            to: CGPoint(x: ribbon.start.minX, y: ribbon.start.maxY),
                            control1: CGPoint(x: midX, y: ribbon.end.maxY),
                            control2: CGPoint(x: midX, y: ribbon.start.maxY)
                        )
                        path.closeSubpath()
                        context.fill(path, with: .color((colors[ribbon.source] ?? .haPrimary).opacity(0.4)))
                    }
                    for box in layout.boxes {
                        context.fill(
                            Path(roundedRect: box.rect, cornerRadius: 2),
                            with: .color(colors[box.id] ?? .haPrimary)
                        )
                    }
                }
            }
            .frame(height: height)

            if showsLabels {
                FlowLayout(spacing: DesignSystem.Spaces.oneAndHalf) {
                    ForEach(nodes.filter { $0.label != nil }) { node in
                        HStack(spacing: DesignSystem.Spaces.half) {
                            Circle()
                                .fill(node.color)
                                .frame(width: 8, height: 8)
                            Text(node.label ?? "")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

private let sampleSankeyNodes = [
    HASankeyNode(id: "solar", value: 12.4, column: 0, label: "Solar", color: .haWarningColor),
    HASankeyNode(id: "grid", value: 6.1, column: 0, label: "Grid", color: .haPrimary),
    HASankeyNode(id: "home", value: 18.5, column: 1, label: "Home", color: .haSuccessColor),
]

private let sampleSankeyLinks = [
    HASankeyLink(source: "solar", target: "home"),
    HASankeyLink(source: "grid", target: "home"),
]

#Preview {
    HASankeyChart(nodes: sampleSankeyNodes, links: sampleSankeyLinks)
        .padding()
}

extension HASankeyChart: FrontendComponent {
    public static var frontendComponentName: String { "ha-sankey-chart" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
