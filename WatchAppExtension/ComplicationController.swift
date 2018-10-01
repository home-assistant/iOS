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

        let realm = Realm.live()
        print("Realm is located at:", realm.configuration.fileURL!)

        let allComplications = realm.objects(WatchComplication.self)

        print("All configured complications", allComplications, allComplications.count, allComplications.first)

        let matchedFamily = ComplicationGroupMember(family: complication.family)

        print("matchedFamily", matchedFamily.rawValue)
        let pred = NSPredicate(format: "rawFamily == %@", matchedFamily.rawValue)
        guard let config = realm.objects(WatchComplication.self).filter(pred).first else {
            print("No configured complication found for \(matchedFamily.rawValue), returning family specific 404")
            // FIXME: Return a family specific template 404.
            handler(nil)
            return
        }

        print("complicationObjects", config)

        print("Providing template for", complication.family.description)

        if let template = config.CLKComplicationTemplate(family: complication.family) {
            handler(CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template))
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
