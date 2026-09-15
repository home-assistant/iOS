import Foundation

/// What a tile writes on its second line, the frontend's `state_content`.
///
/// Most tiles just show the state. The ones the home strategy configures differently say so: a
/// favourite names the room it is in, because it could be from anywhere in the house, and the
/// weather tile leads with the temperature.
public enum HomeTileStateContent: String, Equatable, Sendable {
    case state
    case temperature
    case areaName
}
