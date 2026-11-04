import Foundation

@available(iOS 27.0, *)
enum ReminderListResolution {
    case noLists
    case only(ReminderListSchemaEntity)
    case choice([ReminderListSchemaEntity])

    init(lists: [ReminderListSchemaEntity]) {
        switch lists.count {
        case 0: self = .noLists
        case 1: self = .only(lists[0])
        default: self = .choice(lists)
        }
    }
}
