import Eureka
import Foundation
import Shared
import UIKit

public final class YamlSection: Section {
    private let yamlRow = TextAreaRow { row in
        row.value = ""
        row.textAreaHeight = .dynamic(initialTextViewHeight: 100)

        row.cellSetup { cell, _ in
            cell.textView.configureCodeFont()
        }
    }

    private let yamlGetter: () -> String

    public init(
        tag: String,
        header: String,
        yamlGetter: @escaping () -> String,
        present: @escaping (UIViewController) -> Void
    ) {
        self.yamlGetter = yamlGetter

        super.init(
            header: header,
            footer: nil
        )

        self.tag = tag

        self
            <<< yamlRow
            <<< ButtonRow { row in
                row.title = L10n.ActionsConfigurator.TriggerExample.share

                row.onCellSelection { [yamlRow, present, yamlGetter] cell, _ in
                    // although this could be done via presentationMode, we want to preserve the 'button' look
                    let value = yamlRow.value ?? yamlGetter()
                    let controller = UIActivityViewController(activityItems: [value], applicationActivities: [])
                    controller.popoverPresentationController?.sourceView = cell
                    controller.popoverPresentationController?.sourceRect = cell.bounds
                    present(controller)
                }
            }

        yamlRow.value = yamlGetter()
    }

    @available(*, unavailable)
    required init<S>(_ elements: S) where S: Sequence, S.Element == BaseRow {
        fatalError("init(_:) has not been implemented")
    }

    @available(*, unavailable)
    required init() {
        fatalError("init() has not been implemented")
    }

    public func update() {
        yamlRow.value = yamlGetter()
        yamlRow.updateCell()
    }
}
