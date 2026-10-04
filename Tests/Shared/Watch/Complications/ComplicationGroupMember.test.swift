import Foundation
@testable import Shared
import Testing

struct ComplicationGroupMemberTests {
    @Test func initFromNameRoundTripsEveryRawValue() {
        for member in ComplicationGroupMember.allCases {
            #expect(ComplicationGroupMember(name: member.rawValue) == member)
        }
    }

    @Test func initFromUnknownNameFallsBackToCircularSmall() {
        #expect(ComplicationGroupMember(name: "notAFamily") == .circularSmall)
        #expect(ComplicationGroupMember(name: "") == .circularSmall)
    }

    @Test func everyMemberHasLocalizedStrings() {
        for member in ComplicationGroupMember.allCases {
            #expect(!member.name.isEmpty)
            #expect(!member.shortName.isEmpty)
            #expect(!member.description.isEmpty)
        }
        #expect(
            ComplicationGroupMember.graphicBezel.shortName
                == L10n.Watch.Labels.ComplicationGroupMember.GraphicBezel.shortName
        )
        #expect(
            ComplicationGroupMember.utilitarianSmallFlat.name
                == L10n.Watch.Labels.ComplicationGroupMember.UtilitarianSmallFlat.name
        )
        // The descriptions are deliberately cross-wired in the source; pin that down.
        #expect(
            ComplicationGroupMember.modularSmall.description
                == L10n.Watch.Labels.ComplicationGroupMember.GraphicBezel.description
        )
        #expect(
            ComplicationGroupMember.graphicRectangular.description
                == L10n.Watch.Labels.ComplicationGroupMember.UtilitarianSmallFlat.description
        )
    }

    @Test func groupsMatchTheFamilyKind() {
        #expect(ComplicationGroupMember.circularSmall.group == .circularSmall)
        #expect(ComplicationGroupMember.extraLarge.group == .extraLarge)
        #expect(ComplicationGroupMember.graphicBezel.group == .graphic)
        #expect(ComplicationGroupMember.graphicCircular.group == .graphic)
        #expect(ComplicationGroupMember.graphicCorner.group == .graphic)
        #expect(ComplicationGroupMember.graphicRectangular.group == .graphic)
        #expect(ComplicationGroupMember.modularLarge.group == .modular)
        #expect(ComplicationGroupMember.modularSmall.group == .modular)
        #expect(ComplicationGroupMember.utilitarianLarge.group == .utilitarian)
        #expect(ComplicationGroupMember.utilitarianSmall.group == .utilitarian)
        #expect(ComplicationGroupMember.utilitarianSmallFlat.group == .utilitarian)
    }

    @Test func everyTemplateBelongsToTheMemberThatListsIt() {
        for member in ComplicationGroupMember.allCases {
            #expect(!member.templates.isEmpty)
            for template in member.templates {
                #expect(template.groupMember == member)
                #expect(template.group == member.group)
            }
        }
    }

    @Test func templatesCoverEveryTemplateExactlyOnce() {
        let templates = ComplicationGroupMember.allCases.flatMap(\.templates)
        #expect(templates.count == ComplicationTemplate.allCases.count)
        #expect(Set(templates) == Set(ComplicationTemplate.allCases))
    }

    @Test func specificTemplateLists() {
        #expect(ComplicationGroupMember.graphicBezel.templates == [.GraphicBezelCircularText])
        #expect(ComplicationGroupMember.utilitarianLarge.templates == [.UtilitarianLargeFlat])
        #expect(ComplicationGroupMember.utilitarianSmallFlat.templates == [.UtilitarianSmallFlat])
        #expect(ComplicationGroupMember.modularLarge.templates == [
            .ModularLargeStandardBody,
            .ModularLargeTallBody,
            .ModularLargeColumns,
            .ModularLargeTable,
        ])
        #expect(ComplicationGroupMember.graphicRectangular.templates == [
            .GraphicRectangularStandardBody,
            .GraphicRectangularTextGauge,
            .GraphicRectangularLargeImage,
        ])
        #expect(ComplicationGroupMember.circularSmall.templates.first == .CircularSmallRingImage)
        #expect(ComplicationGroupMember.extraLarge.templates.count == 7)
        #expect(ComplicationGroupMember.modularSmall.templates.count == 7)
        #expect(ComplicationGroupMember.graphicCorner.templates.count == 5)
        #expect(ComplicationGroupMember.graphicCircular.templates.count == 6)
        #expect(ComplicationGroupMember.utilitarianSmall.templates == [
            .UtilitarianSmallRingImage,
            .UtilitarianSmallRingText,
            .UtilitarianSmallSquare,
        ])
    }

    @Test func membersSortByName() {
        let sorted = ComplicationGroupMember.allCases.sorted()
        #expect(sorted.map(\.name) == ComplicationGroupMember.allCases.map(\.name).sorted())
    }
}
