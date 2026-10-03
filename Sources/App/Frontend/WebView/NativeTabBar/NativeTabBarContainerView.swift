#if os(iOS)
import SFSafeSymbols
import Shared
import SwiftUI

/// The App Labs native iOS tab bar.
@available(iOS 26, *)
struct NativeTabBarContainerView: View {
    private enum Constants {
        static var tabIconSize: CGFloat { 24 }
    }

    @ObservedObject var viewModel: NativeTabBarViewModel
    @Environment(\.serverSelectionNamespace) private var transitionNamespace
    @State private var hasVerticalBar = false
    let webViewController: WebViewController?
    let frontendOpacity: Double
    let frontendIgnoredSafeAreaEdges: Edge.Set
    let onNeedsWebViewController: () -> Void

    /// The bar hides behind the frontend's more-info dialog: the dialog covers the page the bar would switch
    /// away from, and the frontend reports when it closes or navigates.
    private var tabBarVisibility: Visibility {
        viewModel.isTabBarHidden ? .hidden : .automatic
    }

    var body: some View {
        TabView(selection: Binding(
            get: { viewModel.selection },
            set: { viewModel.didSelect($0) }
        )) {
            ForEach(viewModel.regularTabItems) { item in
                Tab(value: item.tab) {
                    Group {
                        if item.sidebarItem != nil {
                            NativeTabBarFrontendTabView(
                                viewModel: viewModel,
                                item: item,
                                webViewController: webViewController,
                                frontendOpacity: frontendOpacity,
                                frontendIgnoredSafeAreaEdges: frontendIgnoredSafeAreaEdges,
                                showsBarItems: hasVerticalBar,
                                onNeedsWebViewController: onNeedsWebViewController
                            )
                        } else {
                            Color.clear
                        }
                    }
                    .toolbarVisibility(tabBarVisibility, for: .tabBar)
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
                        NativeTabBarFrontendSlot(
                            controller: webViewController,
                            isActive: viewModel.selection == .more,
                            onNeedsController: onNeedsWebViewController
                        )
                        .opacity(frontendOpacity)
                        .ignoresSafeArea(edges: frontendIgnoredSafeAreaEdges)
                        .transition(.move(edge: .trailing))
                    }
                }
                .animation(DesignSystem.Animation.easeInOutFaster, value: viewModel.moreShowsFrontend)
                .toolbarVisibility(tabBarVisibility, for: .tabBar)
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
        .animation(DesignSystem.Animation.easeInOutFaster, value: viewModel.isTabBarHidden)
        .tint(viewModel.accentColor)
        .background(NativeTabBarLongPressInstaller {
            viewModel.showCustomize(zoomingFromButton: false)
        })
        .background(VerticalBarObserver(hasVerticalBar: $hasVerticalBar))
        .onChange(of: hasVerticalBar, initial: true) { _, hasVerticalBar in
            viewModel.usesVerticalBar = hasVerticalBar
        }
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
    )
}
#endif
