import UIKit

/// A native time field laid over an `<input type="time">` while it is being edited; see
/// `CatalystTimeInputWorkaround`. Takes and reports values in the `HH:mm` form the input uses, keeping
/// any seconds the input already had.
final class CatalystTimeInputOverlayView: UIView {
    let token: String
    private let datePicker = UIDatePicker()
    private let initialValue: String
    private let onChange: (String) -> Void

    init(token: String, value: String, step: Int, onChange: @escaping (String) -> Void) {
        self.token = token
        self.initialValue = value
        self.onChange = onChange
        super.init(frame: .zero)

        // Looks like a plain text field so it reads as the input itself, not as something on top of it.
        backgroundColor = .systemBackground
        layer.borderWidth = 1
        layer.borderColor = UIColor.separator.cgColor

        datePicker.datePickerMode = .time
        datePicker.preferredDatePickerStyle = .compact
        datePicker.minuteInterval = Self.minuteInterval(forStep: step)
        if let date = Self.date(from: value) {
            datePicker.date = date
        }
        datePicker.addTarget(self, action: #selector(valueChanged), for: .valueChanged)
        datePicker.sizeToFit()
        addSubview(datePicker)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Where the time sits inside the overlay, mirroring how the input draws its value.
    enum Alignment: Equatable {
        case left(inset: CGFloat)
        case center
        case right(inset: CGFloat)
    }

    /// Covers the input's rect (in the superview's coordinates), growing to fit the picker if needed.
    func place(over rect: CGRect, cornerRadius: CGFloat, alignment: Alignment) {
        layer.cornerRadius = cornerRadius
        let pickerSize = datePicker.bounds.size
        let width = max(rect.width, pickerSize.width)
        let height = max(rect.height, pickerSize.height)
        frame = CGRect(x: rect.midX - width / 2, y: rect.midY - height / 2, width: width, height: height)

        let x: CGFloat
        switch alignment {
        case let .left(inset):
            x = min(inset, width - pickerSize.width)
        case .center:
            x = (width - pickerSize.width) / 2
        case let .right(inset):
            x = max(width - pickerSize.width - inset, 0)
        }
        datePicker.frame.origin = CGPoint(x: x, y: (height - pickerSize.height) / 2)
    }

    /// Moves keyboard focus into the picker so typing edits the time right away: into the field (hour or
    /// minute) closest to `point`, in this view's coordinates, or the first one. The compact picker does
    /// not take focus itself; its fields do. The web view takes focus back while it finishes handling the
    /// click that opened the overlay, so focus is claimed again once that is done.
    func beginEditing(near point: CGPoint?) {
        for delay in [0, Self.refocusDelay] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, window != nil, !Self.containsFirstResponder(datePicker) else { return }
                focusableField(near: point)?.becomeFirstResponder()
            }
        }
    }

    private static let refocusDelay: TimeInterval = 0.25

    private func focusableField(near point: CGPoint?) -> UIView? {
        let fields = Self.focusableViews(in: datePicker)
        guard let point else { return fields.first }
        return fields.min { first, second in
            distance(of: first, to: point) < distance(of: second, to: point)
        }
    }

    private func distance(of field: UIView, to point: CGPoint) -> CGFloat {
        abs(convert(field.bounds, from: field).midX - point.x)
    }

    private static func focusableViews(in view: UIView) -> [UIView] {
        view.canBecomeFirstResponder ? [view] : view.subviews.flatMap(focusableViews)
    }

    private static func containsFirstResponder(_ view: UIView) -> Bool {
        view.isFirstResponder || view.subviews.contains(where: containsFirstResponder)
    }

    @objc private func valueChanged() {
        onChange(Self.value(from: datePicker.date, keepingSecondsOf: initialValue))
    }

    /// `step` is in seconds; `UIDatePicker` only accepts whole-minute divisors of 60 up to 30.
    static func minuteInterval(forStep step: Int) -> Int {
        guard step >= 60, step.isMultiple(of: 60) else { return 1 }
        let minutes = step / 60
        return minutes <= 30 && 60.isMultiple(of: minutes) ? minutes : 1
    }

    static func date(from value: String, calendar: Calendar = .current, now: Date = Date()) -> Date? {
        let parts = value.split(separator: ":")
        guard parts.count >= 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0 ..< 24).contains(hour), (0 ..< 60).contains(minute) else {
            return nil
        }
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now)
    }

    static func value(from date: Date, keepingSecondsOf previous: String, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let seconds = previous.split(separator: ":", maxSplits: 2).dropFirst(2).first.map { ":" + $0 } ?? ""
        return String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0) + seconds
    }
}
