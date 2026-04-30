import SwiftUI

struct TodayEventCardView: View {
    let event: CalendarEvent
    let timeText: String
    let prepComplete: Bool
    let outcomeComplete: Bool
    let nextComplete: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Text(event.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)

                Text(timeText)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }

            HStack(spacing: 10) {
                NoteStatusChipView(title: "Prep", isComplete: prepComplete)
                NoteStatusChipView(title: "Outcome", isComplete: outcomeComplete)
                NoteStatusChipView(title: "Next", isComplete: nextComplete)
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.035), radius: 10, y: 3)
    }
}
