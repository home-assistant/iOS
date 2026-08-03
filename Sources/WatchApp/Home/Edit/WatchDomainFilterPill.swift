import Shared
import SwiftUI

/// A small capsule filter chip used above the entity list to narrow the candidates to a single domain.
struct WatchDomainFilterPill: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(verbatim: title)
                .font(.caption2)
                .foregroundStyle(.white)
                .padding(.horizontal, DesignSystem.Spaces.one)
                .padding(.vertical, DesignSystem.Spaces.half)
        }
        .buttonStyle(.plain)
        .modify { view in
            if #available(watchOS 26.0, *) {
                view.glassEffect(.regular.tint(selected ? Color.haPrimary : nil).interactive(), in: .capsule)
            } else {
                view
                    .background(selected ? Color.haPrimary : Color.gray.opacity(0.3))
                    .clipShape(Capsule())
            }
        }
        .contentShape(Capsule())
    }
}

#Preview {
    HStack {
        WatchDomainFilterPill(title: "All", selected: true, action: {})
        WatchDomainFilterPill(title: "Light", selected: false, action: {})
    }
}
