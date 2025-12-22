//
//  HAAssistExtensions.swift
//
//  Helper extensions for AVFoundation components
//

import Foundation
import AVFoundation

extension AVAudioPlayerNode {
    var currentTime: TimeInterval {
        guard let nodeTime: AVAudioTime = self.lastRenderTime, 
              let playerTime: AVAudioTime = self.playerTime(forNodeTime: nodeTime) else { 
            return 0 
        }

        return Double(playerTime.sampleTime) / playerTime.sampleRate
    }
}
