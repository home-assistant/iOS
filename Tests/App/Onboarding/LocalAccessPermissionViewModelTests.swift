import Combine
import Foundation
@testable import HomeAssistant
import Shared
import Testing

@Suite("LocalAccessPermissionViewModel Tests")
struct LocalAccessPermissionViewModelTests {
    // MARK: - Initialization Tests

    @Test("Initialization with default selection")
    func initializationWithDefaultSelection() async throws {
        let viewModel = LocalAccessPermissionViewModel()

        #expect(viewModel.selection == .mostSecure)
    }

    @Test("Initialization with explicit nil selection")
    func initializationWithExplicitNilSelection() async throws {
        let viewModel = LocalAccessPermissionViewModel(initialSelection: nil)

        #expect(viewModel.selection == .mostSecure)
    }

    @Test("Initialization with most secure selection")
    func initializationWithMostSecureSelection() async throws {
        let viewModel = LocalAccessPermissionViewModel(initialSelection: .mostSecure)

        #expect(viewModel.selection == .mostSecure)
    }

    @Test("Initialization with less secure selection")
    func initializationWithLessSecureSelection() async throws {
        let viewModel = LocalAccessPermissionViewModel(initialSelection: .lessSecure)

        #expect(viewModel.selection == .lessSecure)
    }

    @Test("Initialization with undefined selection")
    func initializationWithUndefinedSelection() async throws {
        let viewModel = LocalAccessPermissionViewModel(initialSelection: .undefined)

        #expect(viewModel.selection == .undefined)
    }
}
