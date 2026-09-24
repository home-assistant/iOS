import Foundation

enum WAVDataChunk {
    private static let headerLength = 12
    private static let chunkHeaderLength = 8

    /// The samples of a RIFF/WAVE file, or `file` itself when it is not one (raw PCM passes through).
    static func pcm(in file: Data) -> Data {
        guard file.count >= headerLength,
              tag(in: file, at: 0) == "RIFF",
              tag(in: file, at: 8) == "WAVE" else {
            return file
        }

        var offset = headerLength
        while offset + chunkHeaderLength <= file.count {
            let payloadStart = offset + chunkHeaderLength
            let declaredSize = Int(littleEndianUInt32(in: file, at: offset + 4))
            let payloadEnd = min(payloadStart + declaredSize, file.count)
            if tag(in: file, at: offset) == "data" {
                return file.subdata(in: payloadStart ..< payloadEnd)
            }
            offset = payloadEnd + (declaredSize % 2)
        }
        return Data()
    }

    private static func tag(in data: Data, at offset: Int) -> String? {
        let start = data.startIndex + offset
        return String(data: data[start ..< start + 4], encoding: .ascii)
    }

    private static func littleEndianUInt32(in data: Data, at offset: Int) -> UInt32 {
        let start = data.startIndex + offset
        return data[start ..< start + 4].reversed().reduce(0) { $0 << 8 | UInt32($1) }
    }
}
