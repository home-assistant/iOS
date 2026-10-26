import Foundation
import PromiseKit

/// What both Focus sensors report: which named Focus is on, and whether any Focus is on.
///
/// Each half has its own source, and the newest answer each source gave is the one that counts:
/// - The name is only ever told by the Focus Filter, see `FocusFilterWrapper`.
/// - Whether a Focus is on is told by iOS's Focus status, see `FocusStatusWrapper`.
///
/// A named Focus is on whatever the status says. Focus status is shared per Focus, and iOS
/// reports "not focused" for one that doesn't share it or that allows this app's notifications,
/// so the filter is the only way such a Focus is seen at all.
///
/// Every process resolves from the same stored answers, so the app and its extensions report the
/// same thing. Only the app can ask iOS, and it stores each answer it gets. The extensions don't
/// rebuild a Focus state from a push the app has since seen past.
public struct FocusReport: Equatable {
    /// The name the Focus Filter gave for the Focus that is on, or `nil` while no Focus with a
    /// name picked in the filter is on.
    public let name: String?
    /// Whether any Focus is on, or `nil` when nothing this process can read says.
    public let isFocused: Bool?

    public init(name: String?, isFocused: Bool?) {
        self.name = name
        self.isFocused = isFocused
    }

    static func resolve(filter: FocusFilterState?, status: FocusStatusObservation?) -> FocusReport {
        let name = filter?.name.flatMap { $0.isEmpty ? nil : $0 }
        return FocusReport(name: name, isFocused: name != nil ? true : status?.isFocused)
    }

    /// Asks iOS for fresh answers where this process can, stores them, and resolves the report
    /// from the newest answers every process stored.
    public static func current() -> Promise<FocusReport> {
        Promise { seal in
            Task {
                await Current.focusFilter.readFromIOS()
                Current.focusStatus.readFromIOS()

                let report = resolve(
                    filter: Current.focusFilter.activeFocusState(),
                    status: Current.focusStatus.latest()
                )

                // Both Focus sensors stand on this, and each answer comes from a different process
                // at a different moment, so all of them are logged next to the result to make a
                // wrong report readable after the fact.
                Current.Log.info {
                    "focus report: \(report) from " +
                        "filter[run(\(describe(Current.focusFilter.runs.value))) " +
                        "reading(\(describe(Current.focusFilter.readings.value)))] " +
                        "status[push(\(describe(Current.focusStatus.pushes.value))) " +
                        "reading(\(describe(Current.focusStatus.readings.value)))]"
                }

                seal.fulfill(report)
            }
        }
    }

    private static func describe(_ state: FocusFilterState?) -> String {
        state.map { "\($0.name ?? "<none>") at \($0.date)" } ?? "<never>"
    }

    private static func describe(_ observation: FocusStatusObservation?) -> String {
        observation.map { "\(String(describing: $0.isFocused)) at \($0.date)" } ?? "<never>"
    }
}
