import Foundation
@testable import Shared
import Testing

struct CLKComplicationStringsTests {
    // MARK: - ComplicationGroup

    @Test func groupNamesAreNonEmptyAndDistinct() {
        let names = ComplicationGroup.allCases.map(\.name)
        #expect(names.allSatisfy { !$0.isEmpty })
        #expect(Set(names).count == ComplicationGroup.allCases.count)
    }

    @Test func groupDescriptionsAreNonEmptyAndDistinct() {
        let descriptions = ComplicationGroup.allCases.map(\.description)
        #expect(descriptions.allSatisfy { !$0.isEmpty })
        #expect(Set(descriptions).count == ComplicationGroup.allCases.count)
    }

    @Test func groupMembersPartitionAllMembers() {
        var seen: [ComplicationGroupMember] = []
        for group in ComplicationGroup.allCases {
            let members = group.members
            #expect(!members.isEmpty)
            for member in members {
                #expect(member.group == group)
            }
            seen += members
        }
        #expect(Set(seen).count == seen.count)
        #expect(Set(seen) == Set(ComplicationGroupMember.allCases))
    }

    @Test func groupComparableSortsByName() {
        let sorted = ComplicationGroup.allCases.sorted()
        let expected = ComplicationGroup.allCases.sorted { $0.name < $1.name }
        #expect(sorted == expected)
        #expect(ComplicationGroup.circularSmall < ComplicationGroup.utilitarian)
    }

    // MARK: - ComplicationGroupMember

    @Test func memberInitFromNameRoundTrips() {
        for member in ComplicationGroupMember.allCases {
            #expect(ComplicationGroupMember(name: member.rawValue) == member)
        }
    }

    @Test func memberInitFromUnknownNameFallsBackToCircularSmall() {
        #expect(ComplicationGroupMember(name: "does-not-exist") == .circularSmall)
    }

    @Test func memberNamesAreNonEmptyAndDistinct() {
        let names = ComplicationGroupMember.allCases.map(\.name)
        #expect(names.allSatisfy { !$0.isEmpty })
        #expect(Set(names).count == ComplicationGroupMember.allCases.count)
    }

    @Test func memberShortNamesAreNonEmpty() {
        for member in ComplicationGroupMember.allCases {
            #expect(!member.shortName.isEmpty)
        }
    }

    @Test func memberDescriptionsAreNonEmptyAndDistinct() {
        let descriptions = ComplicationGroupMember.allCases.map(\.description)
        #expect(descriptions.allSatisfy { !$0.isEmpty })
        #expect(Set(descriptions).count == ComplicationGroupMember.allCases.count)
    }

    @Test func memberGroupMatchesPrefix() {
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

    @Test func memberTemplatesPartitionAllTemplates() {
        var seen: [ComplicationTemplate] = []
        for member in ComplicationGroupMember.allCases {
            let templates = member.templates
            #expect(!templates.isEmpty)
            for template in templates {
                #expect(template.groupMember == member)
                #expect(template.group == member.group)
            }
            seen += templates
        }
        #expect(Set(seen).count == seen.count)
        #expect(Set(seen) == Set(ComplicationTemplate.allCases))
    }

    @Test func memberComparableSortsByName() {
        let sorted = ComplicationGroupMember.allCases.sorted()
        let expected = ComplicationGroupMember.allCases.sorted { $0.name < $1.name }
        #expect(sorted == expected)
    }

    // MARK: - ComplicationTemplate

    @Test func templateStyleIsNonEmpty() {
        for template in ComplicationTemplate.allCases {
            #expect(!template.style.isEmpty, "\(template)")
        }
        #expect(ComplicationTemplate.CircularSmallRingImage.style == ComplicationTemplate.ExtraLargeRingImage.style)
        #expect(ComplicationTemplate.ModularLargeTallBody.style != ComplicationTemplate.ModularLargeTable.style)
    }

    @Test func templateDescriptionsAreNonEmpty() {
        for template in ComplicationTemplate.allCases {
            #expect(!template.description.isEmpty, "\(template)")
        }
    }

    @Test func templateTypeIsKnownValue() {
        let known: Set<String> = ["image", "text", "body", "table"]
        for template in ComplicationTemplate.allCases {
            #expect(known.contains(template.type), "\(template)")
        }
        #expect(ComplicationTemplate.ModularLargeStandardBody.type == "body")
        #expect(ComplicationTemplate.ModularLargeTable.type == "table")
        #expect(ComplicationTemplate.GraphicRectangularLargeImage.type == "image")
        #expect(ComplicationTemplate.GraphicBezelCircularText.type == "text")
    }

    @Test func templateTextAreasAreDistinctPerTemplate() {
        for template in ComplicationTemplate.allCases {
            let areas = template.textAreas
            #expect(Set(areas).count == areas.count, "\(template)")
        }
        #expect(ComplicationTemplate.CircularSmallRingImage.textAreas.isEmpty)
        #expect(ComplicationTemplate.ModularLargeTable.textAreas.count == 5)
        #expect(ComplicationTemplate.GraphicCornerGaugeText.textAreas == [.Outer, .Leading, .Trailing])
    }

    @Test func templateRingAndGaugeFlagsAreConsistent() {
        for template in ComplicationTemplate.allCases {
            if template.hasRing {
                #expect(template.rawValue.contains("Ring"), "\(template)")
                #expect(!template.hasGauge, "\(template)")
            }
            if template.hasGauge {
                #expect(template.rawValue.contains("Gauge"), "\(template)")
            } else {
                #expect(!template.gaugeCanBeEitherStyle)
                #expect(!template.gaugeIsOpenStyle)
                #expect(!template.gaugeIsClosedStyle)
            }
            if template.gaugeIsOpenStyle {
                #expect(!template.gaugeIsClosedStyle)
                #expect(!template.gaugeCanBeEitherStyle)
            }
            if template.gaugeIsClosedStyle {
                #expect(!template.gaugeCanBeEitherStyle)
            }
        }
        #expect(ComplicationTemplate.GraphicCircularOpenGaugeImage.gaugeIsOpenStyle)
        #expect(ComplicationTemplate.GraphicCircularClosedGaugeText.gaugeIsClosedStyle)
        #expect(ComplicationTemplate.GraphicRectangularTextGauge.gaugeCanBeEitherStyle)
    }

    @Test func templateHasImageAndColumnAlignment() {
        let imageTemplates = ComplicationTemplate.allCases.filter(\.hasImage)
        #expect(imageTemplates.contains(.GraphicBezelCircularText))
        #expect(!imageTemplates.contains(.ModularLargeStandardBody))
        #expect(!imageTemplates.contains(.GraphicRectangularStandardBody))

        let columnTemplates = ComplicationTemplate.allCases.filter(\.supportsColumn2Alignment)
        #expect(Set(columnTemplates) == [
            .ModularLargeColumns, .ModularLargeTable, .ExtraLargeColumnsText, .ModularSmallColumnsText,
        ])
    }

    // MARK: - ComplicationTextAreas

    @Test func textAreaDescriptionsAndLabelsAreNonEmpty() {
        for area in ComplicationTextAreas.allCases {
            #expect(!area.description.isEmpty, "\(area)")
            #expect(!area.label.isEmpty, "\(area)")
        }
        let labels = ComplicationTextAreas.allCases.map(\.label)
        #expect(Set(labels).count == ComplicationTextAreas.allCases.count)
    }

    @Test func textAreaSlugStripsSpacesAndCommas() {
        for area in ComplicationTextAreas.allCases {
            #expect(!area.slug.contains(" "))
            #expect(!area.slug.contains(","))
        }
        #expect(ComplicationTextAreas.Row1Column2.slug == "Row1Column2")
        #expect(ComplicationTextAreas.InsideRing.slug == "InsideRing")
    }

    @Test func textAreaFirstColumnOfSameRow() {
        #expect(ComplicationTextAreas.Row1Column2.firstColumnOfSameRow == .Row1Column1)
        #expect(ComplicationTextAreas.Row2Column2.firstColumnOfSameRow == .Row2Column1)
        #expect(ComplicationTextAreas.Row3Column2.firstColumnOfSameRow == .Row3Column1)
        for area in ComplicationTextAreas.allCases where !area.rawValue.hasSuffix("Column 2") {
            #expect(area.firstColumnOfSameRow == nil, "\(area)")
        }
    }

    @Test func textAreaGaugeEndLabels() {
        let ends = ComplicationTextAreas.allCases.filter(\.isGaugeEndLabel)
        #expect(Set(ends) == [.Leading, .Trailing])
    }
}
