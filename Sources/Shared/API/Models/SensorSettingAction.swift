import Foundation

/// An app-level flow a sensor can offer from its detail screen, as opposed to a value the row
/// edits. `Shared` names the flow, the app decides what it looks like and runs it, so sensor
/// definitions stay free of UI.
public enum SensorSettingAction: Equatable {
    /// Creates an MJPEG IP Camera config entry pointed at this device's camera stream server,
    /// after asking which server to add it to when there is more than one.
    case addCameraStreamToHomeAssistant
}
