import SwiftUI

struct NoteStatusChipView: View {
    let title: String
    let isComplete: Bool

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(isComplete ? Color.accentColor : Color(.tertiaryLabel))

            Text(title)
                .font(.system(size: 10.5, weight: .regular))
                .foregroundStyle(isComplete ? Color.accentColor : Color(.secondaryLabel))
        }
    }
}
