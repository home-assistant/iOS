import ClockKit
import Shared

class ComplicationController: NSObject, CLKComplicationDataSource {
    // Helpful resources
    // https://github.com/LoopKit/Loop/issues/816
    // https://crunchybagel.com/detecting-which-complication-was-tapped/

    private func complicationModel(for complication: CLKComplication) -> AppWatchComplication? {
        // Helper function to get a complication using the correct ID depending on watchOS version

        let model: AppWatchComplication?

        do {
            if complication.identifier != CLKDefaultComplicationIdentifier {
                // existing complications that were configured pre-7 have no identifier set
                // so we can only access the value if it's a valid one. otherwise, fall back to old matching behavior.
                
                // Fetch from GRDB
                model = try Current.database().read { db in
                    try AppWatchComplication.fetch(identifier: complication.identifier, from: db)
                }
            } else {
                // we migrate pre-existing complications, and when still using watchOS 6 create new ones,
                // with the family as the identifier, so we can rely on this code path for older OS and older complications
                let matchedFamily = ComplicationGroupMember(family: complication.family)
                
                // Fetch from GRDB using family rawValue
                model = try Current.database().read { db in
                    try AppWatchComplication.fetch(identifier: matchedFamily.rawValue, from: db)
                }
            }
        } catch {
            Current.Log.error("Failed to fetch complication from GRDB: \(error.localizedDescription)")
            model = nil
        }

        return model
    }
    
    /// Converts AppWatchComplication to WatchComplication for accessing business logic methods
    private func toWatchComplication(_ appComplication: AppWatchComplication) -> WatchComplication? {
        try? WatchComplication(JSON: [
            "identifier": appComplication.identifier,
            "serverIdentifier": appComplication.serverIdentifier as Any,
            "Family": appComplication.rawFamily,
            "Template": appComplication.rawTemplate,
            "Data": appComplication.complicationData,
            "CreatedAt": appComplication.createdAt.timeIntervalSince1970,
            "name": appComplication.name as Any,
            "IsPublic": true // Default value, can be added to AppWatchComplication if needed
        ])
    }

    private func template(for complication: CLKComplication) -> CLKComplicationTemplate {
        MaterialDesignIcons.register()

        let template: CLKComplicationTemplate

        if let appModel = complicationModel(for: complication),
           let watchModel = toWatchComplication(appModel),
           let generated = watchModel.CLKComplicationTemplate(family: complication.family) {
            template = generated
        } else if complication.identifier == AssistDefaultComplication.defaultComplicationId {
            template = AssistDefaultComplication.createAssistTemplate(for: complication.family)
        } else {
            Current.Log.info {
                "no configured template for \(complication.identifier), providing placeholder"
            }

            template = ComplicationGroupMember(family: complication.family)
                .fallbackTemplate(for: complication.identifier)
        }

        return template
    }

    // MARK: - Timeline Configuration

    func getPrivacyBehavior(
        for complication: CLKComplication,
        withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void
    ) {
        if let appModel = complicationModel(for: complication),
           let watchModel = toWatchComplication(appModel) {
            if watchModel.IsPublic == false {
                handler(.hideOnLockScreen)
            } else {
                handler(.showOnLockScreen)
            }
        } else {
            // Default to showing on lock screen if no model found
            handler(.showOnLockScreen)
        }
    }

    // MARK: - Timeline Population

    func getCurrentTimelineEntry(
        for complication: CLKComplication,
        withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void
    ) {
        Current.Log.verbose {
            "Providing template for \(complication.identifier) family \(complication.family.description)"
        }

        let date = Date().encodedForComplication(family: complication.family) ?? Date()
        handler(.init(date: date, complicationTemplate: template(for: complication)))
    }

    // MARK: - Placeholder Templates

    func getLocalizableSampleTemplate(
        for complication: CLKComplication,
        withHandler handler: @escaping (CLKComplicationTemplate?) -> Void
    ) {
        handler(template(for: complication))
    }

    // MARK: - Complication Descriptors

    func getComplicationDescriptors(handler: @escaping ([CLKComplicationDescriptor]) -> Void) {
        // Fetch complications from GRDB
        let configured: [CLKComplicationDescriptor]
        do {
            let appComplications = try Current.database().read { db in
                try AppWatchComplication.fetchAll(from: db)
            }
            
            // Convert to WatchComplication and map to descriptors
            configured = appComplications.compactMap { appComplication in
                guard let watchComplication = toWatchComplication(appComplication) else {
                    Current.Log.error("Failed to convert AppWatchComplication to WatchComplication")
                    return nil
                }
                return watchComplication.complicationDescriptor
            }
        } catch {
            Current.Log.error("Failed to fetch complications from GRDB: \(error.localizedDescription)")
            configured = []
        }

        let placeholders = ComplicationGroupMember.allCases
            .map(\.placeholderComplicationDescriptor)

        let assistDefaultComplicationDescriptor = [AssistDefaultComplication.descriptor]

        handler(configured + placeholders + assistDefaultComplicationDescriptor)
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
