import CoreMedia
import Foundation
import Shared

extension CMSampleBuffer {
    func audioSamples() -> Data? {
        guard let audioBuffer = CMSampleBufferGetDataBuffer(self) else {
            Current.Log.error("Failed to get audio data buffer from sample buffer.")
            return nil
        }

        var audioBufferDataPointer: UnsafeMutablePointer<Int8>?
        var audioBufferDataLength = 0

        let status = CMBlockBufferGetDataPointer(
            audioBuffer,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &audioBufferDataLength,
            dataPointerOut: &audioBufferDataPointer
        )
        guard status == kCMBlockBufferNoErr else {
            Current.Log.error("Failed to access audio data pointer.")
            return nil
        }

        return Data(bytes: audioBufferDataPointer!, count: audioBufferDataLength)
    }
}
