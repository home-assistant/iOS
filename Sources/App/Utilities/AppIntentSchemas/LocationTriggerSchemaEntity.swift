import AppIntents
import Foundation
import GeoToolbox

/// Home Assistant todo items have no location trigger, so this only ever appears as nil. It exists
/// because the schema requires the property to have this shape.
@available(iOS 27.0, *)
@AppEntity(schema: .reminders.locationTrigger)
struct LocationTriggerSchemaEntity: TransientAppEntity {
    var place: PlaceDescriptor
    var event: LocationTriggerEventSchemaEnum

    var displayRepresentation: DisplayRepresentation {
        .init(title: .init("app_intents.reminders.location_trigger.name", defaultValue: "Location"))
    }

    init() {
        self.place = PlaceDescriptor(representations: [], commonName: nil)
        self.event = .arrive
    }
}
