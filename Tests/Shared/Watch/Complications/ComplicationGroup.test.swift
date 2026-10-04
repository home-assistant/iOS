import Foundation
@testable import Shared
import Testing

struct ComplicationGroupTests {
    @Test func everyGroupHasALocalizedNameAndDescription() {
        for group in ComplicationGroup.allCases {
            #expect(!group.name.isEmpty)
            #expect(!group.description.isEmpty)
        }
        #expect(ComplicationGroup.graphic.name == L10n.Watch.Labels.ComplicationGroup.Graphic.name)
        #expect(ComplicationGroup.modular.description == L10n.Watch.Labels.ComplicationGroup.Modular.description)
    }

    @Test func membersPointBackToTheirGroup() {
        for group in ComplicationGroup.allCases {
            #expect(!group.members.isEmpty)
            for member in group.members {
                #expect(member.group == group)
            }
        }
    }

    @Test func membersCoverEveryFamilyExactlyOnce() {
        let members = ComplicationGroup.allCases.flatMap(\.members)
        #expect(members.count == ComplicationGroupMember.allCases.count)
        #expect(Set(members) == Set(ComplicationGroupMember.allCases))
    }

    @Test func graphicGroupHoldsTheFourGraphicFamilies() {
        #expect(ComplicationGroup.graphic.members == [
            .graphicBezel,
            .graphicCircular,
            .graphicCorner,
            .graphicRectangular,
        ])
        #expect(ComplicationGroup.modular.members == [.modularLarge, .modularSmall])
        #expect(ComplicationGroup.utilitarian.members == [
            .utilitarianLarge,
            .utilitarianSmall,
            .utilitarianSmallFlat,
        ])
        #expect(ComplicationGroup.circularSmall.members == [.circularSmall])
        #expect(ComplicationGroup.extraLarge.members == [.extraLarge])
    }

    @Test func groupsSortByName() {
        let sorted = ComplicationGroup.allCases.sorted()
        #expect(sorted.map(\.name) == ComplicationGroup.allCases.map(\.name).sorted())
        #expect((ComplicationGroup.graphic < ComplicationGroup.graphic) == false)
    }
}
