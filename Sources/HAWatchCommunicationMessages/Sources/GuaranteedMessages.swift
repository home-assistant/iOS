import Foundation

/// Identifiers for reliable, queued messages (backed by `transferUserInfo`). Raw values cross the
/// wire — never repurpose them.
///
/// Note: the guaranteed config-pull flow currently reuses `InteractiveImmediateMessages.watchConfig`
/// and `InteractiveImmediateResponses.watchConfigResponse` as guaranteed-message identifiers rather
/// than cases from this enum.
public enum GuaranteedMessages: String, CaseIterable {
    case sync
}
