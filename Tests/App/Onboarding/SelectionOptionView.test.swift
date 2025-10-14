@testable import HomeAssistant
import SnapshotTesting
import SwiftUI
import Testing

struct SelectionOptionViewTests {
    // MARK: - Test Data

    private var sampleOptions: [SelectionOption] {
        [
            SelectionOption(
                value: "secure",
                title: "Most secure: Allow this app to know when you're home",
                subtitle: "This provides the best security features",
                isRecommended: true
            ),
            SelectionOption(
                value: "less_secure",
                title: "Less secure: Do not allow this app to know when you're home",
                subtitle: "Limited functionality but more privacy",
                isRecommended: false
            ),
            SelectionOption(
                value: "custom",
                title: "Custom Configuration",
                subtitle: nil,
                isRecommended: false
            ),
        ]
    }

    // MARK: - Single Selection Tests

    @MainActor @Test func testSingleSelectionEmptyStateSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }

        let view = AnyView(
            SelectionOptionView(options: sampleOptions, selection: .constant(nil))
                .padding()
        )

        assertLightDarkSnapshots(of: view, named: "single-selection-empty")
    }

    @MainActor @Test func testSingleSelectionWithSelectedItemSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }

        let view = AnyView(
            SelectionOptionView(options: sampleOptions, selection: .constant("secure"))
                .padding()
        )

        assertLightDarkSnapshots(of: view, named: "single-selection-selected")
    }

    @MainActor @Test func testSingleSelectionRecommendedItemSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }

        let view = AnyView(
            SelectionOptionView(options: sampleOptions, selection: .constant("secure"))
                .padding()
        )

        assertLightDarkSnapshots(of: view, named: "single-selection-recommended")
    }

    // MARK: - Multiple Selection Tests

    @MainActor @Test func testMultipleSelectionEmptyStateSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }

        let view = AnyView(
            SelectionOptionView(options: sampleOptions, multipleSelection: .constant([]))
                .padding()
        )

        assertLightDarkSnapshots(of: view, named: "multiple-selection-empty")
    }

    @MainActor @Test func testMultipleSelectionWithSelectedItemsSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }

        let view = AnyView(
            SelectionOptionView(options: sampleOptions, multipleSelection: .constant(["secure", "custom"]))
                .padding()
        )

        assertLightDarkSnapshots(of: view, named: "multiple-selection-selected")
    }

    @MainActor @Test func testMultipleSelectionRecommendedItemSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }

        let view = AnyView(
            SelectionOptionView(options: sampleOptions, multipleSelection: .constant(["secure"]))
                .padding()
        )

        assertLightDarkSnapshots(of: view, named: "multiple-selection-recommended")
    }

    // MARK: - Edge Cases

    @MainActor @Test func testSingleOptionSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }

        let singleOption = [
            SelectionOption(
                value: "only_option",
                title: "Only Available Option",
                subtitle: "This is the only choice available",
                isRecommended: true
            ),
        ]

        let view = AnyView(
            SelectionOptionView(options: singleOption, selection: .constant(nil))
                .padding()
        )

        assertLightDarkSnapshots(of: view, named: "single-option")
    }

    @MainActor @Test func testLongTextContentSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }

        let longTextOptions = [
            SelectionOption(
                value: "long_title",
                title: "This is a very long title that should wrap to multiple lines and test how the layout handles extensive text content in the selection option view",
                subtitle: "This is also a very long subtitle that provides additional context and information about the selection option, testing how subtitles handle multiline text and proper spacing within the component layout",
                isRecommended: true
            ),
            SelectionOption(
                value: "short",
                title: "Short",
                subtitle: "Brief",
                isRecommended: false
            ),
        ]

        let view = AnyView(
            SelectionOptionView(options: longTextOptions, selection: .constant("long_title"))
                .padding()
                .frame(maxWidth: 320) // Constrain width to force wrapping
        )

        assertLightDarkSnapshots(of: view, named: "long-text-content")
    }

    @MainActor @Test func testOptionsWithoutSubtitlesSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }

        let optionsWithoutSubtitles = [
            SelectionOption(value: "option1", title: "First Option", isRecommended: true),
            SelectionOption(value: "option2", title: "Second Option"),
            SelectionOption(value: "option3", title: "Third Option"),
        ]

        let view = AnyView(
            SelectionOptionView(options: optionsWithoutSubtitles, multipleSelection: .constant(["option1", "option3"]))
                .padding()
        )

        assertLightDarkSnapshots(of: view, named: "options-without-subtitles")
    }
}

// MARK: - Test Extensions

extension SelectionOptionViewTests {
    // Test the SelectionOption model itself
    @Test func testSelectionOptionEquality() async throws {
        let option1 = SelectionOption(value: "test", title: "Test", subtitle: "Subtitle", isRecommended: true)
        let option2 = SelectionOption(value: "test", title: "Test", subtitle: "Subtitle", isRecommended: true)

        // They should not be equal because they have different UUIDs
        #expect(option1 != option2)
        #expect(option1.value == option2.value)
        #expect(option1.title == option2.title)
        #expect(option1.subtitle == option2.subtitle)
        #expect(option1.isRecommended == option2.isRecommended)
    }

    @Test func testSelectionOptionDefaultValues() async throws {
        let option = SelectionOption(value: "test", title: "Test Title")

        #expect(option.value == "test")
        #expect(option.title == "Test Title")
        #expect(option.subtitle == nil)
        #expect(option.isRecommended == false)
    }

    @Test func testSelectionOptionHashable() async throws {
        let option1 = SelectionOption(value: "test", title: "Test")
        let option2 = SelectionOption(value: "test", title: "Test")

        let set = Set([option1, option2])
        // Should contain both options since they have different IDs
        #expect(set.count == 2)
    }
}
