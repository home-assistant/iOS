import Eureka
import Shared

public final class LearnMoreButtonRow: _ButtonRowOf<URL>, RowType {
    public required init(tag: String?) {
        super.init(tag: tag)

        title = L10n.Nfc.List.learnMore
    }

    override public func updateCell() {
        super.updateCell()

        cell.textLabel?.textAlignment = .natural
    }

    override public func customDidSelect() {
        guard let url = value else { return }
        openURLInBrowser(url, cell.formViewController())
        deselect(animated: true)
    }
}
