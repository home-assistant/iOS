@testable import HomeAssistant

import Shared
import SwiftUI
import Testing
import WidgetKit

struct WidgetOptimisticToggleTests {
    @Test(arguments: [Domain.light, .switch, .inputBoolean, .fan])
    func onlyKnownBinaryStatesAreOptimistic(domain: Domain) throws {
        for rawState in ["on", "off"] {
            let toggle = try #require(WidgetOptimisticToggle(domain: domain, state: state(rawState)))
            #expect(toggle.isOn == (rawState == "on"))
        }
        for rawState in ["unknown", "unavailable", "opening", ""] {
            #expect(WidgetOptimisticToggle(domain: domain, state: state(rawState)) == nil)
        }
        #expect(WidgetOptimisticToggle(domain: domain, state: nil) == nil)
    }

    @Test(arguments: [Domain.lock, .cover, .valve, .script, .scene, .sensor, .climate, .group, .siren])
    func otherDomainsWaitForTheServer(domain: Domain) {
        #expect(WidgetOptimisticToggle(domain: domain, state: state("on")) == nil)
    }

    @Test func customColorsArePreserved() throws {
        let toggle = try #require(WidgetOptimisticToggle(domain: .light, state: state("off"), customColor: .purple))
        #expect(toggle.onColor == .purple)
        #expect(toggle.offColor == .purple)
        #expect(WidgetOptimisticToggle(domain: nil, state: state("on")) == nil)
    }

    @available(iOS 17, *)
    @Test func intentTargetsTheOppositeOfTheDisplayedStateAndHonorsConfirmations() throws {
        let interaction = WidgetTileInteraction(type: .custom, family: .systemMedium)
        for rawState in ["on", "off"] {
            var model = WidgetBasicViewModel(
                id: "s-light.a",
                title: "Light",
                subtitle: rawState,
                interactionType: .appIntent(.toggle(entityId: "light.a", domain: "light", serverId: "s")),
                icon: .lightbulbIcon,
                optimisticToggle: .init(domain: .light, state: state(rawState))
            )
            let intent = try #require(interaction.optimisticIntent(for: model.interactionType, model: model))
            #expect(intent.targetValue == (rawState == "off"))
            #expect(intent.entityId == "light.a")
            #expect(intent.serverId == "s")

            model.requiresConfirmation = true
            #expect(interaction.optimisticIntent(for: model.interactionType, model: model) == nil)
            model.requiresConfirmation = false
            model.showConfirmation = true
            #expect(interaction.optimisticIntent(for: model.interactionType, model: model) == nil)
            model.showConfirmation = false
            model.disabled = true
            #expect(interaction.optimisticIntent(for: model.interactionType, model: model) == nil)
            model.disabled = false
            #expect(interaction.optimisticIntent(for: .appIntent(.refresh), model: model) == nil)
            #expect(
                WidgetTileInteraction(type: .custom, family: .accessoryCircular)
                    .optimisticIntent(for: model.interactionType, model: model) == nil
            )
        }
    }

    private func state(_ rawState: String) -> WidgetEntityState {
        .init(
            value: rawState,
            domainState: nil,
            rawState: rawState,
            deviceClass: nil,
            liveColorHex: nil,
            groupMemberDomain: nil
        )
    }
}
