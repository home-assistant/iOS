import Foundation
@testable import Shared
import Testing

struct RemoteMediaTransportContextWriterTests {
    private func server(
        internalURL: String? = nil,
        externalURL: String? = nil,
        remoteUIURL: String? = nil,
        cloudhookURL: String? = nil,
        useCloud: Bool = true
    ) -> Server {
        .fake { info in
            info.connection.set(address: nil, for: .external)
            info.connection.set(address: internalURL.flatMap(URL.init(string:)), for: .internal)
            info.connection.set(address: externalURL.flatMap(URL.init(string:)), for: .external)
            info.connection.set(address: remoteUIURL.flatMap(URL.init(string:)), for: .remoteUI)
            info.connection.cloudhookURL = cloudhookURL.flatMap(URL.init(string:))
            info.connection.webhookID = "hook-id"
            info.connection.useCloud = useCloud
        }
    }

    private func urls(_ server: Server) -> [String] {
        RemoteMediaTransportContextWriter.webhookURLs(for: server).map(\.absoluteString)
    }

    @Test func cloudhookIsPreferredAndOtherRoutesRemainAsFallbacks() {
        let result = urls(server(
            internalURL: "http://homeassistant.local:8123",
            externalURL: "https://ha.example.com",
            cloudhookURL: "https://hooks.nabu.casa/abc"
        ))
        #expect(result.first == "https://hooks.nabu.casa/abc")
        #expect(result.contains("https://ha.example.com/api/webhook/hook-id"))
        #expect(result.contains("http://homeassistant.local:8123/api/webhook/hook-id"))
    }

    @Test func externalIsPreferredOverInternalWithoutACloudhook() {
        #expect(urls(server(
            internalURL: "http://homeassistant.local:8123",
            externalURL: "https://ha.example.com"
        )) == [
            "https://ha.example.com/api/webhook/hook-id",
            "http://homeassistant.local:8123/api/webhook/hook-id",
        ])
    }

    @Test func remoteUIOutranksExternal() {
        let result = urls(server(
            externalURL: "https://ha.example.com",
            remoteUIURL: "https://remote.nabu.casa"
        ))
        #expect(result.first == "https://remote.nabu.casa/api/webhook/hook-id")
    }

    @Test func remoteUIIsDroppedWhenTheUserOptedOutOfCloud() {
        #expect(urls(server(
            externalURL: "https://ha.example.com",
            remoteUIURL: "https://remote.nabu.casa",
            useCloud: false
        )) == ["https://ha.example.com/api/webhook/hook-id"])
    }

    @Test func internalOnlyServerStillGetsARoute() {
        #expect(urls(server(internalURL: "http://homeassistant.local:8123")) == [
            "http://homeassistant.local:8123/api/webhook/hook-id",
        ])
    }

    @Test func aServerWithNoURLAtAllYieldsNoCandidates() {
        #expect(urls(server()).isEmpty)
    }

    @Test func candidatesAreNotDuplicated() {
        let result = urls(server(internalURL: "https://ha.example.com", externalURL: "https://ha.example.com"))
        #expect(result.count == Set(result).count)
    }

    @Test func contextCarriesTheSelectionAndTheDerivedSecret() {
        let selection = RemoteMediaSelection(serverId: "home", entityId: "media_player.speaker")
        let server = server(externalURL: "https://ha.example.com")
        let context = RemoteMediaTransportContextWriter.context(for: selection, server: server)
        #expect(context.selection == selection)
        #expect(context.webhookURLs == [URL(string: "https://ha.example.com/api/webhook/hook-id")!])
        // This fake registration has no webhook secret, so the payload would go out in plaintext.
        #expect(context.secret == nil)
    }
}
