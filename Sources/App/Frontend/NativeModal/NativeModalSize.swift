import Foundation

/// How much room the frontend asks a native modal for. The app decides what that means on its
/// platform; on iPhone it picks the sheet's detents.
enum NativeModalSize: String {
    /// Half the screen to begin with, draggable to the whole of it.
    case compact
    /// The whole screen.
    case full

    /// Anything the frontend did not name takes the whole screen.
    init(payload: Any?) {
        self = (payload as? String).flatMap(NativeModalSize.init(rawValue:)) ?? .full
    }
}
