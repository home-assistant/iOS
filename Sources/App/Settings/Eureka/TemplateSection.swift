import HAKit
import Shared
import Eureka

public final class TemplateSection: Section {
    private var subscriptionToken: HACancellable?
    var displayResult: (Any) throws -> String

    init(
        header: String? = nil,
        footer: String? = nil,
        displayResult: @escaping (Any) throws -> String = { String(describing: $0) },
        initializeInput: (TextAreaRow) -> Void,
        initializeSection: (Section) -> Void
    ) {
        self.displayResult = displayResult
        super.init(header: header, footer: footer)

        append(inputRow)
        append(resultRow)
        append(errorRow)

        updateResult(.success(""))

        initializeSection(self)
        initializeInput(inputRow)

        inputRow.onChange { [weak self] _ in
            self?.updateResultSubscription()
        }

        updateResultSubscription()
    }

    @available(*, unavailable)
    required init() {
        fatalError("init() has not been implemented")
    }

    @available(*, unavailable)
    required init<S>(_ elements: S) where S: Sequence, S.Element == BaseRow {
        fatalError("init(_:) has not been implemented")
    }

    let inputRow = TextAreaRow {
        $0.cellSetup { cell, _ in
            cell.textView.keyboardType = .asciiCapable
            cell.textView.smartQuotesType = .no
            cell.textView.smartDashesType = .no
            cell.textView.smartInsertDeleteType = .no
            cell.textView.autocorrectionType = .no
            cell.textView.autocapitalizationType = .none
            cell.textView.spellCheckingType = .no
        }
    }

    let resultRow = LabelRow {
        $0.cellUpdate { cell, row in
            cell.textLabel?.numberOfLines = 0

            if #available(iOS 13, *) {
                cell.textLabel?.textColor = .secondaryLabel
            } else {
                cell.textLabel?.textColor = .gray
            }
        }
    }

    let errorRow = LabelRow {
        $0.cellUpdate { cell, _ in
            cell.textLabel?.numberOfLines = 0

            if #available(iOS 13, *) {
                cell.textLabel?.textColor = .systemRed
            } else {
                cell.textLabel?.textColor = .red
            }
        }
    }

    private func updateResult(_ value: Result<String, Error>) {
        switch value {
        case let .success(value):
            resultRow.title = value
            errorRow.title = nil
            resultRow.hidden = false
            errorRow.hidden = true
        case let .failure(error):
            resultRow.title = nil
            errorRow.title = error.localizedDescription
            resultRow.hidden = true
            errorRow.hidden = false
        }

        resultRow.updateCell()
        errorRow.updateCell()

        resultRow.evaluateHidden()
        errorRow.evaluateHidden()

        if let tableView = inputRow.cell?.formViewController()?.tableView {
            // height may have changed, so we need to re-query. ^ grabs the input row 'cause it is always not hidden
            UIView.performWithoutAnimation {
                tableView.performBatchUpdates(nil, completion: nil)
            }
        }
    }

    private func updateResultSubscription() {
        subscriptionToken?.cancel()

        guard let template = inputRow.value, !template.isEmpty else {
            updateResult(.success(""))
            return
        }

        subscriptionToken = Current.apiConnection.subscribe(
            to: .renderTemplate(inputRow.value ?? ""),
            initiated: { [weak self] result in
                switch result {
                case let .failure(error):
                    self?.updateResult(.failure(error))
                case .success: break
                }
            },
            handler: { [weak self] _, result in
                guard let self = self else { return }

                self.updateResult(.init {
                    try self.displayResult(result.result)
                })
            }
        )
    }
}
