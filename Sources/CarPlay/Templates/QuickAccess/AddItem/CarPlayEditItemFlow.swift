import CarPlay
import Foundation
import Shared

@available(iOS 16.0, *)
final class CarPlayEditItemFlow {
    typealias DisplayItem = (title: String, subtitle: String?, image: UIImage)

    private weak var interfaceController: CPInterfaceController?
    private let viewModel: CarPlayAddItemViewModel
    private let itemDisplay: (MagicItem) -> DisplayItem
    private let onFinish: () -> Void

    private let template = CPListTemplate(title: L10n.CarPlay.QuickAccess.EditItem.title, sections: [])

    init(
        interfaceController: CPInterfaceController?,
        viewModel: CarPlayAddItemViewModel = CarPlayAddItemViewModel(),
        itemDisplay: @escaping (MagicItem) -> DisplayItem,
        onFinish: @escaping () -> Void
    ) {
        self.interfaceController = interfaceController
        self.viewModel = viewModel
        self.itemDisplay = itemDisplay
        self.onFinish = onFinish
    }

    func start() {
        let items = viewModel.quickAccessItems
        guard !items.isEmpty else {
            Current.Log.error("Attempted to start CarPlay edit item flow without any items")
            onFinish()
            return
        }

        interfaceController?.pushTemplate(template, animated: true, completion: nil)
        render(items: items)
    }

    private func render(items: [MagicItem]) {
        let rows = items.prefix(Int(CPListTemplate.maximumItemCount)).map { item -> CPListItem in
            let display = itemDisplay(item)
            let row = CPListItem(
                text: display.title,
                detailText: display.subtitle,
                image: display.image
            )
            row.handler = { [weak self] _, completion in
                self?.presentConfirmation(item: item, title: display.title)
                completion()
            }
            return row
        }

        template.updateSections([CPListSection(items: Array(rows))])
    }

    private func presentConfirmation(item: MagicItem, title: String) {
        let deleteAction = CPAlertAction(
            title: L10n.delete,
            style: .destructive
        ) { [weak self] _ in
            self?.delete(item: item)
        }
        let requireConfirmationAction = CPAlertAction(
            title: L10n.CarPlay.QuickAccess.AddItem.Confirmation.require,
            style: .default
        ) { [weak self] _ in
            self?.updateConfirmation(item: item, requiresConfirmation: true)
        }
        let noConfirmationAction = CPAlertAction(
            title: L10n.CarPlay.QuickAccess.EditItem.Confirmation.noConfirmation,
            style: .default
        ) { [weak self] _ in
            self?.updateConfirmation(item: item, requiresConfirmation: false)
        }
        let cancelAction = CPAlertAction(
            title: L10n.Alerts.Confirm.cancel,
            style: .cancel
        ) { [weak self] _ in
            self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
        }

        let actionSheet = CPActionSheetTemplate(
            title: title,
            message: nil,
            actions: [deleteAction, requireConfirmationAction, noConfirmationAction, cancelAction]
        )
        interfaceController?.presentTemplate(actionSheet, animated: true, completion: nil)
    }

    private func delete(item: MagicItem) {
        viewModel.deleteItemFromQuickAccess(item)
        finish()
    }

    private func updateConfirmation(item: MagicItem, requiresConfirmation: Bool) {
        viewModel.updateItemConfirmation(item, requiresConfirmation: requiresConfirmation)
        finish()
    }

    private func finish() {
        interfaceController?.dismissTemplate(animated: true, completion: nil)
        interfaceController?.popToRootTemplate(animated: true, completion: nil)
        onFinish()
    }
}
