import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Produces the small, bounded image representation safe for the Remote Media extension to decode.
public enum RemoteMediaArtworkDownsampler {
    public static let maximumPixelSize = 512
    public static let compressionQuality = 0.8

    /// Downsamples with ImageIO rather than decoding the source at full resolution, and never
    /// upscales. The encoded result is what the extension caches and hands to Now Playing.
    public static func downsample(
        _ data: Data,
        maximumPixelSize: Int = maximumPixelSize
    ) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else { return nil }
        CGImageDestinationAddImage(destination, image, [
            kCGImageDestinationLossyCompressionQuality: compressionQuality,
        ] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
