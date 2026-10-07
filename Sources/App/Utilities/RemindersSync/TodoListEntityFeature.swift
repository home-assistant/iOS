import Foundation

/// Mirror of Home Assistant's `TodoListEntityFeature` bitmask, read from a todo entity's
/// `supported_features` attribute. Todo lists only support a subset of the optional item fields
/// (e.g. the Shopping List integration has no descriptions or due dates), and the todo services
/// fail when they receive a field the entity can't store.
struct TodoListEntityFeature: OptionSet {
    let rawValue: Int

    static let createItem = TodoListEntityFeature(rawValue: 1)
    static let deleteItem = TodoListEntityFeature(rawValue: 2)
    static let updateItem = TodoListEntityFeature(rawValue: 4)
    static let moveItem = TodoListEntityFeature(rawValue: 8)
    static let setDueDateOnItem = TodoListEntityFeature(rawValue: 16)
    static let setDueDatetimeOnItem = TodoListEntityFeature(rawValue: 32)
    static let setDescriptionOnItem = TodoListEntityFeature(rawValue: 64)
}
