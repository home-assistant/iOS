@testable import HomeAssistant

import Testing

struct WidgetStateValueColoringTests {
    @Test("Colors finite negative values when the preference is enabled")
    func colorsNegativeValues() {
        #expect(
            WidgetStateValueColoring.colorHex(
                numericValue: -12.52,
                colorNegativeNumericStates: true
            ) == WidgetStateValueColoring.negativeStateColorHex
        )
    }

    @Test("Leaves non-negative and non-finite values unchanged")
    func leavesOtherValuesUnchanged() {
        for value in [0.0, 12.52, .infinity, -.infinity, .nan] {
            #expect(
                WidgetStateValueColoring.colorHex(
                    numericValue: value,
                    colorNegativeNumericStates: true
                ) == nil
            )
        }
    }

    @Test("Leaves negative values unchanged when the preference is disabled")
    func respectsPreference() {
        #expect(
            WidgetStateValueColoring.colorHex(
                numericValue: -12.52,
                colorNegativeNumericStates: false
            ) == nil
        )
    }
}
