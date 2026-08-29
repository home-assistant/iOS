#if !os(watchOS)
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

/// A QR code drawn from a string. The SwiftUI counterpart of the frontend's `ha-qr-code`.
///
/// Core Image generates the symbol, so there is no third-party dependency — the frontend reaches
/// for the `qrcode` package because the web has no equivalent built in.
public struct HAQRCode: View {
    /// How much of the symbol can be damaged and still read. The cases mirror the frontend's
    /// `error-correction-level`; the raw values are the letters Core Image and the QR standard use.
    public enum ErrorCorrectionLevel: String, CaseIterable, Sendable {
        case low = "L"
        case medium = "M"
        case quartile = "Q"
        case high = "H"
    }

    private let data: String
    private let errorCorrectionLevel: ErrorCorrectionLevel?
    private let scale: CGFloat
    private let margin: CGFloat
    private let centerImage: Image?
    private let foreground: Color
    private let background: Color

    /// - Parameters:
    ///   - errorCorrectionLevel: Left `nil`, this follows the frontend's default: `quartile` when
    ///     there is a centre image covering part of the symbol, `medium` otherwise.
    ///   - scale: Points per module — per square of the symbol.
    ///   - margin: The quiet zone around the symbol, in modules. Four is the standard minimum and
    ///     the frontend's default; scanners need it to find the edges.
    ///   - centerImage: Drawn over the middle quarter of the symbol, as the frontend does.
    public init(
        data: String,
        errorCorrectionLevel: ErrorCorrectionLevel? = nil,
        scale: CGFloat = 4,
        margin: CGFloat = 4,
        centerImage: Image? = nil,
        foreground: Color = Color(uiColor: .label),
        background: Color = .haCardBackground
    ) {
        self.data = data
        self.errorCorrectionLevel = errorCorrectionLevel
        self.scale = scale
        self.margin = margin
        self.centerImage = centerImage
        self.foreground = foreground
        self.background = background
    }

    private var resolvedLevel: ErrorCorrectionLevel {
        errorCorrectionLevel ?? (centerImage == nil ? .medium : .quartile)
    }

    /// The frontend re-derives the foreground when the themed colours are missing or too close
    /// together, because a code drawn white-on-white is not a code. Same rule here, at the same
    /// 3:1 threshold.
    private var resolvedForeground: Color {
        guard let ratio = ColorContrast.ratio(foreground, background),
              ratio >= ColorContrast.minimumRatio else {
            return ColorContrast.contrastingForeground(on: background)
        }
        return foreground
    }

    public var body: some View {
        Group {
            if let image = Self.symbol(for: data, level: resolvedLevel) {
                code(image)
            } else {
                // Core Image refuses input it cannot encode — too long for the chosen correction
                // level, most often. The frontend surfaces the generator's error in an `ha-alert`.
                HAAlertView(HADesignSystemEnvironment.current.strings.qrCodeFailed, alertType: .error)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(HADesignSystemEnvironment.current.strings.qrCode))
        .accessibilityValue(Text(data))
    }

    private func code(_ image: UIImage) -> some View {
        let side = CGFloat(image.size.width) * scale
        return Image(uiImage: image)
            // The symbol is one pixel per module; smoothing it would blur the very edges a scanner
            // is looking for.
            .interpolation(.none)
            .resizable()
            .renderingMode(.template)
            .foregroundStyle(resolvedForeground)
            .frame(width: side, height: side)
            .overlay {
                if let centerImage {
                    centerImage
                        .resizable()
                        .scaledToFit()
                        // A quarter of the side, centred — the frontend draws it at 0.375 of the
                        // width and a quarter wide, which is the same square.
                        .frame(width: side / 4, height: side / 4)
                }
            }
            .padding(margin * scale)
            .background(background)
    }

    /// Rendered symbols keyed by content and correction level. Generating one runs a Core Image
    /// filter and a CGImage render, which is too slow to repeat on every body evaluation.
    private static let symbolCache = NSCache<NSString, UIImage>()

    private static func symbol(for data: String, level: ErrorCorrectionLevel) -> UIImage? {
        guard !data.isEmpty else {
            return nil
        }
        let cacheKey = "\(level.rawValue)-\(data)" as NSString
        if let cached = symbolCache.object(forKey: cacheKey) {
            return cached
        }
        let generator = CIFilter.qrCodeGenerator()
        generator.message = Data(data.utf8)
        generator.correctionLevel = level.rawValue
        guard let symbol = generator.outputImage else {
            return nil
        }
        // The generator draws opaque black modules on an opaque white field, which a template image
        // cannot use — template rendering reads only alpha, so an everywhere-opaque symbol floods
        // the whole square with the tint. Inverting and then reading luminance as alpha turns the
        // data modules opaque and the field transparent, which is what a template wants.
        let inverter = CIFilter.colorInvert()
        inverter.inputImage = symbol
        let mask = CIFilter.maskToAlpha()
        mask.inputImage = inverter.outputImage
        guard let output = mask.outputImage,
              let cgImage = CIContext().createCGImage(output, from: output.extent) else {
            return nil
        }
        let image = UIImage(cgImage: cgImage).withRenderingMode(.alwaysTemplate)
        symbolCache.setObject(image, forKey: cacheKey)
        return image
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.three) {
        HAQRCode(data: "https://www.home-assistant.io")
        HAQRCode(data: "https://www.home-assistant.io", errorCorrectionLevel: .high, scale: 3)
        HAQRCode(data: "")
    }
    .padding()
}

extension HAQRCode: FrontendComponent {
    public static var frontendComponentName: String { "ha-qr-code" }
}

#endif
