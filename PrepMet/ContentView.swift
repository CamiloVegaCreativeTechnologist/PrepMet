import SwiftUI

struct ContentView: View {
    @StateObject private var permissionManager = CalendarPermissionManager()

    @State private var selectedDate = Date()
    @State private var displayedWeekStart =
        Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start
        ?? Calendar.current.startOfDay(for: Date())

    @State private var weekTransitionDirection = 1
    @State private var displayedMonth =
        Calendar.current.dateInterval(of: .month, for: Date())?.start
        ?? Calendar.current.startOfDay(for: Date())
    @State private var isEventComposerPresented = false

    private let calendar = Calendar.current

    private let eventTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Button {
                                jumpToToday()
                            } label: {
                                Text("Today")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 16)
                                    .frame(height: 40)
                                    .background(Color(.systemBackground), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)

                            Spacer()

                            if permissionManager.permissionState == .granted {
                                NavigationLink {
                                    SearchReviewView(eventStore: permissionManager.calendarStore)
                                } label: {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 20, weight: .regular))
                                        .foregroundStyle(.primary)
                                        .frame(width: 40, height: 40)
                                        .background(Color(.systemBackground), in: Circle())
                                }
                                .buttonStyle(.plain)
                                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
                            }
                        }

                        if permissionManager.permissionState == .granted {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                                    .font(.system(size: 18, weight: .semibold))

                                ZStack {
                                    WeekRowView(
                                        dates: currentWeekDates,
                                        selectedDate: selectedDate,
                                        onSelectDate: { selectedDate = $0 }
                                    )
                                    .id(displayedWeekStart)
                                    .transition(weekTransition)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 66)
                                .clipped()
                                .contentShape(Rectangle())
                                .simultaneousGesture(
                                    DragGesture(minimumDistance: 24)
                                        .onEnded { value in
                                            if value.translation.width < -50 {
                                                shiftWeek(by: 1)
                                            } else if value.translation.width > 50 {
                                                shiftWeek(by: -1)
                                            }
                                        }
                                )

                                SelectedDayHeaderView(
                                    title: selectedDayTitle,
                                    subtitle: eventCountSummary,
                                    onCreateEvent: { isEventComposerPresented = true }
                                )
                            }
                        } else {
                            Text("Calendar Permission")
                                .font(.headline)
                        }

                        if permissionManager.permissionState != .granted {
                            Text(statusText)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(statusColor)
                                .frame(maxWidth: .infinity)
                        }

                        if permissionManager.permissionState == .notDetermined {
                            Button("Allow Calendar Access") {
                                permissionManager.requestCalendarPermission()
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        if permissionManager.permissionState == .granted {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 12) {
                                    if permissionManager.events.isEmpty {
                                        Text(emptyStateText)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.top, 8)
                                    } else {
                                        ForEach(permissionManager.events) { event in
                                            NavigationLink {
                                                EventDetailView(event: event)
                                            } label: {
                                                TodayEventCardView(
                                                    event: event,
                                                    timeText: eventTimeFormatter.string(from: event.startDate),
                                                    prepComplete: hasSavedNote(for: event, section: "Prep"),
                                                    outcomeComplete: hasSavedNote(for: event, section: "Outcome"),
                                                    nextComplete: hasSavedNote(for: event, section: "Next")
                                                )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                .padding(.trailing, 1)
                                .padding(.bottom, 2)
                            }
                            .scrollIndicators(.hidden)
                            .padding(.top, 10)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        }

                        if permissionManager.permissionState == .denied {
                            Text("Calendar access is denied or restricted. You can enable it later in Settings.")
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(24)
                }
            }
        }
        .sheet(isPresented: $isEventComposerPresented, onDismiss: refreshSelectedDayContent) {
            CalendarEventComposerView(
                isPresented: $isEventComposerPresented,
                eventStore: permissionManager.calendarStore,
                selectedDate: selectedDate
            )
        }
        .onAppear {
            displayedWeekStart = startOfWeek(for: selectedDate)
            displayedMonth = startOfMonth(for: selectedDate)

            if permissionManager.permissionState == .granted {
                permissionManager.fetchEvents(for: selectedDate)
            }
        }
        .onChange(of: selectedDate, initial: false) { _, newValue in
            let newWeekStart = startOfWeek(for: newValue)
            if !calendar.isDate(newWeekStart, inSameDayAs: displayedWeekStart) {
                displayedWeekStart = newWeekStart
            }

            displayedMonth = startOfMonth(for: newValue)

            if permissionManager.permissionState == .granted {
                permissionManager.fetchEvents(for: newValue)
            }
        }
        .onChange(of: permissionManager.permissionState, initial: false) { _, newValue in
            if newValue == .granted {
                permissionManager.fetchEvents(for: selectedDate)
            }
        }
    }

    private var statusText: String {
        switch permissionManager.permissionState {
        case .notDetermined:
            return "Not determined"
        case .granted:
            return "Granted"
        case .denied:
            return "Denied or restricted"
        case .error(let message):
            return "Error: \(message)"
        }
    }

    private var statusColor: Color {
        switch permissionManager.permissionState {
        case .notDetermined:
            return .primary
        case .granted:
            return .green
        case .denied:
            return .red
        case .error:
            return .orange
        }
    }

    private var currentWeekDates: [Date] {
        (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: displayedWeekStart)
        }
    }

    private var weekTransition: AnyTransition {
        let insertionEdge: Edge = weekTransitionDirection > 0 ? .trailing : .leading
        let removalEdge: Edge = weekTransitionDirection > 0 ? .leading : .trailing

        return .asymmetric(
            insertion: .move(edge: insertionEdge).combined(with: .opacity),
            removal: .move(edge: removalEdge).combined(with: .opacity)
        )
    }

    private var selectedDayTitle: String {
        if calendar.isDateInToday(selectedDate) {
            return "Today"
        }

        return selectedDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private var emptyStateText: String {
        if calendar.isDateInToday(selectedDate) {
            return "No events today"
        }

        return "No events on \(selectedDate.formatted(.dateTime.weekday(.wide)))"
    }

    private var eventCountSummary: String {
        let count = permissionManager.events.count
        let eventLabel = count == 1 ? "event" : "events"

        if calendar.isDateInToday(selectedDate) {
            return "You have \(count) \(eventLabel) today"
        }

        return "You have \(count) \(eventLabel) on this day"
    }

    private func hasSavedNote(for event: CalendarEvent, section: String) -> Bool {
        let key = "PrepMet.\(event.id).\(section)"
        let text = UserDefaults.standard.string(forKey: key)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !text.isEmpty
    }

    private func shiftWeek(by value: Int) {
        guard let newSelectedDate = calendar.date(byAdding: .day, value: value * 7, to: selectedDate) else {
            return
        }

        weekTransitionDirection = value

        withAnimation(.easeInOut(duration: 0.28)) {
            displayedWeekStart = startOfWeek(for: newSelectedDate)
            selectedDate = newSelectedDate
        }
    }

    private func jumpToToday() {
        let today = Date()
        let todayWeekStart = startOfWeek(for: today)
        let todayMonthStart = startOfMonth(for: today)

        withAnimation(.easeInOut(duration: 0.25)) {
            selectedDate = today
            displayedWeekStart = todayWeekStart
            displayedMonth = todayMonthStart
        }

        if permissionManager.permissionState == .granted {
            permissionManager.fetchEvents(for: today)
        }
    }

    private func startOfWeek(for date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    private func startOfMonth(for date: Date) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    private func refreshSelectedDayContent() {
        guard permissionManager.permissionState == .granted else { return }
        permissionManager.fetchEvents(for: selectedDate)
    }
}

#Preview {
    Text("Preview disabled for heavy screen")
}
