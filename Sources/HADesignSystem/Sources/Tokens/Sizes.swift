import Foundation

/// Layout limits that are not spacing or radius.
///
/// Frontend counterpart: none — the frontend constrains reading width in CSS at each layout rather
/// than through a shared token.
public enum Sizes {
    public static var maxWidthForLargerScreens: CGFloat = 600
}
