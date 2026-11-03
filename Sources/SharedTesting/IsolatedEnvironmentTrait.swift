@testable import Shared
import Testing

/// Gives each test case its own `AppEnvironment`, resolved through `withCurrent`, so what the test
/// assigns to `Current.*` is invisible to every other test and the test can run in parallel.
///
/// The override is task-local: it reaches everything the test calls, including structured child
/// tasks, but not work that hops to a dispatch queue, a PromiseKit callback or `Task.detached`.
/// Those paths read the global environment, which no isolated test ever changes. A test whose
/// subject still goes through them needs ``SharedStateTrait`` (`.sharedState`) instead.
///
/// The closure form configures the environment before the test body runs, which keeps the
/// override next to the suite declaration:
///
/// ```swift
/// @Suite(.isolatedEnvironment { $0.isTestFlight = false })
/// struct AppLabsVisibilityTests { … }
/// ```
public struct IsolatedEnvironmentTrait: SuiteTrait, TestTrait, TestScoping {
    private let configure: @Sendable (AppEnvironment) -> Void

    public var isRecursive: Bool { true }

    init(configure: @escaping @Sendable (AppEnvironment) -> Void) {
        self.configure = configure
    }

    public func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: @Sendable () async throws -> Void
    ) async throws {
        let environment = AppEnvironment.makeIsolated()
        configure(environment)
        try await withCurrent(environment) {
            try await function()
        }
    }
}

public extension Trait where Self == IsolatedEnvironmentTrait {
    /// A fresh `Current` for each test case, left at its defaults.
    static var isolatedEnvironment: Self { Self { _ in } }

    /// A fresh `Current` for each test case, with `configure` applied to it first.
    static func isolatedEnvironment(_ configure: @escaping @Sendable (AppEnvironment) -> Void) -> Self {
        Self(configure: configure)
    }
}
