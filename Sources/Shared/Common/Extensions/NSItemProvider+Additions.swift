import CoreServices
import Foundation
import PromiseKit

public struct ItemProviderRequest<Type> {
    internal let utType: String
    internal init(_ utType: CFString) {
        self.utType = utType as String
    }

    public static var url: ItemProviderRequest<URL> { .init(kUTTypeURL) }
    public static var text: ItemProviderRequest<String> { .init(kUTTypeText) }
}

public extension NSItemProvider {
    func item<T>(for request: ItemProviderRequest<T>) -> Promise<T> {
        Promise { seal in
            loadItem(forTypeIdentifier: request.utType, options: nil, completionHandler: { value, error in
                seal.resolve(value as? T, error)
            })
        }
    }
}

public extension NSExtensionContext {
    func inputItemAttachments<T>(for request: ItemProviderRequest<T>) -> Guarantee<[T]> {
        let extensionItems = inputItems.compactMap { $0 as? NSExtensionItem }
        let attachments = extensionItems
            .flatMap { $0.attachments ?? [] }
            .map { $0.item(for: request) }

        return when(resolved: attachments).compactMapValues {
            switch $0 {
            case let .fulfilled(value): return value
            case .rejected: return nil
            }
        }
    }
}
