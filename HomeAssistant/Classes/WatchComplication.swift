//
//  WatchComplication.swift
//  Shared
//
//  Created by Robert Trencheny on 9/26/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import UIKit
import RealmSwift
import ObjectMapper
import Iconic
import UIColor_Hex_Swift
#if os(watchOS)
import ClockKit
import UIColor_Hex_Swift
#endif

// swiftlint:disable:next type_body_length
public class WatchComplication: Object, Mappable {
    @objc private dynamic var rawFamily: String = ""
    public var Family: ComplicationGroupMember {
        get {
            print("GET Family for str '", rawFamily, "'")
            if let f = ComplicationGroupMember(rawValue: rawFamily) {
                return f
            }
            return ComplicationGroupMember.modularSmall
        }
        set {
            rawFamily = newValue.rawValue
        }
    }
    @objc private dynamic var rawTemplate: String = ""
    public var Template: ComplicationTemplate {
        get {
            print("GET Template for str'", rawTemplate, "'")
            if let t = ComplicationTemplate(rawValue: rawTemplate) {
                return t
            }
            return self.Family.templates.first!
        }
        set {
            rawTemplate = newValue.rawValue
        }
    }
    @objc dynamic var Data: [String: Any] {
        get {
            guard let dictionaryData = complicationData else {
                return [String: Any]()
            }
            do {
                let dict = try JSONSerialization.jsonObject(with: dictionaryData, options: []) as? [String: Any]
                return dict!
            } catch {
                return [String: Any]()
            }
        }

        set {
            do {
                let data = try JSONSerialization.data(withJSONObject: newValue, options: [])
                complicationData = data
            } catch {
                complicationData = nil
            }
        }
    }
    @objc fileprivate dynamic var complicationData: Data?
    @objc dynamic var CreatedAt = Date()

    @objc dynamic var RenderedData: [String: Any] = [String: Any]()

    override public static func primaryKey() -> String? {
        return "rawFamily"
    }

    override public static func ignoredProperties() -> [String] {
        return ["RenderedData", "Family", "Template"]
    }

    required convenience public init?(map: Map) {
        self.init()
    }

    public func mapping(map: Map) {
        let realm = Realm.live()
        let isWriteRequired = realm.isInWriteTransaction == false
        isWriteRequired ? realm.beginWrite() : ()

        Template  <- map["Template"]
        Data      <- map["Data"]
        CreatedAt <- map["CreatedAt"]

        if map.mappingType == .toJSON {
            var family = self.Family
            family <- map["Family"]
        } else {
            Family <- map["Family"]
        }

        isWriteRequired ? try? realm.commitWrite() : ()
    }

    #if os(watchOS)

    var textDataProviders: [String: CLKTextProvider] {
        var providers: [String: CLKTextProvider] = [String: CLKTextProvider]()

        if let textAreas = self.Data["textAreas"] as? [String: [String: Any]] {
            for (key, textArea) in textAreas {
                guard let text = textArea["text"] as? String else {
                    print("TextArea", key, "doesn't have any text!")
                    continue
                }
                guard let color = textArea["color"] as? String else {
                    print("TextArea", key, "doesn't have a text color!")
                    continue
                }
                let provider = CLKSimpleTextProvider(text: text)
                provider.tintColor = UIColor(hex: color)
                providers[key] = provider
            }
        }

        return providers
    }

    var iconProvider: CLKImageProvider? {
        if let iconDict = self.Data["icon"] as? [String: String], let iconName = iconDict["icon"],
            let iconColor = iconDict["icon_color"], let iconSize = self.Template.imageSize {
            let icon = MaterialDesignIcons(named: iconName)
            let image = icon.image(ofSize: iconSize, color: .clear)
            let provider = CLKImageProvider(onePieceImage: image)
            provider.tintColor = UIColor(hex: iconColor)
            return provider
        }

        return nil
    }

    var gaugeProvider: CLKSimpleGaugeProvider? {
        if let gaugeDict = self.Data["gauge"] as? [String: String], let gaugeValue = gaugeDict["gauge"],
            let floatVal = Float(gaugeValue), let gaugeColor = gaugeDict["gauge_color"],
            let gaugeStyle = gaugeDict["gauge_style"] {

            let style = (gaugeStyle == "fill" ? CLKGaugeProviderStyle.fill : CLKGaugeProviderStyle.ring)

            return CLKSimpleGaugeProvider(style: style, gaugeColor: UIColor(hex: gaugeColor), fillFraction: floatVal)
        }

        return nil
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func CLKComplicationTemplate(family: CLKComplicationFamily) -> CLKComplicationTemplate? {
        if self.Template.groupMember != ComplicationGroupMember(family: family) {
            print("Would have returned a template (\(self.Template)) outside of the expected family (\(family)")
            return nil
        }
        switch self.Template {
        case .CircularSmallRingImage:
            let template = CLKComplicationTemplateCircularSmallRingImage()
            if let iconProvider = self.iconProvider {
                template.imageProvider = iconProvider
            }
            return template
        case .CircularSmallSimpleImage:
            let template = CLKComplicationTemplateCircularSmallSimpleImage()
            if let iconProvider = self.iconProvider {
                template.imageProvider = iconProvider
            }
            return template
        case .CircularSmallStackImage:
            let template = CLKComplicationTemplateCircularSmallStackImage()
            if let iconProvider = self.iconProvider {
                template.line1ImageProvider = iconProvider
            }
            if let textProvider = self.textDataProviders["Line2"] {
                template.line2TextProvider = textProvider
            }
            return template
        case .CircularSmallRingText:
            let template = CLKComplicationTemplateCircularSmallRingText()
            if let textProvider = self.textDataProviders["InsideRing"] {
                template.textProvider = textProvider
            }
            return template
        case .CircularSmallSimpleText:
            let template = CLKComplicationTemplateCircularSmallSimpleText()
            if let textProvider = self.textDataProviders["Center"] {
                template.textProvider = textProvider
            }
            return template
        case .CircularSmallStackText:
            let template = CLKComplicationTemplateCircularSmallStackText()
            if let textProvider = self.textDataProviders["Line1"] {
                template.line1TextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Line2"] {
                template.line2TextProvider = textProvider
            }
            return template
        case .ExtraLargeRingImage:
            let template = CLKComplicationTemplateExtraLargeRingImage()
            if let iconProvider = self.iconProvider {
                template.imageProvider = iconProvider
            }
            return template
        case .ExtraLargeSimpleImage:
            let template = CLKComplicationTemplateExtraLargeSimpleImage()
            if let iconProvider = self.iconProvider {
                template.imageProvider = iconProvider
            }
            return template
        case .ExtraLargeStackImage:
            let template = CLKComplicationTemplateExtraLargeStackImage()
            if let iconProvider = self.iconProvider {
                template.line1ImageProvider = iconProvider
            }
            if let textProvider = self.textDataProviders["Line2"] {
                template.line2TextProvider = textProvider
            }
            return template
        case .ExtraLargeColumnsText:
            let template = CLKComplicationTemplateExtraLargeColumnsText()
            if let textProvider = self.textDataProviders["Row1Column1"] {
                template.row1Column1TextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Row1Column2"] {
                template.row1Column2TextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Row2Column1"] {
                template.row2Column1TextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Row2Column2"] {
                template.row2Column2TextProvider = textProvider
            }
            return template
        case .ExtraLargeRingText:
            let template = CLKComplicationTemplateExtraLargeRingText()
            if let textProvider = self.textDataProviders["InsideRing"] {
                template.textProvider = textProvider
            }
            return template
        case .ExtraLargeSimpleText:
            let template = CLKComplicationTemplateExtraLargeSimpleText()
            if let textProvider = self.textDataProviders["Center"] {
                template.textProvider = textProvider
            }
            return template
        case .ExtraLargeStackText:
            let template = CLKComplicationTemplateExtraLargeStackText()
            if let textProvider = self.textDataProviders["Line1"] {
                template.line1TextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Line2"] {
                template.line2TextProvider = textProvider
            }
            return template
        case .ModularSmallRingImage:
            let template = CLKComplicationTemplateModularSmallRingImage()
            if let iconProvider = self.iconProvider {
                template.imageProvider = iconProvider
            }
            return template
        case .ModularSmallSimpleImage:
            let template = CLKComplicationTemplateModularSmallSimpleImage()
            if let iconProvider = self.iconProvider {
                template.imageProvider = iconProvider
            }
            return template
        case .ModularSmallStackImage:
            let template = CLKComplicationTemplateModularSmallStackImage()
            if let iconProvider = self.iconProvider {
                template.line1ImageProvider = iconProvider
            }
            if let textProvider = self.textDataProviders["Line2"] {
                template.line2TextProvider = textProvider
            }
            return template
        case .ModularSmallColumnsText:
            let template = CLKComplicationTemplateModularSmallColumnsText()
            if let textProvider = self.textDataProviders["Row1Column1"] {
                template.row1Column1TextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Row1Column2"] {
                template.row1Column2TextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Row2Column1"] {
                template.row2Column1TextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Row2Column2"] {
                template.row2Column2TextProvider = textProvider
            }
            return template
        case .ModularSmallRingText:
            let template = CLKComplicationTemplateModularSmallRingText()
            if let textProvider = self.textDataProviders["InsideRing"] {
                template.textProvider = textProvider
            }
            return template
        case .ModularSmallSimpleText:
            let template = CLKComplicationTemplateModularSmallSimpleText()
            if let textProvider = self.textDataProviders["Center"] {
                template.textProvider = textProvider
            }
            return template
        case .ModularSmallStackText:
            let template = CLKComplicationTemplateModularSmallStackText()
            if let textProvider = self.textDataProviders["Line1"] {
                template.line1TextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Line2"] {
                template.line2TextProvider = textProvider
            }
            return template
        case .ModularLargeStandardBody:
            let template = CLKComplicationTemplateModularLargeStandardBody()
            if let textProvider = self.textDataProviders["Header"] {
                template.headerTextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Body1"] {
                template.body1TextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Body2"] {
                template.body2TextProvider = textProvider
            }
            return template
        case .ModularLargeTallBody:
            let template = CLKComplicationTemplateModularLargeTallBody()
            if let textProvider = self.textDataProviders["Header"] {
                template.headerTextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Center"] {
                template.bodyTextProvider = textProvider
            }
            return template
        case .ModularLargeColumns:
            let template = CLKComplicationTemplateModularLargeColumns()
            if let textProvider = self.textDataProviders["Row1Column1"] {
                template.row1Column1TextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Row1Column2"] {
                template.row1Column2TextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Row2Column1"] {
                template.row2Column1TextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Row2Column2"] {
                template.row2Column2TextProvider = textProvider
            }
            return template
        case .ModularLargeTable:
            let template = CLKComplicationTemplateModularLargeTable()
            if let textProvider = self.textDataProviders["Header"] {
                template.headerTextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Row1Column1"] {
                template.row1Column1TextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Row1Column2"] {
                template.row1Column2TextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Row2Column1"] {
                template.row2Column1TextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Row2Column2"] {
                template.row2Column2TextProvider = textProvider
            }
            return template
        case .UtilitarianSmallFlat:
            let template = CLKComplicationTemplateUtilitarianSmallFlat()
            if let iconProvider = self.iconProvider {
                template.imageProvider = iconProvider
            }
            if let textProvider = self.textDataProviders["Center"] {
                template.textProvider = textProvider
            }
            return template
        case .UtilitarianSmallRingImage:
            let template = CLKComplicationTemplateUtilitarianSmallRingImage()
            if let iconProvider = self.iconProvider {
                template.imageProvider = iconProvider
            }
            return template
        case .UtilitarianSmallRingText:
            let template = CLKComplicationTemplateUtilitarianSmallRingText()
            if let textProvider = self.textDataProviders["InsideRing"] {
                template.textProvider = textProvider
            }
            return template
        case .UtilitarianSmallSquare:
            let template = CLKComplicationTemplateUtilitarianSmallSquare()
            return template
        case .UtilitarianLargeFlat:
            let template = CLKComplicationTemplateUtilitarianLargeFlat()
            if let textProvider = self.textDataProviders["Center"] {
                template.textProvider = textProvider
            }
            return template
        case .GraphicCornerCircularImage:
            let template = CLKComplicationTemplateGraphicCornerCircularImage()
            // Need a FullImageProvider for this one
//            if let iconProvider = self.iconProvider {
//                template.imageProvider = iconProvider
//            }
            return template
        case .GraphicCornerGaugeImage:
            let template = CLKComplicationTemplateGraphicCornerGaugeImage()
            // Need a FullImageProvider for this one
//            if let iconProvider = self.iconProvider {
//                template.imageProvider = iconProvider
//            }
            if let gaugeProvider = self.gaugeProvider {
                template.gaugeProvider = gaugeProvider
            }
            if let textProvider = self.textDataProviders["Leading"] {
                template.leadingTextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Trailing"] {
                template.trailingTextProvider = textProvider
            }
            return template
        case .GraphicCornerGaugeText:
            let template = CLKComplicationTemplateGraphicCornerGaugeText()
            if let gaugeProvider = self.gaugeProvider {
                template.gaugeProvider = gaugeProvider
            }
            if let textProvider = self.textDataProviders["Outer"] {
                template.outerTextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Leading"] {
                template.leadingTextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Trailing"] {
                template.trailingTextProvider = textProvider
            }
            return template
        case .GraphicCornerStackText:
            let template = CLKComplicationTemplateGraphicCornerStackText()
            if let textProvider = self.textDataProviders["Outer"] {
                template.outerTextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Inner"] {
                template.innerTextProvider = textProvider
            }
            return template
        case .GraphicCornerTextImage:
            let template = CLKComplicationTemplateGraphicCornerTextImage()
            // Need a FullImageProvider for this one
//            if let iconProvider = self.iconProvider {
//                template.imageProvider = iconProvider
//            }
            if let textProvider = self.textDataProviders["Center"] {
                template.textProvider = textProvider
            }
            return template
        case .GraphicCircularImage:
            let template = CLKComplicationTemplateGraphicCircularImage()
            // Need a FullImageProvider for this one
//            if let iconProvider = self.iconProvider {
//                template.imageProvider = iconProvider
//            }
            return template
        case .GraphicCircularClosedGaugeImage:
            let template = CLKComplicationTemplateGraphicCircularClosedGaugeImage()
            // Need a FullImageProvider for this one
//            if let iconProvider = self.iconProvider {
//                template.imageProvider = iconProvider
//            }
            if let gaugeProvider = self.gaugeProvider {
                template.gaugeProvider = gaugeProvider
            }
            return template
        case .GraphicCircularOpenGaugeImage:
            let template = CLKComplicationTemplateGraphicCircularOpenGaugeImage()
            // Need a FullImageProvider for this one
//            if let iconProvider = self.iconProvider {
//                template.bottomImageProvider = iconProvider
//            }
            if let gaugeProvider = self.gaugeProvider {
                template.gaugeProvider = gaugeProvider
            }
            if let textProvider = self.textDataProviders["Center"] {
                template.centerTextProvider = textProvider
            }
            return template
        case .GraphicCircularClosedGaugeText:
            let template = CLKComplicationTemplateGraphicCircularClosedGaugeText()
            if let gaugeProvider = self.gaugeProvider {
                template.gaugeProvider = gaugeProvider
            }
            if let textProvider = self.textDataProviders["Center"] {
                template.centerTextProvider = textProvider
            }
            return template
        case .GraphicCircularOpenGaugeSimpleText:
            let template = CLKComplicationTemplateGraphicCircularOpenGaugeSimpleText()
            if let gaugeProvider = self.gaugeProvider {
                template.gaugeProvider = gaugeProvider
            }
            if let textProvider = self.textDataProviders["Center"] {
                template.centerTextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Bottom"] {
                template.bottomTextProvider = textProvider
            }
            return template
        case .GraphicCircularOpenGaugeRangeText:
            let template = CLKComplicationTemplateGraphicCircularOpenGaugeRangeText()
            if let gaugeProvider = self.gaugeProvider {
                template.gaugeProvider = gaugeProvider
            }
            if let textProvider = self.textDataProviders["Center"] {
                template.centerTextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Leading"] {
                template.leadingTextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Trailing"] {
                template.trailingTextProvider = textProvider
            }
            return template
        case .GraphicBezelCircularText:
            let template = CLKComplicationTemplateGraphicBezelCircularText()
            if let textProvider = self.textDataProviders["Center"] {
                template.textProvider = textProvider
            }
            return template
        case .GraphicRectangularStandardBody:
            let template = CLKComplicationTemplateGraphicRectangularStandardBody()
            if let textProvider = self.textDataProviders["Header"] {
                template.headerTextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Body1"] {
                template.body1TextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Body2"] {
                template.body2TextProvider = textProvider
            }
            return template
        case .GraphicRectangularTextGauge:
            let template = CLKComplicationTemplateGraphicRectangularTextGauge()
            if let gaugeProvider = self.gaugeProvider {
                template.gaugeProvider = gaugeProvider
            }
            if let textProvider = self.textDataProviders["Header"] {
                template.headerTextProvider = textProvider
            }
            if let textProvider = self.textDataProviders["Body1"] {
                template.body1TextProvider = textProvider
            }
            return template
        case .GraphicRectangularLargeImage:
            let template = CLKComplicationTemplateGraphicRectangularLargeImage()
//            if let iconProvider = self.iconProvider {
//                template.imageProvider = iconProvider
//            }
            // Need a FullImageProvider for this one
            if let textProvider = self.textDataProviders["Header"] {
                template.textProvider = textProvider
            }
            return template
        }
    }

    #endif
}
