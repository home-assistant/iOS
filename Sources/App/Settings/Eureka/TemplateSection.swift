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
        append(loadingRow)
        append(resultRow)
        append(errorRow)

        initializeSection(self)
        initializeInput(inputRow)

        inputRow.onChange { [weak self] _ in
            self?.updateResultSubscription()
        }

        updateResultSubscription(skipDelay: true)
    }

    deinit {
        subscriptionToken?.cancel()
        updateDebounceTimer?.invalidate()
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

    let loadingRow = ActivityIndicatorRow()

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

    private func updateResult(with value: Result<String, Error>?) {
        switch value {
        case let .some(.success(value)):
            resultRow.title = value
            errorRow.title = nil
            resultRow.hidden = false
            errorRow.hidden = true
            loadingRow.hidden = true
        case let .some(.failure(error)):
            resultRow.title = nil
            errorRow.title = error.localizedDescription
            resultRow.hidden = true
            errorRow.hidden = false
            loadingRow.hidden = true
        case .none:
            resultRow.title = nil
            errorRow.title = nil
            resultRow.hidden = true
            errorRow.hidden = true
            loadingRow.hidden = false
        }

        UIView.performWithoutAnimation {
            resultRow.updateCell()
            errorRow.updateCell()

            resultRow.evaluateHidden()
            errorRow.evaluateHidden()
            loadingRow.evaluateHidden()

            if let tableView = inputRow.cell?.formViewController()?.tableView {
                // height may have changed, so we need to re-query. ^ grabs the input row 'cause it is always not hidden
                tableView.performBatchUpdates(nil, completion: nil)
            }
        }
    }

    private func updateResult(from error: Error) {
        updateResult(with: .failure(error))
    }

    private func updateResult(from any: Any) {
        updateResult(with: .init {
            try displayResult(any)
        })
    }

    private var updateDebounceTimer: Timer? {
        didSet {
            oldValue?.invalidate()
        }
    }
    private func updateResultSubscription(skipDelay: Bool = false) {
        subscriptionToken?.cancel()
        updateDebounceTimer?.invalidate()

        guard let template = inputRow.value, !template.isEmpty else {
            updateResult(with: .success(""))
            return
        }

        guard template.containsJinjaTemplate else {
            updateResult(from: template)
            return
        }

        updateResult(with: nil)
        updateDebounceTimer = Timer.scheduledTimer(withTimeInterval: skipDelay ? 0 : 1.0, repeats: false) { [weak self] _ in
            self?.subscriptionToken = Current.apiConnection.subscribe(
                to: .renderTemplate(template),
                initiated: { result in
                    if case let .failure(error) = result {
                        self?.updateResult(from: error)
                    }
                },
                handler: { _, result in
                    self?.updateResult(from: result.result)
                }
            )
        }
    }
}
