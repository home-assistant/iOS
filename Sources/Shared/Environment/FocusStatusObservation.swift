import Foundation

/// One answer iOS gave to "is a Focus on", with when it was given, so answers taken by different
/// processes at different moments can be ordered and the newest one used.
///
/// Stored in the app group under keys that predate this type. JSON decoding ignores the fields an
/// older build stored alongside these two, so the last status an older build received still reads.
public struct FocusStatusObservation: Codable, Equatable {
    /// `true` while a Focus that silences this app is on, `false` otherwise, and `nil` when iOS
    /// gave no answer, which is what it does for an app without the Focus status permission.
    public var isFocused: Bool?
    /// When iOS gave the answer.
    public var date: Date

    public init(isFocused: Bool?, date: Date) {
        self.isFocused = isFocused
        self.date = date
    }
}
