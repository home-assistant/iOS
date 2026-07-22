import AVFoundation
import Foundation
import Shared

protocol AudioPlayerProtocol {
    var delegate: AudioPlayerDelegate? { get set }
    func play(url: URL, server: Server)
    func pause()
}

protocol AudioPlayerDelegate: AnyObject {
    func audioPlayerDidFinishPlaying(_ player: AudioPlayer)
    func volumeIsZero()
}

final class AudioPlayer: NSObject, AudioPlayerProtocol {
    weak var delegate: AudioPlayerDelegate?
    private let player = AVPlayer()
    private var dataPlayer: AVAudioPlayer?
    private var downloadTask: URLSessionDataTask?

    func play(url: URL, server: Server) {
        let audioSession = AVAudioSession.sharedInstance()

        // Each step is attempted independently: if deactivation fails (e.g. while the
        // recorder's capture session is still tearing down), the category switch below must
        // still run — otherwise the session can stay in the output-less .record category
        // and playback is silent.
        do {
            try audioSession.setActive(false)
        } catch {
            Current.Log.error("Failed to deactivate audio session before playback: \(error.localizedDescription)")
        }
        do {
            try audioSession.setCategory(.playback)
        } catch {
            Current.Log.error("Failed to set playback category for audio player: \(error.localizedDescription)")
        }
        do {
            try audioSession.setActive(true)
        } catch {
            Current.Log.error("Failed to activate audio session for audio player: \(error.localizedDescription)")
        }

        Current.Log.verbose("Audio player current volume: \(audioSession.outputVolume)")

        if audioSession.outputVolume == 0 {
            delegate?.volumeIsZero()
            return
        }

        if requiresCertificateAwareLoading(server: server) {
            downloadAndPlay(url: url, server: server)
        } else {
            playStreaming(url: url)
        }
    }

    func pause() {
        player.pause()
        dataPlayer?.pause()
        downloadTask?.cancel()
    }

    /// AVPlayer loads media over its own connection, which can neither present the server's
    /// client certificate (mTLS) nor apply the app's TLS security exceptions — so for servers
    /// configured with either, streaming would always fail the handshake.
    private func requiresCertificateAwareLoading(server: Server) -> Bool {
        server.info.connection.clientCertificate != nil ||
            server.info.connection.securityExceptions.hasExceptions
    }

    private func playStreaming(url: URL) {
        let playerItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: playerItem)
        player.play()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioDidFinishPlaying(_:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
    }

    private func downloadAndPlay(url: URL, server: Server) {
        downloadTask?.cancel()

        let session = HomeAssistantAPI.makeCertificateAwareURLSession(server: server)
        let task = session.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.handleDownloadResult(data: data, response: response, error: error)
            }
        }
        downloadTask = task
        task.resume()
        // The running task completes normally; afterwards the session releases its delegate,
        // which URLSession otherwise retains forever.
        session.finishTasksAndInvalidate()
    }

    private func handleDownloadResult(data: Data?, response: URLResponse?, error: Error?) {
        if let error {
            guard (error as? URLError)?.code != .cancelled else { return }
            Current.Log.error("Failed to download TTS audio: \(error.localizedDescription)")
            finishWithoutPlayback()
            return
        }

        if let httpResponse = response as? HTTPURLResponse, !(200 ..< 300).contains(httpResponse.statusCode) {
            Current.Log.error("TTS audio download failed with status code: \(httpResponse.statusCode)")
            finishWithoutPlayback()
            return
        }

        guard let data, !data.isEmpty else {
            Current.Log.error("TTS audio download returned empty data")
            finishWithoutPlayback()
            return
        }

        do {
            dataPlayer = try AVAudioPlayer(data: data)
            dataPlayer?.delegate = self
            dataPlayer?.prepareToPlay()
            if dataPlayer?.play() != true {
                Current.Log.error("AVAudioPlayer failed to start TTS playback")
                finishWithoutPlayback()
            }
        } catch {
            Current.Log.error("Failed to create AVAudioPlayer for TTS: \(error.localizedDescription)")
            finishWithoutPlayback()
        }
    }

    /// Failed playback reports as finished so a continue-conversation pipeline run resumes
    /// listening instead of hanging on audio that will never end.
    private func finishWithoutPlayback() {
        delegate?.audioPlayerDidFinishPlaying(self)
    }

    @objc private func audioDidFinishPlaying(_ notification: Notification) {
        delegate?.audioPlayerDidFinishPlaying(self)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension AudioPlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        delegate?.audioPlayerDidFinishPlaying(self)
    }
}
