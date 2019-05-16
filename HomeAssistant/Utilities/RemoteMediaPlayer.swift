//
//  RemoteMediaPlayer.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 5/15/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import Foundation
import AVKit
import AVFoundation
import Shared

public enum RemotePlayerCommands: String, CaseIterable {
    case setVolumeLevel = "set_volume_level"
    case mute = "mute"
    case playMedia = "play_media"
    case play = "media_play"
    case pause = "media_pause"
}

protocol RemoteMediaPlayerDelegate: class {
    func sendStatus(_ state: RemotePlayerState)
    func showPlayer(_ playerViewController: AVPlayerViewController)
    func donePlaying()
}

public class RemoteMediaPlayer: NSObject {

    weak var delegate: RemoteMediaPlayerDelegate?

    private var playerViewController: AVPlayerViewController?

    private var playerRateObserver: NSKeyValueObservation?

    private var isPlaying: Bool? {
        didSet {
            if self.isPlaying == true {
                self.getAndSendCurrentStatus("playing")
            } else {
                self.getAndSendCurrentStatus("paused")
            }
        }
    }

    private var isMuted: Bool = false {
        didSet {
            self.playerViewController?.player?.isMuted = self.isMuted
        }
    }

    func handleCommand(_ command: RemotePlayerCommands, _ payload: Any?) {
        Current.Log.verbose("Received media command \(command) with payload \(String(describing: payload))")
        switch command {
        case .playMedia:
            guard let payload = payload as? [String: String], let urlStr = payload["media_content_id"],
                let url = URL(string: urlStr), let mediaType = payload["media_content_type"] else { return }
            Current.Log.verbose("Play media \(payload)")
            self.play(url, mediaType)
        case .play:
            self.playerViewController?.player?.play()
            self.isPlaying = true
        case .pause:
            if self.isPlaying == false {
                self.handleCommand(.play, nil)
                return
            }
            self.playerViewController?.player?.pause()
            self.isPlaying = false
        case .setVolumeLevel:
            guard let newVolume = payload as? Double else { return }
            self.playerViewController?.player?.volume = Float(newVolume)
            if newVolume > 0 { self.isMuted = false }
        case .mute:
            self.isMuted = !self.isMuted
        }
    }

    func play(_ url: URL, _ contentType: String) {
        let asset = AVAsset(url: url)

        Current.Log.verbose("Asset \(asset)")

        asset.loadValuesAsynchronously(forKeys: ["playable"]) {
            var error: NSError? = nil
            let status = asset.statusOfValue(forKey: "playable", error: &error)

            switch status {
            case .loaded:
                DispatchQueue.main.async {
                    let playerItem = AVPlayerItem(asset: asset)

                    Current.Log.verbose("playerItem \(playerItem)")

                    let player = AVPlayer(playerItem: playerItem)
                    Current.Log.verbose("player \(player)")

                    self.playerRateObserver = player.observe(\.rate, options: [.new, .old]) { (player, change) in
                        let newRate = change.newValue ?? 0.0
                        if newRate > 0 {
                            Current.Log.verbose("Player started \(player) \(change)")
                            self.isPlaying = true
                        }
                    }

                    let pvc = AVPlayerViewController()
                    pvc.player = player

                    NotificationCenter.default.addObserver(self, selector: #selector(self.playerDidFinishPlaying),
                                                           name: .AVPlayerItemDidPlayToEndTime,
                                                           object: player.currentItem)

                    self.playerViewController = pvc

                    if contentType == "music" || contentType == "audio" {
                        player.play()
                    } else {
                        self.delegate?.showPlayer(pvc)
                    }
                }
            case .failed:
                DispatchQueue.main.async {
                    Current.Log.error("Failed to start playing asset!")
                }
            case .cancelled:
                DispatchQueue.main.async {
                    Current.Log.error("Cancelled playing asset!")
                }
            default:
                break
            }
        }
    }

    func getAndSendCurrentStatus(_ playState: String) {
        guard let player = self.playerViewController?.player, let item = player.currentItem,
            let mediaURL = (item.asset as? AVURLAsset)?.url else { return }

        let volumeLevel: Double = Double(player.volume)

        let isMuted = self.isMuted

        let mediaType = item.hasVideo ? "video" : "audio"

        self.delegate?.sendStatus(RemotePlayerState(state: playState, mediaVolumeLevel: volumeLevel,
                                                    isVolumeMuted: isMuted, mediaContentID: mediaURL.absoluteString,
                                                    mediaContentType: mediaType))
    }

    @objc func playerDidFinishPlaying(note: NSNotification) {
        self.playerViewController?.dismiss(animated: true)
        self.playerRateObserver?.invalidate()

        self.getAndSendCurrentStatus("idle")

        self.isPlaying = false

        self.delegate?.donePlaying()
    }
}

extension AVPlayerItem {
    var hasVideo: Bool {
        return self.tracks.filter({$0.assetTrack?.mediaType == .video}).count > 0
    }
}
