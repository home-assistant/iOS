#if !os(watchOS)
import SwiftUI

/// The greeting over the overview. The frontend draws it as a text-only markdown card; here it is
/// simply the line it renders to.
public struct HomeWelcomeHeaderView: View {
    @Environment(\.homeDashboard) private var context

    private let config: HomeDashboardHeaderConfig

    public init(config: HomeDashboardHeaderConfig) {
        self.config = config
    }

    public var body: some View {
        Text(greeting)
            .font(DesignSystem.Font.title2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var greeting: String {
        context.strings.welcomeUser
            .replacingOccurrences(of: "{user}", with: config.userName ?? "")
            .trimmingCharacters(in: .whitespaces)
    }
}

#Preview {
    HomeWelcomeHeaderView(config: HomeDashboardHeaderConfig(userName: "Bruno"))
        .environment(\.homeDashboard, HomeDashboardContext(registry: HomeDashboardSampleHome.registry))
        .padding()
}

#endif
