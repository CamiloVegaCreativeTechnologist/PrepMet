import SwiftUI

struct MonthCalendarPanelView: View {
    let displayedMonth: Date
    let isMonthJumpPickerPresented: Bool

    @Binding var selectedMonthNumber: Int
    @Binding var selectedYearNumber: Int

    let monthNames: [String]
    let yearOptions: [Int]
    let weekdaySymbols: [String]
    let monthGridDays: [Date?]
    let monthGridHeight: CGFloat
    let monthTransition: AnyTransition
    let selectedDate: Date
    let monthEventDates: Set<Date>
    let onToggleMonthJumpPicker: () -> Void
    let onChangeMonth: (Int) -> Void
    let onSelectDate: (Date) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(.tertiaryLabel))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 12)

            VStack(alignment: .leading, spacing: 0) {
                MonthHeaderView(
                    displayedMonth: displayedMonth,
                    isMonthJumpPickerPresented: isMonthJumpPickerPresented,
                    onToggleMonthJumpPicker: onToggleMonthJumpPicker,
                    onChangeMonth: onChangeMonth
                )

                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.systemBackground))

                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(.separator), lineWidth: 0.6)

                    ZStack(alignment: .top) {
                        if isMonthJumpPickerPresented {
                            MonthYearPickerView(
                                monthNames: monthNames,
                                yearOptions: yearOptions,
                                selectedMonthNumber: $selectedMonthNumber,
                                selectedYearNumber: $selectedYearNumber
                            )
                            .padding(.top, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        } else {
                            MonthGridView(
                                displayedMonth: displayedMonth,
                                weekdaySymbols: weekdaySymbols,
                                monthGridDays: monthGridDays,
                                monthGridHeight: monthGridHeight,
                                monthTransition: monthTransition,
                                selectedDate: selectedDate,
                                monthEventDates: monthEventDates,
                                onSelectDate: onSelectDate
                            )
                            .transition(.opacity)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .animation(.easeInOut(duration: 0.22), value: isMonthJumpPickerPresented)
                }
                .frame(height: monthGridHeight + 34)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(.separator), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 6, y: -1)
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }
}

private struct MonthHeaderView: View {
    let displayedMonth: Date
    let isMonthJumpPickerPresented: Bool
    let onToggleMonthJumpPicker: () -> Void
    let onChangeMonth: (Int) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Button(action: onToggleMonthJumpPicker) {
                HStack(spacing: 4) {
                    Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.primary)

                    Image(systemName: isMonthJumpPickerPresented ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            HStack(spacing: 20) {
                Button {
                    onChangeMonth(-1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                }

                Button {
                    onChangeMonth(1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .foregroundStyle(Color.accentColor)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }
}

private struct MonthGridView: View {
    let displayedMonth: Date
    let weekdaySymbols: [String]
    let monthGridDays: [Date?]
    let monthGridHeight: CGFloat
    let monthTransition: AnyTransition
    let selectedDate: Date
    let monthEventDates: Set<Date>
    let onSelectDate: (Date) -> Void

    private let monthGridSpacing: CGFloat = 8
    private let monthDayCellHeight: CGFloat = 38

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            ZStack {
                LazyVGrid(columns: monthGridColumns, spacing: monthGridSpacing) {
                    ForEach(Array(monthGridDays.enumerated()), id: \.offset) { _, date in
                        if let date {
                            Button {
                                onSelectDate(date)
                            } label: {
                                MonthDayCellView(
                                    date: date,
                                    selectedDate: selectedDate,
                                    hasEvents: monthEventDates.contains(Calendar.current.startOfDay(for: date)),
                                    height: monthDayCellHeight
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            Color.clear
                                .frame(height: monthDayCellHeight)
                        }
                    }
                }
                .id(displayedMonth)
                .transition(monthTransition)
            }
            .frame(height: monthGridHeight)
            .clipped()
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private var monthGridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: monthGridSpacing), count: 7)
    }
}

private struct MonthDayCellView: View {
    let date: Date
    let selectedDate: Date
    let hasEvents: Bool
    let height: CGFloat

    private let calendar = Calendar.current

    var body: some View {
        let isSelectedDate = calendar.isDate(date, inSameDayAs: selectedDate)
        let isTodayDate = calendar.isDateInToday(date)

        VStack(spacing: 3) {
            ZStack {
                Circle()
                    .fill(
                        isSelectedDate
                            ? Color.accentColor
                            : (isTodayDate ? Color.accentColor.opacity(0.08) : Color.clear)
                    )
                    .frame(width: 30, height: 30)
                    .overlay(
                        Circle()
                            .stroke(todayOutlineColor(isSelected: isSelectedDate), lineWidth: isTodayDate ? 1 : 0)
                    )
                    .shadow(
                        color: isSelectedDate ? Color.accentColor.opacity(0.16) : .clear,
                        radius: 6,
                        y: 2
                    )

                Text(date.formatted(.dateTime.day()))
                    .font(.subheadline.weight(isSelectedDate ? .semibold : (isTodayDate ? .medium : .regular)))
                    .foregroundStyle(isSelectedDate ? Color.white : Color.primary)
            }

            Capsule()
                .fill(isSelectedDate ? Color.white.opacity(0.88) : Color.accentColor.opacity(0.38))
                .frame(width: 3.5, height: 3.5)
                .opacity(hasEvents ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
    }

    private func todayOutlineColor(isSelected: Bool) -> Color {
        if isSelected {
            return Color.white.opacity(0.88)
        }

        return Color.accentColor.opacity(0.32)
    }
}

private struct MonthYearPickerView: View {
    let monthNames: [String]
    let yearOptions: [Int]

    @Binding var selectedMonthNumber: Int
    @Binding var selectedYearNumber: Int

    var body: some View {
        HStack(spacing: 0) {
            Picker("Month", selection: $selectedMonthNumber) {
                ForEach(Array(monthNames.enumerated()), id: \.offset) { index, monthName in
                    Text(monthName).tag(index + 1)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .clipped()

            Picker("Year", selection: $selectedYearNumber) {
                ForEach(yearOptions, id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .clipped()
        }
        .frame(height: 216)
        .background(Color(.systemBackground))
        .background(alignment: .center) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.systemBackground))
                .frame(height: 36)
                .padding(.horizontal, 16)
        }
        .overlay(alignment: .center) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(.separator), lineWidth: 0.5)
                .frame(height: 36)
                .padding(.horizontal, 16)
                .allowsHitTesting(false)
        }
    }
}
