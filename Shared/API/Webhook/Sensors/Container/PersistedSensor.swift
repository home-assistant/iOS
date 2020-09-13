import RealmSwift
import ObjectMapper

class PersistedSensor: Object {
    @objc dynamic var uniqueID: String
    @objc dynamic var updated: Date
    @objc private dynamic var sensorData: Data
    var sensor: WebhookSensor {
        get {
            let object = (try? JSONSerialization.jsonObject(with: sensorData, options: [])) ?? [:]
            return Mapper<WebhookSensor>().map(JSONObject: object) ?? WebhookSensor()
        }
        set {
            assert(newValue.UniqueID == uniqueID)
            sensorData = Self.data(for: newValue)
            updated = Current.date()
        }
    }

    override class func primaryKey() -> String? {
        #keyPath(uniqueID)
    }

    private static func data(for sensor: WebhookSensor) -> Data {
        let mapper = Mapper<WebhookSensor>(
            context: WebhookSensorContext(update: false),
            shouldIncludeNilValues: true
        )
        return (try? JSONSerialization.data(
            withJSONObject: mapper.toJSON(sensor),
            options: [.sortedKeys]
        )) ?? Data()
    }

    init?(sensor: WebhookSensor) {
        if let uniqueID = sensor.UniqueID {
            self.uniqueID = uniqueID
        } else {
            return nil
        }

        self.sensorData = Self.data(for: sensor)
        self.updated = Current.date()
        super.init()
    }

    @available(*, unavailable)
    required init() {
        // this gets invoked by the realm runtime only
        self.uniqueID = ""
        self.sensorData = Data()
        self.updated = Current.date()
    }
}
