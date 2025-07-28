import WatchKit

extension WKInterfaceLabel {
    func setTextAndHideIfEmpty(_ text: String) {
        setText(text)
        setHidden(text.isEmpty)
    }
}
