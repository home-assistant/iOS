//
//  ComplicationController.swift
//  WatchApp Extension
//
//  Created by Robert Trencheny on 9/24/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import ClockKit

class ComplicationController: NSObject, CLKComplicationDataSource {

    // MARK: - Timeline Configuration

    func getSupportedTimeTravelDirections(for complication: CLKComplication,
                                          withHandler handler: @escaping (CLKComplicationTimeTravelDirections) -> Void) {
        handler([.backward, .forward])
    }

    func getTimelineStartDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        handler(nil)
    }

    func getTimelineEndDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        handler(nil)
    }

    func getPrivacyBehavior(for complication: CLKComplication,
                            withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
        handler(.showOnLockScreen)
    }

    // MARK: - Timeline Population

    func getCurrentTimelineEntry(for complication: CLKComplication,
                                 withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        // Call the handler with the current timeline entry

        print("Providing template for", complication.family.description)

        switch complication.family {
        case .modularSmall:
            let template = CLKComplicationTemplateModularSmallStackText()
            template.line1TextProvider = CLKSimpleTextProvider(text: "Line 1", shortText: "L1")
            template.line2TextProvider = CLKSimpleTextProvider(text: "Line 2", shortText: "L2")
            handler(CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template))
            return
        case .circularSmall:
            let template = CLKComplicationTemplateCircularSmallSimpleText()
            template.textProvider = CLKSimpleTextProvider(text: "Line 1", shortText: "L1")
            handler(CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template))
            return
        case .extraLarge:
            let template = CLKComplicationTemplateExtraLargeStackText()
            template.line1TextProvider = CLKSimpleTextProvider(text: "Line 1", shortText: "L1")
            template.line2TextProvider = CLKSimpleTextProvider(text: "Line 2", shortText: "L2")
            handler(CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template))
            return
        case .graphicBezel:
            let template = CLKComplicationTemplateGraphicBezelCircularText()
            // FIXME: Add circTemplate
            template.textProvider = CLKSimpleTextProvider(text: "Line 1", shortText: "L1")
            handler(CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template))
            return
        case .graphicCircular:
            let template = CLKComplicationTemplateGraphicCircularClosedGaugeText()
            template.centerTextProvider = CLKSimpleTextProvider(text: "Line 1", shortText: "L1")
            template.gaugeProvider = CLKSimpleGaugeProvider(style: .ring, gaugeColor: .orange, fillFraction: 0.623)
            handler(CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template))
            return
        case .graphicCorner:
            let template = CLKComplicationTemplateGraphicCornerStackText()
            template.outerTextProvider = CLKSimpleTextProvider(text: "Line 1", shortText: "L1")
            template.innerTextProvider = CLKSimpleTextProvider(text: "Line 2", shortText: "L2")
            handler(CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template))
            return
        case .graphicRectangular:
            let template = CLKComplicationTemplateGraphicRectangularStandardBody()
            template.headerTextProvider = CLKSimpleTextProvider(text: "Line 1", shortText: "L1")
            template.body1TextProvider = CLKSimpleTextProvider(text: "Line 2", shortText: "L2")
            template.body2TextProvider = CLKSimpleTextProvider(text: "Line 3", shortText: "L3")
            handler(CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template))
            return
        case .modularLarge:
            let template = CLKComplicationTemplateModularLargeStandardBody()
            template.headerTextProvider = CLKSimpleTextProvider(text: "Line 1", shortText: "L1")
            template.body1TextProvider = CLKSimpleTextProvider(text: "Line 2", shortText: "L2")
            template.body2TextProvider = CLKSimpleTextProvider(text: "Line 3", shortText: "L3")
            handler(CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template))
            return
        case .utilitarianLarge:
            let template = CLKComplicationTemplateUtilitarianLargeFlat()
            template.textProvider = CLKSimpleTextProvider(text: "Line 1", shortText: "L1")
            handler(CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template))
            return
        case .utilitarianSmall, .utilitarianSmallFlat:
            let template = CLKComplicationTemplateUtilitarianSmallFlat()
            template.textProvider = CLKSimpleTextProvider(text: "Line 1", shortText: "L1")
            handler(CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template))
            return
        default:
            print("Not providing template for", complication.family.description)
            handler(nil)
        }
    }

    func getTimelineEntries(for complication: CLKComplication, before date: Date, limit: Int,
                            withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        // Call the handler with the timeline entries prior to the given date
        handler(nil)
    }

    func getTimelineEntries(for complication: CLKComplication, after date: Date, limit: Int,
                            withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        // Call the handler with the timeline entries after to the given date
        handler(nil)
    }

    // MARK: - Placeholder Templates

    func getLocalizableSampleTemplate(for complication: CLKComplication,
                                      withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        // This method will be called once per supported complication, and the results will be cached
        handler(nil)
    }

}

extension CLKComplicationFamily {
    var description: String {
        switch self {
        case .circularSmall:
            return "Circular Small"
        case .extraLarge:
            return "Extra Large"
        case .graphicBezel:
            return "Graphic Bezel"
        case .graphicCircular:
            return "Graphic Circular"
        case .graphicCorner:
            return "Graphic Corner"
        case .graphicRectangular:
            return "Graphic Rectangular"
        case .modularLarge:
            return "Modular Large"
        case .modularSmall:
            return "Modular Small"
        case .utilitarianLarge:
            return "Utilitarian Large"
        case .utilitarianSmall:
            return "Utilitarian Small"
        case .utilitarianSmallFlat:
            return "Utilitarian Small Flat"
        default:
            return "unknown"
        }
    }
}
