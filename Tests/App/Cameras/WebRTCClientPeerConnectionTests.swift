import Foundation
@testable import HomeAssistant
import Testing
import WebRTC

/// The WebRTC client's side of signaling and its peer connection callbacks: remote descriptions and
/// candidates, the remote tracks it adopts for rendering and muting, the data channel, and what it
/// forwards to its delegate. Driven against the client's own peer connection, so nothing leaves the
/// device.
@MainActor
struct WebRTCClientPeerConnectionTests {
    private final class RecordingDelegate: WebRTCClientDelegate {
        var candidates: [RTCIceCandidate] = []
        var states: [RTCIceConnectionState] = []
        var data: [Data] = []

        func webRTCClient(_ client: WebRTCStreamClient, didDiscoverLocalCandidate candidate: RTCIceCandidate) {
            candidates.append(candidate)
        }

        func webRTCClient(_ client: WebRTCStreamClient, didChangeConnectionState state: RTCIceConnectionState) {
            states.append(state)
        }

        func webRTCClient(_ client: WebRTCStreamClient, didReceiveData data: Data) {
            self.data.append(data)
        }
    }

    private final class FakeRenderer: NSObject, RTCVideoRenderer {
        func setSize(_ size: CGSize) {}
        func renderFrame(_ frame: RTCVideoFrame?) {}
    }

    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(10)
        while !condition(), Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    private func peerConnection(of client: WebRTCClient) throws -> RTCPeerConnection {
        try #require(Mirror(reflecting: client).descendant("peerConnection") as? RTCPeerConnection)
    }

    /// The remote audio track the client adopted, if any (without one, `isAudioMuted()` is always true).
    private func remoteAudioTrack(of client: WebRTCClient) -> RTCAudioTrack? {
        Mirror(reflecting: client).descendant("remoteAudioTrack") as? RTCAudioTrack
    }

    private func factory(of client: WebRTCClient) throws -> RTCPeerConnectionFactory {
        try #require(Mirror(reflecting: client).descendant("factory") as? RTCPeerConnectionFactory)
    }

    private func offer(from client: WebRTCClient) async -> String {
        await withCheckedContinuation { continuation in
            client.offer { continuation.resume(returning: $0) }
        }
    }

    private func setRemote(_ description: RTCSessionDescription, on client: WebRTCClient) async -> Error? {
        await withCheckedContinuation { continuation in
            client.set(remoteSdp: description) { continuation.resume(returning: $0) }
        }
    }

    private func addRemote(_ candidate: RTCIceCandidate, to client: WebRTCClient) async -> Error? {
        await withCheckedContinuation { continuation in
            client.set(remoteCandidate: candidate) { continuation.resume(returning: $0) }
        }
    }

    private var candidate: RTCIceCandidate {
        RTCIceCandidate(
            sdp: "candidate:1 1 udp 2122260223 127.0.0.1 54321 typ host",
            sdpMLineIndex: 0,
            sdpMid: "0"
        )
    }

    @Test func aMalformedAnswerIsReportedAsAnError() async {
        let client = WebRTCClient(configuration: .init(iceServers: [], dataChannelLabel: nil))
        defer { client.closeConnection() }

        let error = await setRemote(RTCSessionDescription(type: .answer, sdp: "not an sdp"), on: client)
        #expect(error != nil)
    }

    @Test func anAnswerToTheOfferIsAppliedAndItsTracksAdopted() async throws {
        let client = WebRTCClient(configuration: .init(iceServers: [], dataChannelLabel: "data"))
        defer { client.closeConnection() }
        let renderer = FakeRenderer()
        client.renderRemoteVideo(to: renderer)

        let offer = await offer(from: client)
        #expect(offer.contains("m=video"))
        #expect(offer.contains("m=application"))

        // The offer mirrored into an answer: same transports, every receive-only line sending.
        let answer = offer
            .replacingOccurrences(of: "a=recvonly", with: "a=sendonly")
            .replacingOccurrences(of: "a=setup:actpass", with: "a=setup:active")
        let answerError = await setRemote(RTCSessionDescription(type: .answer, sdp: answer), on: client)
        #expect(answerError == nil)
        let candidateError = await addRemote(candidate, to: client)
        #expect(candidateError == nil)

        // Tracks are adopted on the main queue after the description lands; the audio one starts muted.
        let adopted = await waitUntil { remoteAudioTrack(of: client) != nil }
        #expect(adopted)
        #expect(client.isAudioMuted())
        // The adopted track is the one the mute choice drives.
        client.unmuteAudio()
        #expect(!client.isAudioMuted())
    }

    @Test func aCandidateBeforeAnyDescriptionIsRejected() async {
        let client = WebRTCClient(configuration: .init(iceServers: [], dataChannelLabel: nil))
        defer { client.closeConnection() }

        let expectation1 = await addRemote(candidate, to: client) != nil
        #expect(expectation1)
    }

    @Test func remoteAudioFollowsTheMuteChoiceOnceATrackArrives() async throws {
        let client = WebRTCClient(configuration: .init(iceServers: [], dataChannelLabel: nil))
        defer { client.closeConnection() }
        let peerConnection = try peerConnection(of: client)
        let renderer = FakeRenderer()

        // Without an audio track there is nothing to hear.
        #expect(client.isAudioMuted())
        client.unmuteAudio()
        #expect(client.isAudioMuted())

        client.renderRemoteVideo(to: renderer)
        for transceiver in peerConnection.transceivers {
            client.peerConnection(peerConnection, didStartReceivingOn: transceiver)
        }
        // The audio track is adopted unmuted, as last chosen.
        let expectation2 = await waitUntil { !client.isAudioMuted() }
        #expect(expectation2)

        client.muteAudio()
        #expect(client.isAudioMuted())
        client.unmuteAudio()
        #expect(!client.isAudioMuted())

        // A second renderer moves the video over from the first.
        client.renderRemoteVideo(to: FakeRenderer())
        for transceiver in peerConnection.transceivers {
            client.peerConnection(peerConnection, didStartReceivingOn: transceiver)
        }
        for _ in 0 ..< 10 {
            await Task.yield()
        }
    }

    @Test func peerConnectionEventsReachTheDelegate() throws {
        let client = WebRTCClient(configuration: .init(iceServers: [], dataChannelLabel: nil))
        defer { client.closeConnection() }
        let delegate = RecordingDelegate()
        client.delegate = delegate
        let peerConnection = try peerConnection(of: client)
        let stream = try factory(of: client).mediaStream(withStreamId: "stream")

        client.peerConnection(peerConnection, didChange: RTCSignalingState.haveLocalOffer)
        client.peerConnection(peerConnection, didAdd: stream)
        client.peerConnection(peerConnection, didRemove: stream)
        client.peerConnectionShouldNegotiate(peerConnection)
        client.peerConnection(peerConnection, didChange: RTCIceGatheringState.complete)
        client.peerConnection(peerConnection, didChange: RTCIceConnectionState.connected)
        client.peerConnection(peerConnection, didGenerate: candidate)
        client.peerConnection(peerConnection, didRemove: [candidate])

        #expect(delegate.states == [.connected])
        #expect(delegate.candidates.map(\.sdp) == [candidate.sdp])
    }

    @Test func messagesOnARemoteDataChannelReachTheDelegate() throws {
        let client = WebRTCClient(configuration: .init(iceServers: [], dataChannelLabel: nil))
        defer { client.closeConnection() }
        let delegate = RecordingDelegate()
        client.delegate = delegate
        let peerConnection = try peerConnection(of: client)
        let channel = try #require(peerConnection.dataChannel(
            forLabel: "remote",
            configuration: RTCDataChannelConfiguration()
        ))

        client.peerConnection(peerConnection, didOpen: channel)
        client.dataChannelDidChangeState(channel)
        client.dataChannel(channel, didReceiveMessageWith: RTCDataBuffer(data: Data("ping".utf8), isBinary: false))

        #expect(delegate.data == [Data("ping".utf8)])
    }

    @Test func theConnectionIsNoLongerAliveOnceClosed() {
        let client = WebRTCClient(configuration: .init(iceServers: [], dataChannelLabel: nil))
        #expect(client.isConnectionAlive)
        client.closeConnection()
        #expect(!client.isConnectionAlive)
    }

    // MARK: - Playback-only audio device

    @Test func thePlaybackAudioDeviceNeverRecords() {
        let device = PlaybackOnlyRTCAudioDevice()
        #expect(device.deviceInputSampleRate == 48000)
        #expect(device.deviceOutputSampleRate == 48000)
        #expect(device.inputNumberOfChannels == 0)
        #expect(device.outputNumberOfChannels == 1)
        #expect(device.inputIOBufferDuration == 0.01)
        #expect(device.outputIOBufferDuration == 0.01)
        #expect(device.inputLatency == 0)
        #expect(device.outputLatency >= 0)

        #expect(device.initializeRecording())
        #expect(device.isRecordingInitialized)
        #expect(device.startRecording())
        #expect(!device.isRecording)
        #expect(device.stopRecording())
        #expect(!device.isRecording)
    }

    @Test func thePlaybackAudioDeviceNeedsADelegateBeforePlaying() {
        let device = PlaybackOnlyRTCAudioDevice()
        #expect(!device.isInitialized)
        #expect(!device.initializePlayout())
        #expect(!device.startPlayout())
        #expect(!device.isPlaying)
        // Nothing was started, so stopping has nothing to undo.
        #expect(device.stopPlayout())
        #expect(!device.isPlayoutInitialized)
    }
}
