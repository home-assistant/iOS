import Foundation
@testable import Shared
import Testing

@Suite(.serialized)
struct RemoteMediaSelectionTests {
    @Test func selectionPersistsAndCanBeCleared() throws {
        let store = Current.settingsStore
        let previousRecord = store.remoteMediaFollowRecord
        let previousSequence = store.remoteMediaFollowSequence
        defer {
            store.remoteMediaFollowRecord = previousRecord
            store.remoteMediaFollowSequence = previousSequence
        }
        let selection = RemoteMediaSelection(serverId: "home", entityId: "media_player.speaker")
        store.startRemoteMediaFollowLifetime(following: selection)
        #expect(SettingsStore().remoteMediaSelection == selection)
        store.startRemoteMediaFollowLifetime(following: nil)
        #expect(SettingsStore().remoteMediaSelection == nil)
    }

    @Test func malformedSelectionIsIgnored() {
        let prefs = Current.settingsStore.prefs
        let previousRecord = prefs.data(forKey: "remoteMediaFollowRecord")
        let previous = prefs.data(forKey: "remoteMediaSelection")
        defer {
            prefs.set(previousRecord, forKey: "remoteMediaFollowRecord")
            prefs.set(previous, forKey: "remoteMediaSelection")
        }
        prefs.removeObject(forKey: "remoteMediaFollowRecord")
        prefs.set(Data("invalid".utf8), forKey: "remoteMediaSelection")
        #expect(Current.settingsStore.remoteMediaSelection == nil)
    }

    /// The identifier length-prefixes the server id, so a different split of the same characters
    /// cannot produce the same session.
    @Test func identifiersDoNotCollideAcrossServers() {
        let first = RemoteMediaSelection(serverId: "ab", entityId: "media_player.x")
        let second = RemoteMediaSelection(serverId: "a", entityId: "bmedia_player.x")
        #expect(first.id != second.id)
    }
}
