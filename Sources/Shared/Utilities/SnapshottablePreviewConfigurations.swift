import SwiftUI

/// Struct to hold different preview configurations that can be reused for snapshot testing
///
/// Each configuration holds an item, of generic type Item, and a name.
/// A configure function is also provided that outputs a SwiftUI View, taking an item as input.
///
/// Usage example:
/// ```
/// struct MyView_Previews: PreviewProvider {
///   static var previews: some View {
/// 	configuration.previews()
///   }
///
///   static var configuration: SnapshottablePreviewConfigurations<String> = {
/// 	.init(
/// 	  configurations: [
/// 		.init(item: "1st", name: "First"),
/// 		.init(
/// 		  item: "2nd",
/// 		  name: "Second"
/// 		),
/// 	  ],
/// 	  configure: { configuration in
/// 		Text(configuration)
/// 	  }
/// 	)
///   }()
/// }
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
