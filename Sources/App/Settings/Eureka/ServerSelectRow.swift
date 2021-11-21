import Eureka
import Shared

final class ServerSelectRow: _PushRow<PushSelectorCell<AccountRowValue>>, RowType {
    public required convenience init(tag: String?) {
        self.init(tag: tag, includeAll: false)
    }

    init(tag: String?, includeAll: Bool) {
        super.init(tag: tag)
        title = NSLocalizedString("Server", comment: "")
        selectorTitle = NSLocalizedString("Server", comment: "")
        displayValueFor = { value in
            if case let .server(server) = value {
                return server.info.name
            } else {
                return value?.placeholderTitle
            }
        }
        optionsProvider = .lazy { _cell, handler in
            var values = [AccountRowValue]()

            if includeAll {
                values.append(.all)
            }

            values.append(contentsOf: Current.servers.all.map { .server($0) })

            handler(values)
        }
        onPresent { _, to in
            to.enableDeselection = false
        }
    }
}

