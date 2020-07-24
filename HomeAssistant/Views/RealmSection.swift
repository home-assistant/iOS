import Foundation
import Eureka
import RealmSwift

final public class RealmSection<ObjectType: Object>: Section {
    private let collection: AnyRealmCollection<ObjectType>
    private let getter: (ObjectType) -> BaseRow?
    private let emptyRows: [BaseRow]
    private let didUpdate: (Section, AnyRealmCollection<ObjectType>) -> Void

    private var observeTokens: [NotificationToken] = []

    init(
        header: String? = nil,
        footer: String? = nil,
        collection: AnyRealmCollection<ObjectType>,
        emptyRows: [BaseRow] = [],
        getter: @escaping (ObjectType) -> BaseRow?,
        didUpdate: @escaping (Section, AnyRealmCollection<ObjectType>) -> Void = { _, _ in }
    ) {
        self.collection = collection
        self.emptyRows = emptyRows
        self.getter = getter
        self.didUpdate = didUpdate
        super.init(header: header, footer: footer)

        let observeToken = collection.observe { [weak self] change in
            switch change {
            case .initial:
                // defering a run loop here causes weird ordering issues with eureka, makes the onChange not fire
                break
            case .update:
                self?.update()
            case .error:
                break
            }
        }

        observeTokens.append(observeToken)

        UIView.performWithoutAnimation {
            update()
        }
    }

    deinit {
        observeTokens.forEach { $0.invalidate() }
    }

    @available(*, unavailable)
    required init<S>(_ elements: S) where S: Sequence, S.Element == BaseRow {
        fatalError("init(_:) has not been implemented")
    }

    @available(*, unavailable)
    required init() {
        fatalError("init() has not been implemented")
    }

    private func update() {
        let tableView = (form?.delegate as? FormViewController)?.tableView

        tableView?.beginUpdates()
        removeAll()

        if collection.isEmpty {
            append(contentsOf: emptyRows)
        } else {
            append(contentsOf: collection.compactMap {
                let row = self.getter($0)
                // we rely on remove/insert, and eureka doesn't handle this -- even if it's the same === row!
                row?.tag = nil
                return row
            })
        }

        didUpdate(self, collection)

        evaluateHidden()
        reload()
        tableView?.endUpdates()
    }
}
