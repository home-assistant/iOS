//
//  CLKComplication+Strings.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 9/25/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation

enum ComplicationGroup {
    case circularSmall
    case extraLarge
    case graphic
    case modular
    case utilitarian

    var name: String {
        switch self {
        case .circularSmall:
            return "Circular Small"
        case .extraLarge:
            return "Extra Large"
        case .graphic:
            return "Graphic"
        case .modular:
            return "Modular"
        case .utilitarian:
            return "Utilitarian"
        }
    }

    var description: String {
        switch self {
        case .circularSmall:
            return "Use circular small complications to display content in the corners of the Color watch face."
        case .extraLarge:
            return "Use the extra large complications to display content on the X-Large watch faces."
        case .graphic:
            return "Use graphic complications to display visually rich content in the Infograph and Infograph Modular clock faces."
        case .modular:
            return "Use modular small complications to display content in the Modular watch face."
        case .utilitarian:
            return "Use the utilitarian complications to display content in the Utility, Motion, Mickey Mouse, and Minnie Mouse watch faces."
        }
    }

    var members: [ComplicationGroupMember] {
        switch self {
        case .circularSmall:
            return [ComplicationGroupMember.circularSmall]
        case .extraLarge:
            return [ComplicationGroupMember.extraLarge]
        case .graphic:
            return [ComplicationGroupMember.graphicBezel, ComplicationGroupMember.graphicCircular,
                    ComplicationGroupMember.graphicCorner, ComplicationGroupMember.graphicRectangular]
        case .modular:
            return [ComplicationGroupMember.modularLarge, ComplicationGroupMember.modularSmall]
        case .utilitarian:
            return [ComplicationGroupMember.utilitarianLarge, ComplicationGroupMember.utilitarianSmall,
                    ComplicationGroupMember.utilitarianSmallFlat]
        }
    }
}

extension ComplicationGroup: CaseIterable {}

enum ComplicationGroupMember: String {
    case circularSmall
    case extraLarge
    case graphicBezel
    case graphicCircular
    case graphicCorner
    case graphicRectangular
    case modularLarge
    case modularSmall
    case utilitarianLarge
    case utilitarianSmall
    case utilitarianSmallFlat

    init(name: String) {
        switch name {
        case "circularSmall":
            self = .circularSmall
        case "extraLarge":
            self = .extraLarge
        case "graphicBezel":
            self = .graphicBezel
        case "graphicCircular":
            self = .graphicCircular
        case "graphicCorner":
            self = .graphicCorner
        case "graphicRectangular":
            self = .graphicRectangular
        case "modularLarge":
            self = .modularLarge
        case "modularSmall":
            self = .modularSmall
        case "utilitarianLarge":
            self = .utilitarianLarge
        case "utilitarianSmall":
            self = .utilitarianSmall
        case "utilitarianSmallFlat":
            self = .utilitarianSmallFlat
        default:
            print("Unknown group member name", name)
            self = .circularSmall
        }
    }

    var name: String {
        switch self {
        case .circularSmall:
            return "Circular Small"
        case .extraLarge:
            return "Extra Large"
        case .graphicBezel:
            return "Graphic Bezel"
        case .graphicCircular:
            return "Graphic Circular"
        case .graphicCorner:
            return "Graphic Corner"
        case .graphicRectangular:
            return "Graphic Rectangular"
        case .modularLarge:
            return "Modular Large"
        case .modularSmall:
            return "Modular Small"
        case .utilitarianLarge:
            return "Utilitarian Large"
        case .utilitarianSmall:
            return "Utilitarian Small"
        case .utilitarianSmallFlat:
            return "Utilitarian Small Flat"
        }
    }

    var shortName: String {
        switch self {
        case .circularSmall:
            return "Circular Small"
        case .extraLarge:
            return "Extra Large"
        case .graphicBezel:
            return "Bezel"
        case .graphicCircular:
            return "Circular"
        case .graphicCorner:
            return "Corner"
        case .graphicRectangular:
            return "Rectangular"
        case .modularLarge:
            return "Large"
        case .modularSmall:
            return "Small"
        case .utilitarianLarge:
            return "Large"
        case .utilitarianSmall:
            return "Small"
        case .utilitarianSmallFlat:
            return "Small Flat"
        }
    }

    var family: String {
        switch self {
        case .circularSmall:
            return "circularSmall"
        case .extraLarge:
            return "extraLarge"
        case .graphicBezel:
            return "graphicBezel"
        case .graphicCircular:
            return "graphicCircular"
        case .graphicCorner:
            return "graphicCorner"
        case .graphicRectangular:
            return "graphicRectangular"
        case .modularLarge:
            return "modularLarge"
        case .modularSmall:
            return "modularSmall"
        case .utilitarianLarge:
            return "utilitarianLarge"
        case .utilitarianSmall:
            return "utilitarianSmall"
        case .utilitarianSmallFlat:
            return "utilitarianSmallFlat"
        }
    }

    var group: ComplicationGroup {
        switch self {
        case .circularSmall:
            return ComplicationGroup.circularSmall
        case .extraLarge:
            return ComplicationGroup.extraLarge
        case .graphicBezel, .graphicCircular, .graphicCorner, .graphicRectangular:
            return ComplicationGroup.graphic
        case .modularLarge, .modularSmall:
            return ComplicationGroup.modular
        case .utilitarianLarge, .utilitarianSmall, .utilitarianSmallFlat:
            return ComplicationGroup.utilitarian
        }
    }

    var description: String {
        switch self {
        case .circularSmall:
            return "A small circular area used in the Color clock face."
        case .extraLarge:
            return "A large square area used in the X-Large clock face."
        case .modularSmall:
            return "A small square area used in the Modular clock face."
        case .modularLarge:
            return "A large rectangular area used in the Modular clock face."
        case .utilitarianSmall:
            return "A small square or rectangular area used in the Utility, Mickey, Chronograph, and Simple clock faces."
        case .utilitarianSmallFlat:
            return "A small rectangular area used in the in the Photos, Motion, and Timelapse clock faces."
        case .utilitarianLarge:
            return "A large rectangular area that spans the width of the screen in the Utility and Mickey clock faces."
        case .graphicCorner:
            return "A curved area that fills the corners in the Infograph clock face."
        case .graphicCircular:
            return "A circular area used in the Infograph and Infograph Modular clock faces."
        case .graphicBezel:
            return "A circular area with optional curved text placed along the bezel of the Infograph clock face."
        case .graphicRectangular:
            return "A large rectangular area used in the Infograph Modular clock face."
        }
    }

    var templates: [ComplicationTemplate] {
        switch self {
        case .circularSmall:
            return [.CircularSmallRingImage, .CircularSmallSimpleImage, .CircularSmallStackImage,
                    .CircularSmallRingText, .CircularSmallSimpleText, .CircularSmallStackText]
        case .extraLarge:
            return [.ExtraLargeRingImage, .ExtraLargeSimpleImage, .ExtraLargeStackImage, .ExtraLargeColumnsText,
                    .ExtraLargeRingText, .ExtraLargeSimpleText, .ExtraLargeStackText]
        case .modularSmall:
            return [.ModularSmallRingImage, .ModularSmallSimpleImage, .ModularSmallStackImage,
                    .ModularSmallColumnsText, .ModularSmallRingText, .ModularSmallSimpleText, .ModularSmallStackText]
        case .modularLarge:
            return [.ModularLargeStandardBody, .ModularLargeTallBody, .ModularLargeColumns, .ModularLargeTable]
        case .utilitarianSmall:
            return [.UtilitarianSmallRingImage, .UtilitarianSmallRingText, .UtilitarianSmallSquare]
        case .utilitarianSmallFlat:
            return [.UtilitarianSmallFlat]
        case .utilitarianLarge:
            return [.UtilitarianLargeFlat]
        case .graphicCorner:
            return [.GraphicCornerCircularImage, .GraphicCornerGaugeImage, .GraphicCornerGaugeText,
                    .GraphicCornerStackText, .GraphicCornerTextImage]
        case .graphicCircular:
            return [.GraphicCircularImage, .GraphicCircularClosedGaugeImage, .GraphicCircularOpenGaugeImage,
                    .GraphicCircularClosedGaugeText, .GraphicCircularOpenGaugeSimpleText,
                    .GraphicCircularOpenGaugeRangeText]
        case .graphicBezel:
            return [.GraphicBezelCircularText]
        case .graphicRectangular:
            return [.GraphicRectangularStandardBody, .GraphicRectangularTextGauge, .GraphicRectangularLargeImage]
        }
    }
}

extension ComplicationGroupMember: CaseIterable {}

// swiftlint:disable:next type_body_length
enum ComplicationTemplate: String {
    case CircularSmallRingImage
    case CircularSmallSimpleImage
    case CircularSmallStackImage
    case CircularSmallRingText
    case CircularSmallSimpleText
    case CircularSmallStackText
    case ExtraLargeRingImage
    case ExtraLargeSimpleImage
    case ExtraLargeStackImage
    case ExtraLargeColumnsText
    case ExtraLargeRingText
    case ExtraLargeSimpleText
    case ExtraLargeStackText
    case ModularSmallRingImage
    case ModularSmallSimpleImage
    case ModularSmallStackImage
    case ModularSmallColumnsText
    case ModularSmallRingText
    case ModularSmallSimpleText
    case ModularSmallStackText
    case ModularLargeStandardBody
    case ModularLargeTallBody
    case ModularLargeColumns
    case ModularLargeTable
    case UtilitarianSmallFlat
    case UtilitarianSmallRingImage
    case UtilitarianSmallRingText
    case UtilitarianSmallSquare
    case UtilitarianLargeFlat
    case GraphicCornerCircularImage
    case GraphicCornerGaugeImage
    case GraphicCornerGaugeText
    case GraphicCornerStackText
    case GraphicCornerTextImage
    case GraphicCircularImage
    case GraphicCircularClosedGaugeImage
    case GraphicCircularOpenGaugeImage
    case GraphicCircularClosedGaugeText
    case GraphicCircularOpenGaugeSimpleText
    case GraphicCircularOpenGaugeRangeText
    case GraphicBezelCircularText
    case GraphicRectangularStandardBody
    case GraphicRectangularTextGauge
    case GraphicRectangularLargeImage

    var style: String {
        switch self {
        case .CircularSmallRingImage, .ExtraLargeRingImage, .ModularSmallRingImage, .UtilitarianSmallRingImage:
            return "Ring Image"
        case .CircularSmallSimpleImage, .ExtraLargeSimpleImage, .ModularSmallSimpleImage:
            return "Simple Image"
        case .CircularSmallStackImage, .ExtraLargeStackImage, .ModularSmallStackImage:
            return "Stack Image"
        case .CircularSmallRingText, .ExtraLargeRingText, .ModularSmallRingText, .UtilitarianSmallRingText:
            return "Ring Text"
        case .CircularSmallSimpleText, .ExtraLargeSimpleText, .ModularSmallSimpleText:
            return "Simple Text"
        case .CircularSmallStackText, .ExtraLargeStackText, .ModularSmallStackText, .GraphicCornerStackText:
            return "Stack Text"
        case .ExtraLargeColumnsText, .ModularSmallColumnsText:
            return "Columns Text"
        case .ModularLargeStandardBody, .GraphicRectangularStandardBody:
            return "Standard Body"
        case .ModularLargeTallBody:
            return "Tall Body"
        case .ModularLargeColumns:
            return "Columns"
        case .ModularLargeTable:
            return "Table"
        case .UtilitarianSmallFlat, .UtilitarianLargeFlat:
            return "Flat"
        case .UtilitarianSmallSquare:
            return "Square"
        case .GraphicCornerCircularImage, .GraphicCircularImage:
            return "Circular Image"
        case .GraphicCornerGaugeImage:
            return "Gauge Image"
        case .GraphicCornerGaugeText:
            return "Gauge Text"
        case .GraphicCornerTextImage:
            return "Text Image"
        case .GraphicCircularClosedGaugeImage:
            return "Closed Gauge Image"
        case .GraphicCircularOpenGaugeImage:
            return "Open Gauge Image"
        case .GraphicCircularClosedGaugeText:
            return "Closed Gauge Text"
        case .GraphicCircularOpenGaugeSimpleText:
            return "Open Gauge Simple Text"
        case .GraphicCircularOpenGaugeRangeText:
            return "Open Gauge Range Text"
        case .GraphicBezelCircularText:
            return "Circular Text"
        case .GraphicRectangularTextGauge:
            return "Text Gauge"
        case .GraphicRectangularLargeImage:
            return "Large Image"
        }
    }

    var description: String {
        switch self {
        case .CircularSmallRingImage:
            return "A template for displaying a single image surrounded by a configurable progress ring."
        case .CircularSmallSimpleImage:
            return "A template for displaying a single image."
        case .CircularSmallStackImage:
            return "A template for displaying an image with a line of text below it."
        case .CircularSmallRingText:
            return "A template for displaying a short text string encircled by a configurable progress ring."
        case .CircularSmallSimpleText:
            return "A template for displaying a short text string."
        case .CircularSmallStackText:
            return "A template for displaying two text strings stacked on top of each other."
        case .ExtraLargeRingImage:
            return "A template for displaying an image encircled by a configurable progress ring."
        case .ExtraLargeSimpleImage:
            return "A template for displaying an image."
        case .ExtraLargeStackImage:
            return "A template for displaying a single image with a short line of text below it."
        case .ExtraLargeColumnsText:
            return "A template for displaying two rows and two columns of text."
        case .ExtraLargeRingText:
            return "A template for displaying text encircled by a configurable progress ring."
        case .ExtraLargeSimpleText:
            return "A template for displaying a small amount of text"
        case .ExtraLargeStackText:
            return "A template for displaying two strings stacked one on top of the other."
        case .ModularSmallRingImage:
            return "A template for displaying an image encircled by a configurable progress ring"
        case .ModularSmallSimpleImage:
            return "A template for displaying an image."
        case .ModularSmallStackImage:
            return "A template for displaying a single image with a short line of text below it."
        case .ModularSmallColumnsText:
            return "A template for displaying two rows and two columns of text"
        case .ModularSmallRingText:
            return "A template for displaying text encircled by a configurable progress ring"
        case .ModularSmallSimpleText:
            return "A template for displaying a small amount of text."
        case .ModularSmallStackText:
            return "A template for displaying two strings stacked one on top of the other."
        case .ModularLargeStandardBody:
            return "A template for displaying a header row and two lines of text"
        case .ModularLargeTallBody:
            return "A template for displaying a header row and a tall row of body text."
        case .ModularLargeColumns:
            return "A template for displaying multiple columns of data."
        case .ModularLargeTable:
            return "A template for displaying a header row and columns"
        case .UtilitarianSmallFlat:
            return "A template for displaying an image and text in a single line."
        case .UtilitarianSmallRingImage:
            return "A template for displaying an image encircled by a configurable progress ring"
        case .UtilitarianSmallRingText:
            return "A template for displaying text encircled by a configurable progress ring."
        case .UtilitarianSmallSquare:
            return "A template for displaying a single square image."
        case .UtilitarianLargeFlat:
            return "A template for displaying an image and string in a single long line."
        case .GraphicCornerCircularImage:
            return "A template for displaying an image in the clock face’s corner."
        case .GraphicCornerGaugeImage:
            return "A template for displaying an image and a gauge in the clock face’s corner."
        case .GraphicCornerGaugeText:
            return "A template for displaying text and a gauge in the clock face’s corner."
        case .GraphicCornerStackText:
            return "A template for displaying stacked text in the clock face’s corner."
        case .GraphicCornerTextImage:
            return "A template for displaying an image and text in the clock face’s corner."
        case .GraphicCircularImage:
            return "A template for displaying a full-color circular image."
        case .GraphicCircularClosedGaugeImage:
            return "A template for displaying a full-color circular image and a closed circular gauge."
        case .GraphicCircularOpenGaugeImage:
            return "A template for displaying a full-color circular image, an open gauge, and text."
        case .GraphicCircularClosedGaugeText:
            return "A template for displaying text inside a closed circular gauge."
        case .GraphicCircularOpenGaugeSimpleText:
            return "A template for displaying text inside an open gauge, with a single piece of text for the gauge."
        case .GraphicCircularOpenGaugeRangeText:
            return "A template for displaying text inside an open gauge, with leading and trailing text for the gauge."
        case .GraphicBezelCircularText:
            return "A template for displaying a circular complication with text along the bezel."
        case .GraphicRectangularStandardBody:
            return "A template for displaying a large rectangle containing text."
        case .GraphicRectangularTextGauge:
            return "A template for displaying a large rectangle containing text and a gauge."
        case .GraphicRectangularLargeImage:
            return "A template for displaying a large rectangle containing header text and an image."
        }
    }

    var type: String {
        switch self {
        case .CircularSmallRingImage, .CircularSmallSimpleImage, .CircularSmallStackImage:
            return "image"
        case .CircularSmallRingText, .CircularSmallSimpleText, .CircularSmallStackText:
            return "text"
        case .ExtraLargeRingImage, .ExtraLargeSimpleImage, .ExtraLargeStackImage:
            return "image"
        case .ExtraLargeColumnsText, .ExtraLargeRingText, .ExtraLargeSimpleText, .ExtraLargeStackText:
            return "text"
        case .ModularSmallRingImage, .ModularSmallSimpleImage, .ModularSmallStackImage:
            return "image"
        case .ModularSmallColumnsText, .ModularSmallRingText, .ModularSmallSimpleText, .ModularSmallStackText:
            return "text"
        case .ModularLargeStandardBody, .ModularLargeTallBody:
            return "body"
        case .ModularLargeColumns, .ModularLargeTable:
            return "table"
        case .UtilitarianSmallFlat, .UtilitarianSmallRingImage, .UtilitarianSmallRingText:
            return "text"
        case .UtilitarianSmallSquare:
            return "image"
        case .UtilitarianLargeFlat:
            return "text"
        case .GraphicCornerGaugeText, .GraphicCornerStackText:
            return "text"
        case .GraphicCornerCircularImage, .GraphicCornerGaugeImage, .GraphicCornerTextImage:
            return "image"
        case .GraphicCircularClosedGaugeText, .GraphicCircularOpenGaugeSimpleText, .GraphicCircularOpenGaugeRangeText:
            return "text"
        case .GraphicCircularImage, .GraphicCircularClosedGaugeImage, .GraphicCircularOpenGaugeImage:
            return "image"
        case .GraphicBezelCircularText:
            return "text"
        case .GraphicRectangularStandardBody, .GraphicRectangularTextGauge:
            return "text"
        case .GraphicRectangularLargeImage:
            return "image"
        }
    }

    var group: ComplicationGroup {
        switch self {
        case .CircularSmallRingImage, .CircularSmallSimpleImage, .CircularSmallStackImage, .CircularSmallRingText,
             .CircularSmallSimpleText, .CircularSmallStackText:
            return .circularSmall
        case .ExtraLargeRingImage, .ExtraLargeSimpleImage, .ExtraLargeStackImage, .ExtraLargeColumnsText,
             .ExtraLargeRingText, .ExtraLargeSimpleText, .ExtraLargeStackText:
            return .extraLarge
        case .ModularSmallRingImage, .ModularSmallSimpleImage, .ModularSmallStackImage,
             .ModularSmallColumnsText, .ModularSmallRingText, .ModularSmallSimpleText, .ModularSmallStackText,
             .ModularLargeStandardBody, .ModularLargeTallBody, .ModularLargeColumns, .ModularLargeTable:
            return .modular
        case .UtilitarianSmallFlat, .UtilitarianSmallRingImage, .UtilitarianSmallRingText, .UtilitarianSmallSquare,
             .UtilitarianLargeFlat:
            return .utilitarian
        case .GraphicCornerCircularImage, .GraphicCornerGaugeImage, .GraphicCornerGaugeText, .GraphicCornerStackText,
             .GraphicCornerTextImage, .GraphicCircularImage, .GraphicCircularClosedGaugeImage,
             .GraphicCircularOpenGaugeImage, .GraphicCircularClosedGaugeText, .GraphicCircularOpenGaugeSimpleText,
             .GraphicCircularOpenGaugeRangeText, .GraphicBezelCircularText, .GraphicRectangularStandardBody,
             .GraphicRectangularTextGauge, .GraphicRectangularLargeImage:
            return .graphic
        }
    }

    var groupMember: ComplicationGroupMember {
        switch self {
        case .CircularSmallRingImage, .CircularSmallSimpleImage, .CircularSmallStackImage, .CircularSmallRingText,
             .CircularSmallSimpleText, .CircularSmallStackText:
            return .circularSmall
        case .ExtraLargeRingImage, .ExtraLargeSimpleImage, .ExtraLargeStackImage, .ExtraLargeColumnsText,
             .ExtraLargeRingText, .ExtraLargeSimpleText, .ExtraLargeStackText:
            return .extraLarge
        case .ModularSmallRingImage, .ModularSmallSimpleImage, .ModularSmallStackImage, .ModularSmallColumnsText,
             .ModularSmallRingText, .ModularSmallSimpleText, .ModularSmallStackText:
            return .modularSmall
        case .ModularLargeStandardBody, .ModularLargeTallBody, .ModularLargeColumns, .ModularLargeTable:
            return .modularLarge
        case .UtilitarianSmallFlat:
            return .utilitarianSmallFlat
        case .UtilitarianSmallRingImage, .UtilitarianSmallRingText, .UtilitarianSmallSquare:
            return .utilitarianSmall
        case .UtilitarianLargeFlat:
            return .utilitarianLarge
        case .GraphicCornerCircularImage, .GraphicCornerGaugeImage, .GraphicCornerGaugeText, .GraphicCornerStackText,
             .GraphicCornerTextImage:
            return .graphicCorner
        case .GraphicCircularImage, .GraphicCircularClosedGaugeImage, .GraphicCircularOpenGaugeImage,
             .GraphicCircularClosedGaugeText, .GraphicCircularOpenGaugeSimpleText, .GraphicCircularOpenGaugeRangeText:
            return .graphicCircular
        case .GraphicBezelCircularText:
            return .graphicBezel
        case .GraphicRectangularStandardBody, .GraphicRectangularTextGauge, .GraphicRectangularLargeImage:
            return .graphicRectangular
        }
    }

    var textAreas: [ComplicationTextAreas] {
        switch self {
        case .CircularSmallRingImage:
            return []
        case .CircularSmallSimpleImage:
            return []
        case .CircularSmallStackImage:
            return [.Line2]
        case .CircularSmallRingText:
            return [.InsideRing]
        case .CircularSmallSimpleText:
            return [.Center]
        case .CircularSmallStackText:
            return [.Line1, .Line2]
        case .ExtraLargeRingImage:
            return []
        case .ExtraLargeSimpleImage:
            return []
        case .ExtraLargeStackImage:
            return [.Line2]
        case .ExtraLargeColumnsText:
            return [.Row1Column1, .Row1Column2, .Row2Column1, .Row2Column2]
        case .ExtraLargeRingText:
            return [.InsideRing]
        case .ExtraLargeSimpleText:
            return [.Center]
        case .ExtraLargeStackText:
            return [.Line1, .Line2]
        case .ModularSmallRingImage:
            return []
        case .ModularSmallSimpleImage:
            return []
        case .ModularSmallStackImage:
            return [.Line2]
        case .ModularSmallColumnsText:
            return [.Row1Column1, .Row1Column2, .Row2Column1, .Row2Column2]
        case .ModularSmallRingText:
            return [.InsideRing]
        case .ModularSmallSimpleText:
            return [.Center]
        case .ModularSmallStackText:
            return [.Line1, .Line2]
        case .ModularLargeStandardBody:
            return [.Header, .Line1, .Line2]
        case .ModularLargeTallBody:
            return [.Header, .Center]
        case .ModularLargeColumns:
            return [.Row1Column1, .Row1Column2, .Row2Column1, .Row2Column2]
        case .ModularLargeTable:
            return [.Header, .Row1Column1, .Row1Column2, .Row2Column1, .Row2Column2]
        case .UtilitarianSmallFlat:
            return [.Center]
        case .UtilitarianSmallRingImage:
            return []
        case .UtilitarianSmallRingText:
            return [.InsideRing]
        case .UtilitarianSmallSquare:
            return []
        case .UtilitarianLargeFlat:
            return [.Center]
        case .GraphicCornerCircularImage:
            return []
        case .GraphicCornerGaugeImage:
            return [.Leading, .Trailing]
        case .GraphicCornerGaugeText:
            return [.Outer, .Leading, .Trailing]
        case .GraphicCornerStackText:
            return [.Outer, .Inner]
        case .GraphicCornerTextImage:
            return [.Center]
        case .GraphicCircularImage:
            return []
        case .GraphicCircularClosedGaugeImage:
            return []
        case .GraphicCircularOpenGaugeImage:
            return [.Center]
        case .GraphicCircularClosedGaugeText:
            return [.Center]
        case .GraphicCircularOpenGaugeSimpleText:
            return [.Center, .Bottom]
        case .GraphicCircularOpenGaugeRangeText:
            return [.Center, .Leading, .Trailing]
        case .GraphicBezelCircularText:
            return [.Center]
        case .GraphicRectangularStandardBody:
            return [.Header, .Body1, .Body2]
        case .GraphicRectangularTextGauge:
            return [.Header, .Body1]
        case .GraphicRectangularLargeImage:
            return [.Header]
        }
    }

    var hasRing: Bool {
        switch self {
        case .CircularSmallRingImage, .CircularSmallRingText, .ExtraLargeRingImage, .ExtraLargeRingText,
             .ModularSmallRingImage, .ModularSmallRingText, .UtilitarianSmallRingImage, .UtilitarianSmallRingText:
            return true
        default:
            return false
        }
    }

    var hasGauge: Bool {
        switch self {
        case .GraphicCircularClosedGaugeImage, .GraphicCircularClosedGaugeText, .GraphicCircularOpenGaugeImage,
             .GraphicCircularOpenGaugeRangeText, .GraphicCircularOpenGaugeSimpleText, .GraphicCornerGaugeImage,
             .GraphicCornerGaugeText, .GraphicRectangularTextGauge:
            return true
        default:
            return false
        }
    }

    var gaugeCanBeEitherStyle: Bool {
        switch self {
        case .GraphicCornerGaugeImage, .GraphicCornerGaugeText, .GraphicRectangularTextGauge:
            return true
        default:
            return false
        }
    }

    var gaugeIsOpenStyle: Bool {
        switch self {
        case .GraphicCircularOpenGaugeImage, .GraphicCircularOpenGaugeRangeText, .GraphicCircularOpenGaugeSimpleText:
            return true
        default:
            return false
        }
    }

    var gaugeIsClosedStyle: Bool {
        switch self {
        case .GraphicCircularClosedGaugeImage, .GraphicCircularClosedGaugeText:
            return true
        default:
            return false
        }
    }

    var hasImage: Bool {
        switch self {
        case .CircularSmallRingImage, .CircularSmallSimpleImage, .CircularSmallStackImage, .ExtraLargeRingImage,
             .ExtraLargeSimpleImage, .ExtraLargeStackImage, .ModularSmallRingImage, .ModularSmallSimpleImage,
             .ModularSmallStackImage, .UtilitarianSmallSquare, .UtilitarianSmallRingImage, .GraphicCornerCircularImage,
             .GraphicCornerGaugeImage, .GraphicCornerTextImage, .GraphicCircularImage,
             .GraphicCircularClosedGaugeImage, .GraphicCircularOpenGaugeImage, .GraphicRectangularLargeImage:
            return true
        default:
            return false
        }
    }

    var supportsRow2Alignment: Bool {
        switch self {
        case .ModularLargeColumns, .ModularLargeTable, .ExtraLargeColumnsText:
            return true
        default:
            return false
        }
    }
}

extension ComplicationTemplate: CaseIterable {}

enum ComplicationTextAreas: String, CaseIterable {
    case Body1 = "Body 1"
    case Body2 = "Body 2"
    case Bottom = "Bottom"
    case Center = "Center"
    case Header = "Header"
    case Inner = "Inner"
    case InsideRing = "Inside Ring"
    case Leading = "Leading"
    case Line1 = "Line 1"
    case Line2 = "Line 2"
    case Outer = "Outer"
    case Row1Column1 = "Row 1, Column 1"
    case Row1Column2 = "Row 1, Column 2"
    case Row2Column1 = "Row 2, Column 1"
    case Row2Column2 = "Row 2, Column 2"
    case Row3Column1 = "Row 3, Column 1"
    case Row3Column2 = "Row 3, Column 2"
    case Trailing = "Trailing"

    var description: String {
        switch self {
        case .Body1:
            return "The main body text to display in the complication."
        case .Body2:
            return "The secondary body text to display in the complication."
        case .Bottom:
            return "The text to display at the bottom of the gauge."
        case .Center:
            return "The text to display in the complication."
        case .Header:
            return "The header text to display in the complication."
        case .Inner:
            return "The inner text to display in the complication."
        case .InsideRing:
            return "The text to display in the ring of the complication."
        case .Leading:
            return "The text to display on the leading edge of the gague."
        case .Line1:
            return "The text to display on the top line of the complication."
        case .Line2:
            return "The text to display on the bottom line of the complication."
        case .Outer:
            return "The outer text to display in the complication."
        case .Row1Column1:
            return "The text to display in the first column of the first row."
        case .Row1Column2:
            return "The text to display in the second column of the first row."
        case .Row2Column1:
            return "The text to display in the first column of the second row."
        case .Row2Column2:
            return "The text to display in the second column of the second row."
        case .Row3Column1:
            return "The text to display in the first column of the third row."
        case .Row3Column2:
            return "The text to display in the second column of the third row."
        case .Trailing:
            return "The text to display on the trailing edge of the gauge."
        }
    }
}
