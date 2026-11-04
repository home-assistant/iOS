import Foundation
import SFSafeSymbols

public extension Domain {
    /// The SF Symbol that stands in for this domain in an App Intents picker.
    ///
    /// Pickers draw an icon per row as the list scrolls, and rendering the entity's own Material
    /// Design glyph to an image there made the Shortcuts app stutter. A symbol name costs nothing
    /// to pass and the system draws it, so the picker stays smooth. The trade is per-domain rather
    /// than per-entity accuracy: an entity whose icon was customized in Home Assistant shows its
    /// domain's symbol here. Spotlight results and the result card still draw the real glyph, where
    /// the cost is paid once rather than per row.
    var sfSymbolName: String {
        symbol.rawValue
    }

    private var symbol: SFSymbol {
        switch self {
        case .light: .lightbulb
        case .switch, .inputBoolean: .powerCircle
        case .fan: .fanblades
        case .cover: .blindsHorizontalClosed
        case .valve: .spigot
        case .lock: .lock
        case .climate, .waterHeater: .thermometerMedium
        case .humidifier: .humidity
        case .mediaPlayer: .playCircle
        case .camera: .videoCircle
        case .scene: .moonStars
        case .script, .automation: .playSquare
        case .sensor, .binarySensor, .airQuality: .sensorTagRadiowavesForward
        case .person, .deviceTracker: .personCircle
        case .zone, .geoLocation: .mappinCircle
        case .calendar, .schedule, .date, .dateTime, .time: .calendar
        case .todo: .checklist
        case .alarmControlPanel: .shield
        case .siren, .alert: .bellBadge
        case .vacuum, .lawnMower: .sparkles
        case .weather, .sun: .cloudSun
        case .update: .arrowTriangle2Circlepath
        case .timer, .counter: .timer
        case .button, .inputButton: .handTap
        case .number, .inputNumber: .numberCircle
        case .select, .inputSelect: .listBullet
        case .text, .inputText, .inputDatetime: .characterCursorIbeam
        case .group: .squareStack
        case .remote: .avRemote
        case .image, .imageProcessing: .photo
        case .plant: .leaf
        case .tag: .tag
        case .conversation, .assistSatellite, .stt, .tts, .wakeWord, .aiTask: .bubbleLeftAndBubbleRight
        case .notify: .bellCircle
        case .event: .bolt
        case .infrared, .radioFrequency: .dotRadiowavesLeftAndRight
        case .configurator: .gearshape
        }
    }
}
