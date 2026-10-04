import Foundation
@testable import Shared
import Testing

struct ComplicationTemplateTests {
    @Test func everyTemplateHasLocalizedStyleAndDescription() {
        for template in ComplicationTemplate.allCases {
            #expect(!template.style.isEmpty)
            #expect(!template.description.isEmpty)
        }
    }

    @Test func styleSharesOneLabelAcrossFamilies() {
        #expect(ComplicationTemplate.CircularSmallRingImage.style == L10n.Watch.Labels.ComplicationTemplate.Style.ringImage)
        #expect(ComplicationTemplate.UtilitarianSmallRingImage.style == ComplicationTemplate.ExtraLargeRingImage.style)
        #expect(ComplicationTemplate.GraphicCornerStackText.style == L10n.Watch.Labels.ComplicationTemplate.Style.stackText)
        #expect(
            ComplicationTemplate.GraphicRectangularStandardBody.style
                == ComplicationTemplate.ModularLargeStandardBody.style
        )
        #expect(ComplicationTemplate.UtilitarianLargeFlat.style == L10n.Watch.Labels.ComplicationTemplate.Style.flat)
        #expect(ComplicationTemplate.GraphicCircularImage.style == ComplicationTemplate.GraphicCornerCircularImage.style)
        #expect(ComplicationTemplate.GraphicRectangularTextGauge.style == L10n.Watch.Labels.ComplicationTemplate.Style.textGauge)
        #expect(ComplicationTemplate.GraphicCornerTextImage.style == L10n.Watch.Labels.ComplicationTemplate.Style.textImage)
        #expect(
            ComplicationTemplate.GraphicBezelCircularText.description
                == L10n.Watch.Labels.ComplicationTemplate.GraphicBezelCircularText.description
        )
    }

    @Test func typeClassifiesEveryTemplate() {
        let allowed: Set<String> = ["image", "text", "body", "table"]
        for template in ComplicationTemplate.allCases {
            #expect(allowed.contains(template.type))
        }
        #expect(ComplicationTemplate.CircularSmallSimpleImage.type == "image")
        #expect(ComplicationTemplate.CircularSmallSimpleText.type == "text")
        #expect(ComplicationTemplate.ExtraLargeStackImage.type == "image")
        #expect(ComplicationTemplate.ExtraLargeColumnsText.type == "text")
        #expect(ComplicationTemplate.ModularSmallRingImage.type == "image")
        #expect(ComplicationTemplate.ModularSmallStackText.type == "text")
        #expect(ComplicationTemplate.ModularLargeTallBody.type == "body")
        #expect(ComplicationTemplate.ModularLargeTable.type == "table")
        #expect(ComplicationTemplate.UtilitarianSmallRingImage.type == "text")
        #expect(ComplicationTemplate.UtilitarianSmallSquare.type == "image")
        #expect(ComplicationTemplate.UtilitarianLargeFlat.type == "text")
        #expect(ComplicationTemplate.GraphicCornerGaugeText.type == "text")
        #expect(ComplicationTemplate.GraphicCornerTextImage.type == "image")
        #expect(ComplicationTemplate.GraphicCircularOpenGaugeRangeText.type == "text")
        #expect(ComplicationTemplate.GraphicCircularClosedGaugeImage.type == "image")
        #expect(ComplicationTemplate.GraphicBezelCircularText.type == "text")
        #expect(ComplicationTemplate.GraphicRectangularTextGauge.type == "text")
        #expect(ComplicationTemplate.GraphicRectangularLargeImage.type == "image")
    }

    @Test func groupAgreesWithGroupMember() {
        for template in ComplicationTemplate.allCases {
            #expect(template.group == template.groupMember.group)
            #expect(template.groupMember.templates.contains(template))
        }
        #expect(ComplicationTemplate.ModularLargeColumns.group == .modular)
        #expect(ComplicationTemplate.ModularLargeColumns.groupMember == .modularLarge)
        #expect(ComplicationTemplate.UtilitarianSmallFlat.groupMember == .utilitarianSmallFlat)
        #expect(ComplicationTemplate.UtilitarianLargeFlat.groupMember == .utilitarianLarge)
        #expect(ComplicationTemplate.GraphicBezelCircularText.groupMember == .graphicBezel)
    }

    @Test func textAreasMatchTheTemplateLayout() {
        let expected: [ComplicationTemplate: [ComplicationTextAreas]] = [
            .CircularSmallRingImage: [],
            .CircularSmallSimpleImage: [],
            .CircularSmallStackImage: [.Line2],
            .CircularSmallRingText: [.InsideRing],
            .CircularSmallSimpleText: [.Center],
            .CircularSmallStackText: [.Line1, .Line2],
            .ExtraLargeRingImage: [],
            .ExtraLargeSimpleImage: [],
            .ExtraLargeStackImage: [.Line2],
            .ExtraLargeColumnsText: [.Row1Column1, .Row1Column2, .Row2Column1, .Row2Column2],
            .ExtraLargeRingText: [.InsideRing],
            .ExtraLargeSimpleText: [.Center],
            .ExtraLargeStackText: [.Line1, .Line2],
            .ModularSmallRingImage: [],
            .ModularSmallSimpleImage: [],
            .ModularSmallStackImage: [.Line2],
            .ModularSmallColumnsText: [.Row1Column1, .Row1Column2, .Row2Column1, .Row2Column2],
            .ModularSmallRingText: [.InsideRing],
            .ModularSmallSimpleText: [.Center],
            .ModularSmallStackText: [.Line1, .Line2],
            .ModularLargeStandardBody: [.Header, .Body1, .Body2],
            .ModularLargeTallBody: [.Header, .Center],
            .ModularLargeColumns: [.Row1Column1, .Row1Column2, .Row2Column1, .Row2Column2],
            .ModularLargeTable: [.Header, .Row1Column1, .Row1Column2, .Row2Column1, .Row2Column2],
            .UtilitarianSmallFlat: [.Center],
            .UtilitarianSmallRingImage: [],
            .UtilitarianSmallRingText: [.InsideRing],
            .UtilitarianSmallSquare: [],
            .UtilitarianLargeFlat: [.Center],
            .GraphicCornerCircularImage: [],
            .GraphicCornerGaugeImage: [.Leading, .Trailing],
            .GraphicCornerGaugeText: [.Outer, .Leading, .Trailing],
            .GraphicCornerStackText: [.Outer, .Inner],
            .GraphicCornerTextImage: [.Center],
            .GraphicCircularImage: [],
            .GraphicCircularClosedGaugeImage: [],
            .GraphicCircularOpenGaugeImage: [.Center],
            .GraphicCircularClosedGaugeText: [.Center],
            .GraphicCircularOpenGaugeSimpleText: [.Center, .Bottom],
            .GraphicCircularOpenGaugeRangeText: [.Center, .Leading, .Trailing],
            .GraphicBezelCircularText: [.Center],
            .GraphicRectangularStandardBody: [.Header, .Body1, .Body2],
            .GraphicRectangularTextGauge: [.Header, .Body1],
            .GraphicRectangularLargeImage: [.Header],
        ]
        #expect(expected.count == ComplicationTemplate.allCases.count)
        for template in ComplicationTemplate.allCases {
            #expect(template.textAreas == expected[template], "\(template.rawValue)")
        }
    }

    @Test func ringTemplatesAreExactlyTheRingNamedOnes() {
        for template in ComplicationTemplate.allCases {
            #expect(template.hasRing == template.rawValue.contains("Ring"), "\(template.rawValue)")
        }
    }

    @Test func gaugeStylesPartitionTheGaugeTemplates() {
        for template in ComplicationTemplate.allCases {
            let styles = [template.gaugeCanBeEitherStyle, template.gaugeIsOpenStyle, template.gaugeIsClosedStyle]
            let styleCount = styles.filter { $0 }.count
            #expect(styleCount == (template.hasGauge ? 1 : 0), "\(template.rawValue)")
        }
        #expect(Set(ComplicationTemplate.allCases.filter(\.gaugeCanBeEitherStyle)) == [
            .GraphicCornerGaugeImage,
            .GraphicCornerGaugeText,
            .GraphicRectangularTextGauge,
        ])
        #expect(Set(ComplicationTemplate.allCases.filter(\.gaugeIsOpenStyle)) == [
            .GraphicCircularOpenGaugeImage,
            .GraphicCircularOpenGaugeRangeText,
            .GraphicCircularOpenGaugeSimpleText,
        ])
        #expect(Set(ComplicationTemplate.allCases.filter(\.gaugeIsClosedStyle)) == [
            .GraphicCircularClosedGaugeImage,
            .GraphicCircularClosedGaugeText,
        ])
    }

    @Test func imageTemplatesAreTheOnesTheRendererDrewAnIconFor() {
        let expected: Set<ComplicationTemplate> = [
            .CircularSmallRingImage, .CircularSmallSimpleImage, .CircularSmallStackImage, .ExtraLargeRingImage,
            .ExtraLargeSimpleImage, .ExtraLargeStackImage, .GraphicCircularClosedGaugeImage, .GraphicCircularImage,
            .GraphicCircularOpenGaugeImage, .GraphicCornerCircularImage, .GraphicCornerGaugeImage,
            .GraphicCornerTextImage, .GraphicRectangularLargeImage, .ModularSmallRingImage, .ModularSmallSimpleImage,
            .ModularSmallStackImage, .UtilitarianLargeFlat, .UtilitarianSmallFlat, .UtilitarianSmallRingImage,
            .UtilitarianSmallSquare, .GraphicBezelCircularText,
        ]
        #expect(Set(ComplicationTemplate.allCases.filter(\.hasImage)) == expected)
        #expect(ComplicationTemplate.GraphicRectangularStandardBody.hasImage == false)
        #expect(ComplicationTemplate.ModularLargeStandardBody.hasImage == false)
    }

    @Test func column2AlignmentOnlyForTemplatesWithASecondColumn() {
        for template in ComplicationTemplate.allCases {
            #expect(
                template.supportsColumn2Alignment == template.textAreas.contains(.Row1Column2),
                "\(template.rawValue)"
            )
        }
    }
}
