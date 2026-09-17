import Shared

extension Domain {
    /// Whether the entity's details fit a half-height sheet to begin with.
    ///
    /// These domains show a state row with history and activity underneath, or a single small
    /// control (a number, a select, a run button), so a medium sheet shows what matters and a drag
    /// reveals the rest. Domains with tall controls (a light's slider, a climate dial, a media
    /// player, a camera stream) and any domain not listed here open large straight away.
    var prefersCompactMoreInfoSheet: Bool {
        Self.compactMoreInfoDomains.contains(self)
    }

    static let compactMoreInfoDomains: Set<Domain> = [
        .aiTask,
        .airQuality,
        .alert,
        .assistSatellite,
        .automation,
        .binarySensor,
        .button,
        .calendar,
        .configurator,
        .counter,
        .date,
        .dateTime,
        .deviceTracker,
        .event,
        .geoLocation,
        .imageProcessing,
        .infrared,
        .inputButton,
        .inputDatetime,
        .inputNumber,
        .inputSelect,
        .inputText,
        .notify,
        .number,
        .person,
        .plant,
        .radioFrequency,
        .scene,
        .schedule,
        .select,
        .sensor,
        .stt,
        .sun,
        .tag,
        .text,
        .time,
        .tts,
        .wakeWord,
        .zone,
    ]
}
