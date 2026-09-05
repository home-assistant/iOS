import Foundation

/// How far along one step of the migration is. Drives the spinner / checkmark on `AppMigrationStepRow`.
enum AppMigrationStepState: Equatable {
    case pending
    case running
    case done
    case failed
}
