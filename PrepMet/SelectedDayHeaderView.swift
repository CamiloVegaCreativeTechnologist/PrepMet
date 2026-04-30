import SwiftUI

struct SelectedDayHeaderView: View {
    let title: String
    let subtitle: String
    let onCreateEvent: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 28, weight: .regular))

                Text(subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onCreateEvent) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
    }
}
