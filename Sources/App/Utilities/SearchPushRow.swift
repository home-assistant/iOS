// swiftformat:disable fileHeader
// From https://gist.github.com/gotelgest/cf309f6e2095ff22a20b09ba5c95be36

import Eureka
import Foundation
import UIKit

// swiftlint:disable type_name line_length
open class _SearchSelectorViewController<
    Row: SelectableRowType,
    OptionsRow: OptionsProviderRow
>: SelectorViewController<OptionsRow>,
    UISearchResultsUpdating where Row.Cell.Value: SearchItem {
    private var notificationCenterObservers: [AnyObject] = []

    let searchController = UISearchController(searchResultsController: nil)

    var originalOptions = [ListCheckRow<Row.Cell.Value>]()
    var currentOptions = [ListCheckRow<Row.Cell.Value>]()

    deinit {
        notificationCenterObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    override open func viewDidLoad() {
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
            guard let tableView,
                  let screenFrameValue = note.userInfo?[UIApplication.keyboardFrameEndUserInfoKey] as? NSValue else {
                return
            }

            let overlap = tableView.convert(screenFrameValue.cgRectValue, from: nil).intersection(tableView.bounds)
            tableView.contentInset.bottom = overlap.height
            tableView.verticalScrollIndicatorInsets.bottom = overlap.height
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

    override open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        currentOptions.count
    }

    override open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let option = currentOptions[indexPath.row]
        option.updateCell()
        return option.baseCell
    }

    override open func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        nil
    }

    override open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        currentOptions[indexPath.row].didSelect()
        tableView.deselectRow(at: indexPath, animated: true)
    }

    override open func setupForm(with options: [OptionsRow.OptionsProviderType.Option]) {
        super.setupForm(with: options)
        if let allRows = form.first?.map({ $0 }) as? [ListCheckRow<Row.Cell.Value>] {
            originalOptions = allRows
            currentOptions = originalOptions
        }
        tableView.reloadData()
    }
}

open class SearchSelectorViewController<OptionsRow: OptionsProviderRow>: _SearchSelectorViewController<
    ListCheckRow<OptionsRow.OptionsProviderType.Option>,
    OptionsRow
> where OptionsRow.OptionsProviderType.Option: SearchItem {}

open class _SearchPushRow<Cell: CellType>: SelectorRow<Cell> where Cell: BaseCell, Cell.Value: SearchItem {
    public required init(tag: String?) {
        super.init(tag: tag)
        presentationMode = .show(
            controllerProvider: ControllerProvider.callback {
                SearchSelectorViewController<SelectorRow<Cell>> { _ in }
            },
            onDismiss: { vc in
                _ = vc.navigationController?.popViewController(animated: true)
            }
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
        contains(query.lowercased())
    }
}
