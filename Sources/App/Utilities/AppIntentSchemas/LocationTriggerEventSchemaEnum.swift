import AppIntents
import Foundation

/// Home Assistant has no location triggers, so no case is ever produced; the schema names both.
@available(iOS 27.0, *)
@AppEnum(schema: .reminders.locationTriggerEvent)
enum LocationTriggerEventSchemaEnum: String {
    case arrive
    case depart

    static let caseDisplayRepresentations: [LocationTriggerEventSchemaEnum: DisplayRepresentation] = [
        .arrive: .init(title: .init("app_intents.reminders.location_trigger.arrive", defaultValue: "Arriving")),
        .depart: .init(title: .init("app_intents.reminders.location_trigger.depart", defaultValue: "Leaving")),
    ]
}
