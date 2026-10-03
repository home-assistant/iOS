#if os(macOS)
/// Whether the app is in front, mirroring `UIApplication.State` for code shared with the iOS app. A Mac
/// app keeps running at full speed when it is not frontmost, so it is never in the background.
public enum ApplicationState {
    case active
    case inactive
    case background
}

#elseif os(iOS)
import UIKit

public typealias ApplicationState = UIApplication.State
#endif
