@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing

/// Renders the CarPlay tab picker with built-in, Quick Access folder and tab-only folder tabs, and
/// re-renders it as tabs are turned on and off.
@MainActor
struct CarPlayTabsSelectionViewTests {
    private func viewModel() -> CarPlayConfigurationViewModel {
        let viewModel = CarPlayConfigurationViewModel()
        viewModel.addFolder(named: "Errands")
        viewModel.addTabFolder(named: "Commute")
        return viewModel
    }

    @Test func rendersActiveAndInactiveTabsAndTogglesThem() {
        let viewModel = viewModel()
        let host = CarPlaySwiftUIHost(NavigationStack { CarPlayTabsSelectionView(viewModel: viewModel) })
        defer { host.close() }

        #expect(viewModel.config.tabs.contains { $0.folderId != nil })
        #expect(!viewModel.config.tabs.contains(.domains))
        #expect(viewModel.config.tabs.contains(.quickAccess))

        // What tapping the inactive Domains row and the active Quick Access row does: SwiftUI rows
        // don't expose accessibility elements to activate in a hosted unit test, so the test drives
        // the view model and re-renders the screen in each state.
        viewModel.updateTab(.domains, active: true)
        host.layout()
        #expect(viewModel.config.tabs.contains(.domains))

        viewModel.updateTab(.quickAccess, active: false)
        host.layout()
        #expect(!viewModel.config.tabs.contains(.quickAccess))
    }

    /// With every tab active there is no inactive section at all.
    @Test func rendersWithoutInactiveTabs() {
        let viewModel = CarPlayConfigurationViewModel()
        viewModel.updateTab(.domains, active: true)
        let host = CarPlaySwiftUIHost(NavigationStack { CarPlayTabsSelectionView(viewModel: viewModel) })
        defer { host.close() }

        #expect(Set(viewModel.config.tabs) == Set(CarPlayTab.allCases))
    }
}
