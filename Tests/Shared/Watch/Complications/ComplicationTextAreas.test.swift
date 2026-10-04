import Foundation
@testable import Shared
import Testing

struct ComplicationTextAreasTests {
    @Test func everyAreaHasLocalizedDescriptionAndLabel() {
        for area in ComplicationTextAreas.allCases {
            #expect(!area.description.isEmpty)
            #expect(!area.label.isEmpty)
        }
        #expect(ComplicationTextAreas.InsideRing.label == L10n.Watch.Labels.ComplicationTextAreas.InsideRing.label)
        #expect(
            ComplicationTextAreas.Row3Column2.description
                == L10n.Watch.Labels.ComplicationTextAreas.Row3Column2.description
        )
    }

    @Test func slugStripsSpacesAndCommas() {
        #expect(ComplicationTextAreas.Row1Column1.slug == "Row1Column1")
        #expect(ComplicationTextAreas.InsideRing.slug == "InsideRing")
        #expect(ComplicationTextAreas.Body2.slug == "Body2")
        #expect(ComplicationTextAreas.Header.slug == "Header")
        for area in ComplicationTextAreas.allCases {
            #expect(!area.slug.contains(" "))
            #expect(!area.slug.contains(","))
        }
    }

    @Test func secondColumnsNameTheirFirstColumn() {
        #expect(ComplicationTextAreas.Row1Column2.firstColumnOfSameRow == .Row1Column1)
        #expect(ComplicationTextAreas.Row2Column2.firstColumnOfSameRow == .Row2Column1)
        #expect(ComplicationTextAreas.Row3Column2.firstColumnOfSameRow == .Row3Column1)
        #expect(ComplicationTextAreas.Row1Column1.firstColumnOfSameRow == nil)
        #expect(ComplicationTextAreas.Header.firstColumnOfSameRow == nil)
    }

    @Test func onlyLeadingAndTrailingAreGaugeEndLabels() {
        let gaugeEnds = Set(ComplicationTextAreas.allCases.filter(\.isGaugeEndLabel))
        #expect(gaugeEnds == [.Leading, .Trailing])
    }
}
