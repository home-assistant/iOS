import Foundation

/// Turns the protocol's PCM chunks into the interleaved float samples the render thread mixes.
///
/// The wire convention is little-endian signed two's complement, with 24-bit samples packed into
/// three bytes.
enum SendspinPCMDecoder {
    static func decode(_ data: Data, format: SendspinAudioFormat) -> [Float]? {
        guard [16, 24, 32].contains(format.bitDepth) else { return nil }
        let bytesPerSample = format.bitDepth / 8
        guard data.count % bytesPerSample == 0 else { return nil }
        let sampleCount = data.count / bytesPerSample
        var output = [Float](repeating: 0, count: sampleCount)

        data.withUnsafeBytes { raw in
            switch format.bitDepth {
            case 16:
                for index in 0 ..< sampleCount {
                    let base = index * 2
                    let value = Int16(bitPattern: UInt16(raw[base]) | (UInt16(raw[base + 1]) << 8))
                    output[index] = Float(value) / 32_768
                }
            case 24:
                for index in 0 ..< sampleCount {
                    let base = index * 3
                    var value = Int32(raw[base]) | (Int32(raw[base + 1]) << 8) | (Int32(raw[base + 2]) << 16)
                    if value & 0x0080_0000 != 0 {
                        value -= 0x0100_0000
                    }
                    output[index] = Float(value) / 8_388_608
                }
            case 32:
                for index in 0 ..< sampleCount {
                    let base = index * 4
                    let unsigned = UInt32(raw[base])
                        | (UInt32(raw[base + 1]) << 8)
                        | (UInt32(raw[base + 2]) << 16)
                        | (UInt32(raw[base + 3]) << 24)
                    output[index] = Float(Int32(bitPattern: unsigned)) / 2_147_483_648
                }
            default:
                break
            }
        }

        return output
    }
}
