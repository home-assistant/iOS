import Foundation

/// How large `AssistVoiceOrbView` draws itself. The palette, the timings and the way the orb reacts to
/// the microphone level are the same in both; only the lengths change.
public enum AssistVoiceOrbSize {
    /// The orb as it sits in the phone, tablet and Mac input row, in place of the microphone button.
    case regular
    /// The Apple Watch listening screen, where the orb is the screen's subject rather than one control
    /// in a row — so it draws a little larger than `regular` despite the much smaller display.
    case watch
}
