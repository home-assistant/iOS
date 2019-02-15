//
//  ComplicationController.swift
//  WatchApp Extension
//
//  Created by Robert Trencheny on 9/24/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import ClockKit
import RealmSwift

class ComplicationController: NSObject, CLKComplicationDataSource {

    // MARK: - Timeline Configuration

    func getSupportedTimeTravelDirections(for complication: CLKComplication, withHandler
        handler: @escaping (CLKComplicationTimeTravelDirections) -> Void) {
        handler([])
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

        let matchedFamily = ComplicationGroupMember(family: complication.family)

        let realm = Realm.live()

        let pred = NSPredicate(format: "rawFamily == %@", matchedFamily.rawValue)
        guard let config = realm.objects(WatchComplication.self).filter(pred).first else {
            print("No configured complication found for \(matchedFamily.rawValue), returning family specific error")
            handler(CLKComplicationTimelineEntry(date: Date(), complicationTemplate: matchedFamily.errorTemplate!))
            return
        }

        print("complicationObjects", config)

        guard let template = config.CLKComplicationTemplate(family: complication.family) else {
            print("Unable to generate template for \(matchedFamily.rawValue), returning family specific error")
            handler(CLKComplicationTimelineEntry(date: Date(), complicationTemplate: matchedFamily.errorTemplate!))
            return
        }

        print("Generated template for", complication.family.description, template)

        handler(CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template))
    }

    // MARK: - Placeholder Templates

    func getLocalizableSampleTemplate(for complication: CLKComplication,
                                      withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        // This method will be called once per supported complication, and the results will be cached

        print("Get sample template!", ComplicationGroupMember(family: complication.family).description)
        handler(ComplicationGroupMember(family: complication.family).errorTemplate)
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
