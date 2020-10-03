//
//  SearchPushRow.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 2/18/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//
// From https://gist.github.com/gotelgest/cf309f6e2095ff22a20b09ba5c95be36

import Foundation
import Eureka

// swiftlint:disable type_name line_length
open class _SearchSelectorViewController<Row: SelectableRowType, OptionsRow: OptionsProviderRow>: SelectorViewController<OptionsRow>, UISearchResultsUpdating where Row.Cell.Value: SearchItem {

    private var notificationCenterObservers: [AnyObject] = []

    let searchController = UISearchController(searchResultsController: nil)

    var originalOptions = [ListCheckRow<Row.Cell.Value>]()
    var currentOptions = [ListCheckRow<Row.Cell.Value>]()

    deinit {
        notificationCenterObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    open override func viewDidLoad() {
        super.viewDidLoad()

        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false

        navigationItem.hidesSearchBarWhenScrolling = false
        navigationItem.searchController = searchController

        notificationCenterObservers.append(NotificationCenter.default.addObserver(
            forName: UIApplication.keyboardWillChangeFrameNotification,
            object: nil,
            queue: .main
        ) { [tableView] note in
            guard let tableView = tableView,
                let screenFrameValue = note.userInfo?[UIApplication.keyboardFrameEndUserInfoKey] as? NSValue else {
                return
            }

            let overlap = tableView.convert(screenFrameValue.cgRectValue, from: nil).intersection(tableView.bounds)
            tableView.contentInset.bottom = overlap.height

            if #available(iOS 13, *) {
                tableView.verticalScrollIndicatorInsets.bottom = overlap.height
            } else {
                tableView.scrollIndicatorInsets.bottom = overlap.height
            }
        })
    }

    public func updateSearchResults(for searchController: UISearchController) {
        guard let query = searchController.searchBar.text else { return }
        if query.isEmpty {
            currentOptions = originalOptions
        } else {
            currentOptions = originalOptions.filter { $0.selectableValue?.matchesSearchQuery(query) ?? false }
        }
        tableView.reloadData()
    }

    open override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentOptions.count
    }

    open override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let option = currentOptions[indexPath.row]
        option.updateCell()
        return option.baseCell
    }

    open override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
    }

    open override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        currentOptions[indexPath.row].didSelect()
        tableView.deselectRow(at: indexPath, animated: true)
    }

    open override func setupForm(with options: [OptionsRow.OptionsProviderType.Option]) {
        super.setupForm(with: options)
        if let allRows = form.first?.map({ $0 }) as? [ListCheckRow<Row.Cell.Value>] {
            originalOptions = allRows
            currentOptions = originalOptions
        }
        tableView.reloadData()
    }
}

open class SearchSelectorViewController<OptionsRow: OptionsProviderRow>: _SearchSelectorViewController<ListCheckRow<OptionsRow.OptionsProviderType.Option>, OptionsRow> where OptionsRow.OptionsProviderType.Option: SearchItem {
}

open class _SearchPushRow<Cell: CellType>: SelectorRow<Cell> where Cell: BaseCell, Cell.Value: SearchItem {
    public required init(tag: String?) {
        super.init(tag: tag)
        presentationMode = .show(controllerProvider: ControllerProvider.callback {
            return SearchSelectorViewController<SelectorRow<Cell>> { _ in }
        }, onDismiss: { vc in
            _ = vc.navigationController?.popViewController(animated: true) }
        )
    }
}

public final class SearchPushRow<T: Equatable>: _SearchPushRow<PushSelectorCell<T>>, RowType where T: SearchItem {
    public required init(tag: String?) {
        super.init(tag: tag)
    }
}

public protocol SearchItem {
    func matchesSearchQuery(_ query: String) -> Bool
}

extension String: SearchItem {
    public func matchesSearchQuery(_ query: String) -> Bool {
        return self.contains(query.lowercased())
    }
}
