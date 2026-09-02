import Foundation

/// The one corner radius the app's older screens share.
///
/// Frontend counterpart: `--ha-border-radius-*` in the frontend's token set, ported more fully as
/// `DesignSystem.CornerRadius`. This predates that and is kept for the call sites still on it.
public enum HACornerRadius {
    public static let standard: CGFloat = 8
}
