import SFSafeSymbols
import Shared
import SwiftUI

/// The App Labs native iOS tab bar: the first entries of the list as tabs, More, and Search or Assist in the
/// iOS 26 search role when one of them holds the last slot. One `WebViewController` moves between tabs through
/// `NativeTabBarFrontendSlot`;
/// `frontendOverlay` (the stand-by loader) covers that slot alone, never the bar or the More list.
@available(iOS 26, *)
struct NativeTabBarContainerView<FrontendOverlay: View>: View {
    private enum Constants {
        static var tabIconSize: CGFloat { 24 }
    }

    @ObservedObject var viewModel: NativeTabBarViewModel
    let webViewController: WebViewController?
    let frontendOpacity: Double
    let frontendIgnoredSafeAreaEdges: Edge.Set
    let onNeedsWebViewController: () -> Void
    @ViewBuilder let frontendOverlay: () -> FrontendOverlay

    var body: some View {
        TabView(selection: Binding(
            get: { viewModel.selection },
            set: { viewModel.didSelect($0) }
        )) {
            ForEach(viewModel.regularTabItems) { item in
                Tab(value: item.tab) {
                    if item.sidebarItem != nil {
                        ZStack {
                            NativeTabBarFrontendSlot(
                                controller: webViewController,
                                isActive: viewModel.selection == item.tab,
                                onNeedsController: onNeedsWebViewController
                            )
                            .opacity(frontendOpacity)
                            .ignoresSafeArea(edges: frontendIgnoredSafeAreaEdges)
                            frontendOverlay()
                        }
                    } else {
                        Color.clear
                    }
                } label: {
                    Label {
                        Text(item.title)
                    } icon: {
                        Image(uiImage: item.icon.image(
                            ofSize: .init(width: Constants.tabIconSize, height: Constants.tabIconSize),
                            color: .label
                        ))
                        .renderingMode(.template)
                    }
                }
            }
            Tab(value: NativeTabBarTab.more) {
                ZStack {
                    NavigationStack {
                        NativeTabBarMoreView(viewModel: viewModel)
                    }
                    if viewModel.moreShowsFrontend {
                        ZStack {
                            NativeTabBarFrontendSlot(
                                controller: webViewController,
                                isActive: viewModel.selection == .more,
                                onNeedsController: onNeedsWebViewController
                            )
                            .opacity(frontendOpacity)
                            .ignoresSafeArea(edges: frontendIgnoredSafeAreaEdges)
                            frontendOverlay()
                        }
                        .transition(.move(edge: .trailing))
                    }
                }
                .animation(DesignSystem.Animation.easeInOutFaster, value: viewModel.moreShowsFrontend)
            } label: {
                Label(L10n.TabBar.More.title, systemSymbol: .ellipsis)
            }
            if let searchRoleItem = viewModel.searchRoleItem {
                if searchRoleItem.kind == .search {
                    Tab(value: NativeTabBarTab.search, role: .search) {
                        Color.clear
                    }
                } else {
                    Tab(value: searchRoleItem.tab, role: .search) {
                        Color.clear
                    } label: {
                        Label {
                            Text(searchRoleItem.title)
                        } icon: {
                            Image(uiImage: searchRoleItem.icon.image(
                                ofSize: .init(width: Constants.tabIconSize, height: Constants.tabIconSize),
                                color: .label
                            ))
                            .renderingMode(.template)
                        }
                    }
                }
            }
        }
        .tabViewSearchActivation(.searchTabSelection)
        .tabBarMinimizeBehavior(.onScrollDown)
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }
}

@available(iOS 26, *)
#Preview {
    NativeTabBarContainerView(
        viewModel: .preview(),
        webViewController: nil,
        frontendOpacity: 1,
        frontendIgnoredSafeAreaEdges: .all,
        onNeedsWebViewController: {}
    ) {
        EmptyView()
    }
}
