import Eureka
import Foundation
import RealmSwift
import Shared

public final class RealmSection<ObjectType: Object>: Section {
    private let collection: AnyRealmCollection<ObjectType>
    private let getter: (ObjectType) -> [BaseRow]?
    private let emptyRows: [BaseRow]
    private let didUpdate: (Section, AnyRealmCollection<ObjectType>) -> Void

    private var observeTokens: [NotificationToken] = []

    convenience init(
        header: String? = nil,
        footer: String? = nil,
        collection: AnyRealmCollection<ObjectType>,
        emptyRows: [BaseRow] = [],
        getter: @escaping (ObjectType) -> BaseRow?,
        didUpdate: @escaping (Section, AnyRealmCollection<ObjectType>) -> Void = { _, _ in }
    ) {
        self.init(
            header: header,
            footer: footer,
            collection: collection,
            emptyRows: emptyRows,
            getter: { getter($0).flatMap { [$0] } },
            didUpdate: didUpdate
        )
    }

    init(
        header: String? = nil,
        footer: String? = nil,
        collection: AnyRealmCollection<ObjectType>,
        emptyRows: [BaseRow] = [],
        getter: @escaping (ObjectType) -> [BaseRow]?,
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
            let appendingRows = collection.compactMap { (object: ObjectType) -> [BaseRow]? in
                let rows = self.getter(object)
                // we rely on remove/insert, and eureka doesn't handle this -- even if it's the same === row!
                rows?.forEach { $0.tag = nil }
                return rows
            }.flatMap { $0 }

            // note: eureka has a bug if we don't wrap this in Array where it duplicates
            append(contentsOf: Array(appendingRows))
        }

        didUpdate(self, collection)

        evaluateHidden()

        reload()
        tableView?.endUpdates()
    }
}
