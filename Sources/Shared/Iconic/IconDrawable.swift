// swiftlint:disable all
// swiftformat:disable all
//
//  IconDrawable.swift
//  https://github.com/home-assistant/Iconic
//
//  Copyright © 2019 The Home Assistant Authors
//  Licensed under the Apache 2.0 license
//  For more information see https://github.com/home-assistant/Iconic

import UIKit
import CoreText

/** A wrapper class for Objective-C compatibility. */
public final class Iconic: NSObject { }

/** The IconDrawable protocol defines the complete interface of an Iconic icon's capabilities. */
public protocol IconDrawable {

    /** The icon font's family name. */
    static var familyName: String { get }

    /** The icon font's total count of available icons. */
    static var count: Int { get }

    /** The icon's name. */
    var name: String { get }

    /** The icon's unicode. */
    var unicode: String { get }

    /**
     Creates a new instance with the specified icon name.
     If there is no valid name is recognised, this initializer falls back to the first available icon.

     - parameter iconName: The icon name to use for the new instance.
     */
    init(named iconName: String)

    /**
     Returns the icon as an attributed string with the given pointSize and color.

     - parameter pointSize: The size of the font.
     - parameter color: The tint color of the font.
     */
    func attributedString(ofSize pointSize: CGFloat, color: UIColor?) -> NSAttributedString

    /**
     Returns the icon as an attributed string with the given pointSize, color and padding.

     - parameter pointSize: The size of the font.
     - parameter color: The tint color of the font.
     - parameter edgeInsets: The edge insets to be used as horizontal and vertical padding.
     */
    func attributedString(ofSize pointSize: CGFloat, color: UIColor?, edgeInsets: UIEdgeInsets) -> NSAttributedString

    /**
     Returns the icon as an image with the given size and color.

     - parameter size: The size of the image, in points.
     - parameter color: A tint color for the image.
     */
    func image(ofSize size: CGSize, color: UIColor?) -> UIImage

    /**
     Returns the icon as an image with the given size, color and padding.

     - parameter size: The size of the image, in points.
     - parameter color: The tint color of the image.
     - parameter edgeInsets: The edge insets to be used as padding values.
     */
    func image(ofSize size: CGSize, color: UIColor?, edgeInsets: UIEdgeInsets) -> UIImage

    /**
     Creates and returns the icon font object for the specified size.

     - parameter fontSize: The size (in points) to which the font is scaled.
     */
    static func font(ofSize fontSize: CGFloat) -> UIFont

    /**
     Registers the icon font with the font manager.
     Note: an exception will be thrown if the resource (ttf/otf) font file is not found in the bundle.
     */
    static func register()

    /**
     Unregisters the icon font from the font manager.
     */
    static func unregister()
}

/** This extension adds the required default implementation for Iconic to work. */
extension IconDrawable {

    public func attributedString(ofSize pointSize: CGFloat, color: UIColor?) -> NSAttributedString {

        let font = Self.font(ofSize: pointSize)

        var attributes: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font : font]

        if let color = color {
            attributes[NSAttributedString.Key.foregroundColor] = color
        }

        return NSAttributedString(string: unicode, attributes: attributes)
    }

    public func attributedString(ofSize pointSize: CGFloat, color: UIColor?, edgeInsets: UIEdgeInsets) -> NSAttributedString {

        let aString = attributedString(ofSize: pointSize, color: color)
        let mString = NSMutableAttributedString(attributedString: aString)

        let range = NSRange(location: 0, length: mString.length)

        mString.addAttribute(NSAttributedString.Key.baselineOffset, value: edgeInsets.bottom-edgeInsets.top, range: range)

        let leftSpace = NSAttributedString(string: " ", attributes: [NSAttributedString.Key.kern: edgeInsets.left])
        let rightSpace = NSAttributedString(string: " ", attributes: [NSAttributedString.Key.kern: edgeInsets.right])

        mString.insert(rightSpace, at: mString.length)
        mString.insert(leftSpace, at: 0)

        return mString
    }

    public func image(ofSize size: CGSize, color: UIColor?) -> UIImage {

        return image(ofSize: size, color: color, edgeInsets: .zero)
    }

    public func image(ofSize size: CGSize, color: UIColor?, edgeInsets: UIEdgeInsets) -> UIImage {

        let pointSize = min(size.width, size.height)
        let aString = attributedString(ofSize: pointSize, color: color)
        let mString = NSMutableAttributedString(attributedString: aString)

        var rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        rect.origin.y -= edgeInsets.top
        rect.size.width -= edgeInsets.left + edgeInsets.right
        rect.size.height -= edgeInsets.top + edgeInsets.bottom

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let range = NSRange(location: 0, length: mString.length)

        mString.addAttribute(NSAttributedString.Key.paragraphStyle, value: paragraphStyle, range: range)

        // Renders the attributed string as image using Text Kit
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        mString.draw(in: rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return image!
    }

    public static func font(ofSize fontSize: CGFloat) -> UIFont {

        // Needs a default size, since zero would return a system font object.
        let size = (fontSize == 0) ? 10.0 : fontSize

        return UIFont(name: familyName, size: size)!
    }

    public static func register() {

        // No need to register the font more than once
        if UIFont.familyNames.contains(familyName) {
            return
        }

        guard let url = resourceUrl() else {
            print("Unable to register font '\(familyName)' beacuse URL was nil!")
            return
        }
        var error: Unmanaged<CFError>? = nil
        let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as NSArray?

        guard let descriptor = (descriptors as? [CTFontDescriptor])?.first else {
            assertionFailure("Could not retrieve font descriptors of font at path '\(url)',")
            return
        }

        let font = CTFontCreateWithFontDescriptorAndOptions(descriptor, 0.0, nil, [.preventAutoActivation])
        let fontName = CTFontCopyPostScriptName(font) as String

        // Registers font dynamically
        if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) == false || error != nil {
            if let error = error?.takeUnretainedValue(), CFErrorGetDomain(error) == kCTFontManagerErrorDomain, CFErrorGetCode(error) == CTFontManagerError.alreadyRegistered.rawValue {
                // this is fine
            } else {
                assertionFailure("Failed registering font with the postscript name '\(fontName)' at path '\(url)' with error: \(String(describing: error)).")
            }
        }

        print("Font '\(familyName)' registered successfully!")
    }

    public static func unregister() {

        // No need to unregister if the font isn't registered
        if UIFont.familyNames.contains(familyName) == false {
            return
        }

        guard let url = resourceUrl() else {
            print("Unable to unregister font '\(familyName)' beacuse URL was nil!")
            return
        }
        var error: Unmanaged<CFError>? = nil

        if CTFontManagerUnregisterFontsForURL(url as CFURL, .none, &error) == false || error != nil {
            assertionFailure("Failed unregistering font with name '\(familyName)' at path '\(url)' with error: \(String(describing: error)).")
        }

        print("Font '\(familyName)' unregistered successfully!")
    }

    fileprivate static func resourceUrl() -> URL? {
        let extensions = ["otf", "ttf"]
        let bundle = Bundle(for: Iconic.self)

        return extensions.compactMap { bundle.url(forResource: familyName, withExtension: $0) }.first
    }
}

