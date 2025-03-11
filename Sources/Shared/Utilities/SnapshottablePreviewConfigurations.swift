import SwiftUI

public struct SnapshottablePreviewConfigurations<Item> {
    public struct Configuration<ConfigurationItem>: Identifiable {
        public let item: ConfigurationItem
        public let name: String

        public var id: String { name }

        public init(item: ConfigurationItem, name: String) {
            self.item = item
            self.name = name
        }
    }

    public let configurations: [Configuration<Item>]
    let configure: (Item) -> AnyView

    public init(
        configurations: [Configuration<Item>],
        configure: @escaping (Item) -> some View
    ) {
        self.configurations = configurations
        self.configure = { AnyView(configure($0)) }
    }

    @ViewBuilder
    public func view(_ item: Item) -> some View {
        configure(item)
    }

    @ViewBuilder
    public func previews() -> some View {
        ForEach(configurations) { configuration in
            view(configuration.item)
                .previewDisplayName(configuration.name)
        }
    }
}
