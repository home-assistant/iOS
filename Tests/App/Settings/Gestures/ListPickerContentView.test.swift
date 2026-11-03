@testable import HomeAssistant
import SharedTesting
import SwiftUI
import Testing

/// The searchable list behind every `ListPicker`: tapping a row picks it, and a Labs item carries
/// its badge. The SwiftUI-preview samples are built too.
@MainActor
struct ListPickerContentViewTests {
    @Test func tappingARowPicksIt() async {
        var picked = ListPickerContent.Item(id: "1", title: "Swipe left")
        let content = ListPickerContent(sections: [
            .init(id: "gestures", title: "Gestures", items: [
                .init(id: "1", title: "Swipe left"),
                .init(id: "2", title: "Shake", subtitle: "Experimental", showsLabsLabel: true),
            ]),
        ])
        let driver = await SwiftUIScreenDriver.show(ListPickerContentView(
            title: "Gesture",
            selection: Binding(get: { picked }, set: { picked = $0 }),
            content: content
        ))
        defer { driver.close() }

        await driver.tapRow(IndexPath(item: 1, section: 0))
        #expect(picked.id == "2")
    }

    @Test func buildsThePreviewSamples() async {
        for sample in [
            AnyView(ListPickerPreview.searching),
            AnyView(ListPickerPreview.noResults),
            AnyView(ListPickerPreview.content),
        ] {
            let driver = await SwiftUIScreenDriver.show(sample, inNavigationStack: false)
            #expect(driver.sectionCount >= 1)
            driver.close()
        }
    }
}
