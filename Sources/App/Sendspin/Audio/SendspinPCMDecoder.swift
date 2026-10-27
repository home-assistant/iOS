import Foundation

/// Turns little-endian signed PCM, as Sendspin streams it, into interleaved float samples.
enum SendspinPCMDecoder {
    enum Failure: Error, Equatable {
        case unsupportedBitDepth(Int)
        case partialFrame
    }

    static func decode(_ data: Data, bitDepth: Int, channels: Int) throws -> [Float] {
        let bytesPerSample: Int
        switch bitDepth {
        case 16: bytesPerSample = 2
        case 24: bytesPerSample = 3
        case 32: bytesPerSample = 4
        default: throw Failure.unsupportedBitDepth(bitDepth)
        }
        guard channels > 0, data.count.isMultiple(of: bytesPerSample * channels) else { throw Failure.partialFrame }

        let sampleCount = data.count / bytesPerSample
        var samples = [Float](repeating: 0, count: sampleCount)
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            let bytes = raw.bindMemory(to: UInt8.self)
            for index in 0 ..< sampleCount {
                let base = index * bytesPerSample
                switch bytesPerSample {
                case 2:
                    let value = Int16(bitPattern: UInt16(bytes[base]) | UInt16(bytes[base + 1]) << 8)
                    samples[index] = Float(value) / 32768
                case 3:
                    // Shifted into the top of an Int32 so the sign bit lands where it belongs.
                    let value = Int32(
                        bitPattern: UInt32(bytes[base]) << 8 | UInt32(bytes[base + 1]) << 16 |
                            UInt32(bytes[base + 2]) << 24
                    ) >> 8
                    samples[index] = Float(value) / 8_388_608
                default:
                    let value = Int32(
                        bitPattern: UInt32(bytes[base]) | UInt32(bytes[base + 1]) << 8 |
                            UInt32(bytes[base + 2]) << 16 | UInt32(bytes[base + 3]) << 24
                    )
                    samples[index] = Float(Double(value) / 2_147_483_648)
                }
            }
        }
        return samples
    }
}
