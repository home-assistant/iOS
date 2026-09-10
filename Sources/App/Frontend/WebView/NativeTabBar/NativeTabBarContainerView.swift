import SFSafeSymbols
import Shared
import SwiftUI

/// The App Labs native iOS tab bar.
@available(iOS 26, *)
struct NativeTabBarContainerView<FrontendOverlay: View>: View {
    private enum Constants {
        static var tabIconSize: CGFloat { 24 }
    }

    @ObservedObject var viewModel: NativeTabBarViewModel
    @Environment(\.serverSelectionNamespace) private var transitionNamespace
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
        .background(NativeTabBarLongPressInstaller {
            viewModel.showCustomize(zoomingFromButton: false)
        })
        .sheet(isPresented: $viewModel.showsCustomize) {
            NavigationStack {
                NativeTabBarCustomizeView(viewModel: viewModel)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            CloseButton {
                                viewModel.showsCustomize = false
                            }
                        }
                    }
            }
            .modify { view in
                if viewModel.customizeZoomsFromButton, let transitionNamespace {
                    view.navigationTransition(.zoom(
                        sourceID: NativeTabBarViewModel.customizeTransitionID,
                        in: transitionNamespace
                    ))
                } else {
                    view
                }
            }
        }
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
