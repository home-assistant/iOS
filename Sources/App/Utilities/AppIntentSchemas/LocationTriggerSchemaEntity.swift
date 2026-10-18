import AppIntents
import CoreLocation
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
        // A `PlaceDescriptor` must carry a representation that describes something and traps
        // otherwise -- an empty address counts as nothing. There is no place to name, so this is
        // the null coordinate rather than an invented address a person could end up reading.
        self.place = PlaceDescriptor(representations: [.coordinate(CLLocationCoordinate2D())], commonName: nil)
        self.event = .arrive
    }
}
