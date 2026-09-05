import SwiftUI

/// Type shared by the watch corner view and the preview / snapshot rendering, so both draw the same
/// thing where the layout is theirs to decide.
public enum CornerComplicationTypography {
    /// The corner's own text when it sits flat in the corner tip rather than riding the curve: the big
    /// number ClockKit drew for a Graphic Corner's outer text, sized like the system's own corner gauge
    /// complications (UV Index, Battery). The curved variant is typeset by the system and has no font
    /// of its own.
    public static let flatTextFont = Font.system(size: 20, weight: .semibold)
}
