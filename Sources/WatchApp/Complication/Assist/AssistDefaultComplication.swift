import ClockKit
import Foundation
import Shared
import SwiftUI

enum AssistDefaultComplication {
    static let title = "Assist"
    static let launchNotification: Notification.Name = .init("assist-detault-complication-launch")
    static let defaultComplicationId = "default-assist"
    static var descriptor: CLKComplicationDescriptor {
        CLKComplicationDescriptor(
            identifier: defaultComplicationId,
            displayName: "Assist",
            supportedFamilies: CLKComplicationFamily.allCases
        )
    }

    static func createAssistTemplate(for family: CLKComplicationFamily) -> CLKComplicationTemplate {
        let assistIcon = MaterialDesignIcons.messageProcessingOutlineIcon
        let iconColor = UIColor(Color.haPrimary)
        var bigIcon: UIImage {
            assistIcon.image(
                ofSize: .init(width: 34, height: 34), color: iconColor
            )
        }
        var smallIcon: UIImage {
            assistIcon.image(
                ofSize: .init(width: 24, height: 24), color: iconColor
            )
        }
        switch family {
        case .modularSmall:
            return CLKComplicationTemplateModularSmallSimpleText(textProvider: CLKSimpleTextProvider(text: title))
        case .modularLarge:
            return CLKComplicationTemplateModularLargeStandardBody(
                headerTextProvider: CLKSimpleTextProvider(text: title),
                body1TextProvider: CLKSimpleTextProvider(text: "")
            )
        case .utilitarianSmall:
            return CLKComplicationTemplateUtilitarianSmallSquare(
                imageProvider: CLKImageProvider(onePieceImage: bigIcon)
            )
        case .utilitarianSmallFlat:
            return CLKComplicationTemplateUtilitarianSmallFlat(textProvider: CLKSimpleTextProvider(text: title))
        case .utilitarianLarge:
            return CLKComplicationTemplateUtilitarianLargeFlat(textProvider: CLKSimpleTextProvider(text: title))
        case .circularSmall:
            return CLKComplicationTemplateCircularSmallSimpleText(textProvider: CLKSimpleTextProvider(text: title))
        case .extraLarge:
            return CLKComplicationTemplateExtraLargeSimpleText(textProvider: CLKSimpleTextProvider(text: title))
        case .graphicCorner:
            return CLKComplicationTemplateGraphicCornerTextImage(
                textProvider: CLKSimpleTextProvider(text: title),
                imageProvider: CLKFullColorImageProvider(fullColorImage: smallIcon)
            )
        case .graphicBezel:
            return CLKComplicationTemplateGraphicBezelCircularText(
                circularTemplate: .init(),
                textProvider: CLKSimpleTextProvider(text: title)
            )
        case .graphicCircular:
            return CLKComplicationTemplateGraphicCircularImage(
                imageProvider: CLKFullColorImageProvider(fullColorImage: bigIcon)
            )
        case .graphicRectangular:
            return CLKComplicationTemplateGraphicRectangularStandardBody(
                headerTextProvider: CLKSimpleTextProvider(text: title),
                body1TextProvider: CLKSimpleTextProvider(text: "")
            )
        case .graphicExtraLarge:
            return CLKComplicationTemplateGraphicExtraLargeCircularImage(
                imageProvider: CLKFullColorImageProvider(fullColorImage: bigIcon)
            )
        @unknown default:
            fatalError("Unknown complication family: \(family)")
        }
    }
}
