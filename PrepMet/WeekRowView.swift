import SwiftUI

struct WeekRowView: View {
    let dates: [Date]
    let selectedDate: Date
    let onSelectDate: (Date) -> Void

    private let calendar = Calendar.current

    var body: some View {
        HStack(spacing: 8) {
            ForEach(dates, id: \.self) { date in
                Button {
                    onSelectDate(date)
                } label: {
                    VStack(spacing: 5) {
                        Text(date.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(isSelected(date) ? Color.accentColor : Color.secondary)

                        ZStack {
                            Circle()
                                .fill(isSelected(date) ? Color.accentColor : Color.clear)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .stroke(todayOutlineColor(for: date), lineWidth: isToday(date) ? 1 : 0)
                                )
                                .shadow(
                                    color: isSelected(date) ? Color.accentColor.opacity(0.14) : .clear,
                                    radius: 5,
                                    y: 2
                                )

                            Text(date.formatted(.dateTime.day()))
                                .font(.system(size: 18, weight: isSelected(date) ? .semibold : .regular))
                                .foregroundStyle(isSelected(date) ? Color.white : Color.primary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func isSelected(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }

    private func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    private func todayOutlineColor(for date: Date) -> Color {
        if isSelected(date) {
            return Color.white.opacity(0.88)
        }

        return Color.accentColor.opacity(0.32)
    }
}
