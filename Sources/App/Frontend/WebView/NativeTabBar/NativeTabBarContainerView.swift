import SFSafeSymbols
import Shared
import SwiftUI

/// The App Labs native iOS tab bar: pinned sidebar pages, More and the iOS 26 search tab (which opens the
/// frontend's quick search). One `WebViewController` moves between tabs through `NativeTabBarFrontendSlot`.
@available(iOS 26, *)
struct NativeTabBarContainerView: View {
    private enum Constants {
        static let tabIconSize: CGFloat = 24
    }

    @ObservedObject var viewModel: NativeTabBarViewModel
    let webViewController: WebViewController?
    let frontendOpacity: Double
    let frontendIgnoredSafeAreaEdges: Edge.Set
    let onNeedsWebViewController: () -> Void

    var body: some View {
        TabView(selection: Binding(
            get: { viewModel.selection },
            set: { viewModel.didSelect($0) }
        )) {
            ForEach(viewModel.tabItems) { item in
                Tab(value: NativeTabBarTab.panel(id: item.id)) {
                    NativeTabBarFrontendSlot(
                        controller: webViewController,
                        isActive: viewModel.selection == .panel(id: item.id),
                        onNeedsController: onNeedsWebViewController
                    )
                    .opacity(frontendOpacity)
                    .ignoresSafeArea(edges: frontendIgnoredSafeAreaEdges)
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
            } label: {
                Label(L10n.TabBar.More.title, systemSymbol: .ellipsis)
            }
            Tab(value: NativeTabBarTab.search, role: .search) {
                Color.clear
            }
        }
        .tabViewSearchActivation(.searchTabSelection)
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
