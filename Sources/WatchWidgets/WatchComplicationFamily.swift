import WidgetKit

enum WatchComplicationFamily: String, CaseIterable {
    case circularSmall
    case extraLarge
    case graphicBezel
    case graphicCircular
    case graphicCorner
    case graphicRectangular
    case modularLarge
    case modularSmall
    case utilitarianLarge
    case utilitarianSmall
    case utilitarianSmallFlat

    static func preferredFamilies(for widgetFamily: WidgetFamily) -> [Self] {
        switch widgetFamily {
        case .accessoryCircular:
            return [.graphicCircular, .circularSmall, .modularSmall, .extraLarge]
        case .accessoryRectangular:
            return [.graphicRectangular, .modularLarge, .utilitarianLarge]
        case .accessoryInline:
            return [.utilitarianSmallFlat, .utilitarianSmall, .graphicBezel]
        case .accessoryCorner:
            return [.graphicCorner, .graphicCircular, .circularSmall]
        default:
            return [
                .graphicCircular,
                .graphicRectangular,
                .utilitarianSmallFlat,
                .graphicCorner,
                .circularSmall,
                .modularSmall,
                .modularLarge,
                .extraLarge,
                .utilitarianSmall,
                .utilitarianLarge,
            ]
        }
    }
}
