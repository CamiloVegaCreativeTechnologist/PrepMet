import EventKit
import SwiftUI

struct SearchReviewView: View {
    @Environment(\.dismiss) private var dismiss

    private let eventStore: EKEventStore
    private let calendar = Calendar.current
    private let monthGridSpacing: CGFloat = 8
    private let monthDayCellHeight: CGFloat = 38

    @State private var query = ""
    @State private var isDateFilterActive = false
    @State private var selectedDate = Date()
    @State private var results: [SearchResult] = []

    @State private var isMonthCalendarPresented = false
    @State private var displayedMonth =
        Calendar.current.dateInterval(of: .month, for: Date())?.start
        ?? Calendar.current.startOfDay(for: Date())
    @State private var monthEventDates: Set<Date> = []
    @State private var isMonthJumpPickerPresented = false
    @State private var selectedMonthNumber = Calendar.current.component(.month, from: Date())
    @State private var selectedYearNumber = Calendar.current.component(.year, from: Date())
    @State private var monthTransitionDirection = 1

    @GestureState private var monthPanelDragOffset: CGFloat = 0
    @FocusState private var isSearchFieldFocused: Bool

    init(eventStore: EKEventStore) {
        self.eventStore = eventStore
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Search")
                                .font(.system(size: 32, weight: .regular))

                            Text("Search titles, Prep, Outcome, and Next notes.")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(.secondary)
                        }

                        if isDateFilterActive {
                            activeDateFilterView
                        }

                        if groupedResults.isEmpty {
                            Text(emptyStateText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                        } else {
                            LazyVStack(alignment: .leading, spacing: 20) {
                                ForEach(groupedResults) { group in
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(group.title)
                                            .font(.headline)
                                            .foregroundStyle(.secondary)

                                        VStack(alignment: .leading, spacing: 12) {
                                            ForEach(group.results) { result in
                                                NavigationLink {
                                                    EventDetailView(event: result.event)
                                                } label: {
                                                    resultCard(for: result)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(24)
                }

                if isMonthCalendarPresented {
                    MonthCalendarPanelView(
                        displayedMonth: displayedMonth,
                        isMonthJumpPickerPresented: isMonthJumpPickerPresented,
                        selectedMonthNumber: $selectedMonthNumber,
                        selectedYearNumber: $selectedYearNumber,
                        monthNames: monthNames,
                        yearOptions: yearOptions,
                        weekdaySymbols: weekdaySymbols,
                        monthGridDays: monthGridDays,
                        monthGridHeight: monthGridHeight,
                        monthTransition: monthTransition,
                        selectedDate: selectedDate,
                        monthEventDates: monthEventDates,
                        onToggleMonthJumpPicker: toggleMonthJumpPicker,
                        onChangeMonth: changeMonth,
                        onSelectDate: handleDateSelection
                    )
                    .offset(y: max(0, monthPanelDragOffset))
                    .simultaneousGesture(monthPanelDismissGesture)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isMonthCalendarPresented {
                searchBarAccessory
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, isSearchFieldFocused ? 8 : 12)
                    .background(Color(.systemGroupedBackground))
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    toggleMonthCalendar()
                } label: {
                    Image(systemName: "calendar")
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut(duration: 0.25), value: isMonthCalendarPresented)
        .animation(.easeInOut(duration: 0.22), value: isSearchFieldFocused)
        .onAppear {
            displayedMonth = startOfMonth(for: Date())
            syncMonthJumpPicker(with: displayedMonth)
            refreshMonthEventDates()
            performSearch()
        }
        .onChange(of: query, initial: false) { _, _ in
            performSearch()
        }
        .onChange(of: isDateFilterActive, initial: false) { _, _ in
            performSearch()
        }
        .onChange(of: selectedDate, initial: false) { _, newValue in
            if isDateFilterActive {
                displayedMonth = startOfMonth(for: newValue)
                performSearch()
            }
        }
        .onChange(of: displayedMonth, initial: false) { _, _ in
            syncMonthJumpPicker(with: displayedMonth)
            refreshMonthEventDates()
        }
        .onChange(of: selectedMonthNumber, initial: false) { _, _ in
            if isMonthJumpPickerPresented {
                updateDisplayedMonthFromJumpPicker()
            }
        }
        .onChange(of: selectedYearNumber, initial: false) { _, _ in
            if isMonthJumpPickerPresented {
                updateDisplayedMonthFromJumpPicker()
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search Prep, Outcome, or Next", text: $query)
                .focused($isSearchFieldFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color(.systemBackground))
        )
        .overlay(
            Capsule()
                .stroke(Color(.separator), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 4, y: 1)
    }

    private var searchBarAccessory: some View {
        HStack(spacing: 10) {
            searchField
                .frame(maxWidth: .infinity)

            if isSearchFieldFocused {
                Button(action: cancelSearchMode) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .background(
                            Capsule()
                                .fill(Color(.systemBackground))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color(.separator), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }

    private var activeDateFilterView: some View {
        HStack(spacing: 10) {
            Label(selectedDateFilterText, systemImage: "calendar")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Button("Clear") {
                clearDateFilter()
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.accentColor)
            .buttonStyle(.plain)
        }
    }

    private var selectedDateFilterText: String {
        if calendar.isDateInToday(selectedDate) {
            return "Today"
        }

        if calendar.isDateInYesterday(selectedDate) {
            return "Yesterday"
        }

        return selectedDate.formatted(.dateTime.month(.abbreviated).day().year())
    }

    private var groupedResults: [SearchResultGroup] {
        if results.isEmpty {
            return []
        }

        if isDateFilterActive {
            return [
                SearchResultGroup(
                    title: selectedDateGroupTitle,
                    results: results.sorted { $0.event.startDate < $1.event.startDate }
                )
            ]
        }

        let grouped = Dictionary(grouping: results) { result in
            groupKind(for: result.event.startDate)
        }

        let order: [SearchGroupKind] = [.today, .yesterday, .lastSevenDays, .upcoming, .older]

        return order.compactMap { kind in
            guard let groupedResults = grouped[kind], !groupedResults.isEmpty else {
                return nil
            }

            return SearchResultGroup(
                title: kind.title,
                results: groupedResults.sorted { $0.event.startDate > $1.event.startDate }
            )
        }
    }

    private var selectedDateGroupTitle: String {
        if calendar.isDateInToday(selectedDate) {
            return "Today"
        }

        if calendar.isDateInYesterday(selectedDate) {
            return "Yesterday"
        }

        return selectedDate.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private var emptyStateText: String {
        let trimmedQuery = normalizedQuery

        if isDateFilterActive && trimmedQuery.isEmpty {
            if calendar.isDateInToday(selectedDate) {
                return "No events found for today."
            }

            return "No events found for this date."
        }

        if !trimmedQuery.isEmpty && isDateFilterActive {
            return "No matches found for that date."
        }

        if !trimmedQuery.isEmpty {
            return "No matches found."
        }

        return "No saved review notes yet."
    }

    private var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var monthTransition: AnyTransition {
        let insertionEdge: Edge = monthTransitionDirection > 0 ? .trailing : .leading
        let removalEdge: Edge = monthTransitionDirection > 0 ? .leading : .trailing

        return .asymmetric(
            insertion: .move(edge: insertionEdge).combined(with: .opacity),
            removal: .move(edge: removalEdge).combined(with: .opacity)
        )
    }

    private var monthPanelDismissGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .updating($monthPanelDragOffset) { value, state, _ in
                guard
                    value.translation.height > 0,
                    abs(value.translation.height) > abs(value.translation.width)
                else {
                    return
                }

                state = value.translation.height
            }
            .onEnded { value in
                guard
                    value.translation.height > 80,
                    abs(value.translation.height) > abs(value.translation.width)
                else {
                    return
                }

                dismissMonthCalendar()
            }
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let firstWeekdayIndex = max(calendar.firstWeekday - 1, 0)
        return Array(symbols[firstWeekdayIndex...]) + Array(symbols[..<firstWeekdayIndex])
    }

    private var monthGridDays: [Date?] {
        guard
            let monthRange = calendar.range(of: .day, in: .month, for: displayedMonth),
            let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
        else {
            return []
        }

        let weekday = calendar.component(.weekday, from: firstDayOfMonth)
        let leadingEmptyDays = (weekday - calendar.firstWeekday + 7) % 7

        var days = Array<Date?>(repeating: nil, count: leadingEmptyDays)

        for day in monthRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(date)
            }
        }

        while days.count < 42 {
            days.append(nil)
        }

        return days
    }

    private var monthGridHeight: CGFloat {
        (monthDayCellHeight * 6) + (monthGridSpacing * 5)
    }

    private var monthNames: [String] {
        DateFormatter().monthSymbols
    }

    private var yearOptions: [Int] {
        let currentYear = calendar.component(.year, from: Date())
        return Array((currentYear - 25)...(currentYear + 25))
    }

    private func performSearch() {
        let trimmedQuery = normalizedQuery
        let savedNotes = loadSavedNotes()

        var matchedByID: [String: SearchResult] = [:]

        let eventsToSearch: [EKEvent]
        if isDateFilterActive {
            eventsToSearch = fetchEvents(for: selectedDate)
        } else if trimmedQuery.isEmpty {
            eventsToSearch = savedNotes.keys.compactMap(eventForIdentifier)
        } else {
            eventsToSearch = fetchEventsForSearchWindow()
        }

        for event in eventsToSearch {
            guard let calendarEvent = makeCalendarEvent(from: event) else {
                continue
            }

            let notes = savedNotes[calendarEvent.id] ?? SavedNotes()
            if matches(event: calendarEvent, notes: notes, query: trimmedQuery) {
                matchedByID[calendarEvent.id] = SearchResult(
                    event: calendarEvent,
                    notes: notes,
                    snippet: makeSnippet(for: calendarEvent, notes: notes, query: trimmedQuery)
                )
            }
        }

        for (eventID, notes) in savedNotes {
            guard let event = eventForIdentifier(eventID), let calendarEvent = makeCalendarEvent(from: event) else {
                continue
            }

            if isDateFilterActive && !calendar.isDate(calendarEvent.startDate, inSameDayAs: selectedDate) {
                continue
            }

            if matches(event: calendarEvent, notes: notes, query: trimmedQuery) {
                matchedByID[calendarEvent.id] = SearchResult(
                    event: calendarEvent,
                    notes: notes,
                    snippet: makeSnippet(for: calendarEvent, notes: notes, query: trimmedQuery)
                )
            }
        }

        if isDateFilterActive && trimmedQuery.isEmpty {
            results = matchedByID.values.sorted { $0.event.startDate < $1.event.startDate }
        } else {
            results = matchedByID.values.sorted { $0.event.startDate > $1.event.startDate }
        }
    }

    private func fetchEvents(for date: Date) -> [EKEvent] {
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        return eventStore.events(matching: predicate)
    }

    private func fetchEventsForSearchWindow() -> [EKEvent] {
        let now = Date()
        let start = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        let end = calendar.date(byAdding: .year, value: 1, to: now) ?? now
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        return eventStore.events(matching: predicate)
    }

    private func eventForIdentifier(_ id: String) -> EKEvent? {
        eventStore.calendarItem(withIdentifier: id) as? EKEvent
    }

    private func makeCalendarEvent(from event: EKEvent) -> CalendarEvent? {
        guard let startDate = event.startDate, let endDate = event.endDate else {
            return nil
        }

        let trimmedTitle = event.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let title = trimmedTitle.isEmpty ? "Untitled Event" : trimmedTitle

        return CalendarEvent(
            id: event.calendarItemIdentifier,
            title: title,
            startDate: startDate,
            endDate: endDate
        )
    }

    private func loadSavedNotes() -> [String: SavedNotes] {
        let defaults = UserDefaults.standard
        let keys = defaults.dictionaryRepresentation().keys
        let prefix = "PrepMet."

        var notesByID: [String: SavedNotes] = [:]

        for key in keys where key.hasPrefix(prefix) {
            if key.hasSuffix(".Prep") {
                let eventID = extractEventID(from: key, suffix: ".Prep")
                notesByID[eventID, default: SavedNotes()].prep = defaults.string(forKey: key) ?? ""
            } else if key.hasSuffix(".Outcome") {
                let eventID = extractEventID(from: key, suffix: ".Outcome")
                notesByID[eventID, default: SavedNotes()].outcome = defaults.string(forKey: key) ?? ""
            } else if key.hasSuffix(".Next") {
                let eventID = extractEventID(from: key, suffix: ".Next")
                notesByID[eventID, default: SavedNotes()].next = defaults.string(forKey: key) ?? ""
            }
        }

        return notesByID.filter { $0.value.hasAnyContent }
    }

    private func extractEventID(from key: String, suffix: String) -> String {
        let trimmedPrefix = key.dropFirst("PrepMet.".count)
        return String(trimmedPrefix.dropLast(suffix.count))
    }

    private func matches(event: CalendarEvent, notes: SavedNotes, query: String) -> Bool {
        if query.isEmpty {
            return isDateFilterActive ? true : notes.hasAnyContent
        }

        if event.title.lowercased().contains(query) {
            return true
        }

        return notes.prep.lowercased().contains(query)
            || notes.outcome.lowercased().contains(query)
            || notes.next.lowercased().contains(query)
    }

    private func makeSnippet(for event: CalendarEvent, notes: SavedNotes, query: String) -> String? {
        let candidates: [(String, String)] = [
            ("Prep", notes.prep),
            ("Outcome", notes.outcome),
            ("Next", notes.next)
        ]

        if !query.isEmpty {
            for (label, value) in candidates {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.lowercased().contains(query) {
                    return "\(label): \(snippetText(from: trimmed))"
                }
            }

            if event.title.lowercased().contains(query) {
                return event.startDate.formatted(.dateTime.hour().minute())
            }
        }

        for (label, value) in candidates {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return "\(label): \(snippetText(from: trimmed))"
            }
        }

        return nil
    }

    private func snippetText(from text: String) -> String {
        let normalized = text.replacingOccurrences(of: "\n", with: " ")
        if normalized.count <= 90 {
            return normalized
        }

        let index = normalized.index(normalized.startIndex, offsetBy: 90)
        return normalized[..<index].trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private func groupKind(for date: Date) -> SearchGroupKind {
        if calendar.isDateInToday(date) {
            return .today
        }

        if calendar.isDateInYesterday(date) {
            return .yesterday
        }

        let startOfToday = calendar.startOfDay(for: Date())
        if let lastWeekStart = calendar.date(byAdding: .day, value: -6, to: startOfToday),
           date >= lastWeekStart, date < startOfToday {
            return .lastSevenDays
        }

        if date > startOfToday {
            return .upcoming
        }

        return .older
    }

    private func resultCard(for result: SearchResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.event.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(cardSubtitle(for: result.event))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }

            if let snippet = result.snippet {
                Text(snippet)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            HStack(spacing: 10) {
                noteStatusChip(title: "Prep", isComplete: result.notes.hasPrep)
                noteStatusChip(title: "Outcome", isComplete: result.notes.hasOutcome)
                noteStatusChip(title: "Next", isComplete: result.notes.hasNext)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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

    private func cardSubtitle(for event: CalendarEvent) -> String {
        let time = event.startDate.formatted(.dateTime.hour().minute())
        let endTime = event.endDate.formatted(.dateTime.hour().minute())

        if isDateFilterActive {
            return "\(time) - \(endTime)"
        }

        if calendar.isDateInToday(event.startDate) {
            return "Today, \(time)"
        }

        if calendar.isDateInYesterday(event.startDate) {
            return "Yesterday, \(time)"
        }

        return event.startDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
    }

    private func noteStatusChip(title: String, isComplete: Bool) -> some View {
        HStack(spacing: 3) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(isComplete ? Color.accentColor : Color(.tertiaryLabel))

            Text(title)
                .font(.system(size: 10.5, weight: .regular))
                .foregroundStyle(isComplete ? Color.accentColor : Color(.secondaryLabel))
        }
    }

    private func toggleMonthCalendar() {
        isSearchFieldFocused = false

        if !isMonthCalendarPresented {
            let focusDate = isDateFilterActive ? selectedDate : Date()
            displayedMonth = startOfMonth(for: focusDate)
            refreshMonthEventDates()
            syncMonthJumpPicker(with: displayedMonth)

            withAnimation(.easeInOut(duration: 0.25)) {
                isMonthCalendarPresented = true
            }
            return
        }

        dismissMonthCalendar()
    }

    private func toggleMonthJumpPicker() {
        if !isMonthJumpPickerPresented {
            syncMonthJumpPicker(with: displayedMonth)
        }

        withAnimation(.easeInOut(duration: 0.22)) {
            isMonthJumpPickerPresented.toggle()
        }
    }

    private func handleDateSelection(_ date: Date) {
        selectedDate = date
        isDateFilterActive = true
    }

    private func clearDateFilter() {
        isDateFilterActive = false
    }

    private func cancelSearchMode() {
        query = ""
        isSearchFieldFocused = false
    }

    private func changeMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) else {
            return
        }

        setDisplayedMonth(newMonth, direction: value)
    }

    private func refreshMonthEventDates() {
        monthEventDates = eventDates(inMonthContaining: displayedMonth)
    }

    private func eventDates(inMonthContaining date: Date) -> Set<Date> {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: date),
            let lastDayOfMonth = calendar.date(byAdding: .day, value: -1, to: monthInterval.end)
        else {
            return []
        }

        let predicate = eventStore.predicateForEvents(
            withStart: monthInterval.start,
            end: monthInterval.end,
            calendars: nil
        )

        var datesWithEvents = Set<Date>()

        for event in eventStore.events(matching: predicate) {
            guard let startDate = event.startDate, let endDate = event.endDate else {
                continue
            }

            let firstDay = max(calendar.startOfDay(for: startDate), monthInterval.start)
            let lastRelevantDate = endDate > startDate
                ? endDate.addingTimeInterval(-1)
                : endDate
            let lastDay = min(calendar.startOfDay(for: lastRelevantDate), lastDayOfMonth)

            var currentDay = firstDay
            while currentDay <= lastDay {
                datesWithEvents.insert(currentDay)

                guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDay) else {
                    break
                }

                currentDay = nextDay
            }
        }

        return datesWithEvents
    }

    private func updateDisplayedMonthFromJumpPicker() {
        var components = DateComponents()
        components.year = selectedYearNumber
        components.month = selectedMonthNumber
        components.day = 1

        guard let newMonth = calendar.date(from: components) else {
            return
        }

        setDisplayedMonth(newMonth, direction: newMonth >= displayedMonth ? 1 : -1)
    }

    private func syncMonthJumpPicker(with date: Date) {
        selectedMonthNumber = calendar.component(.month, from: date)
        selectedYearNumber = calendar.component(.year, from: date)
    }

    private func startOfMonth(for date: Date) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    private func setDisplayedMonth(_ newMonth: Date, direction: Int? = nil, animated: Bool = true) {
        let normalizedMonth = startOfMonth(for: newMonth)

        guard !calendar.isDate(normalizedMonth, equalTo: displayedMonth, toGranularity: .month) else {
            return
        }

        monthTransitionDirection = direction ?? (normalizedMonth > displayedMonth ? 1 : -1)

        if animated {
            withAnimation(.easeInOut(duration: 0.28)) {
                displayedMonth = normalizedMonth
            }
        } else {
            displayedMonth = normalizedMonth
        }
    }

    private func dismissMonthCalendar() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isMonthJumpPickerPresented = false
            isMonthCalendarPresented = false
        }
    }
}

private struct SearchResult: Identifiable {
    let event: CalendarEvent
    let notes: SavedNotes
    let snippet: String?

    var id: String { event.id }
}

private struct SearchResultGroup: Identifiable {
    let title: String
    let results: [SearchResult]

    var id: String { title }
}

private struct SavedNotes {
    var prep = ""
    var outcome = ""
    var next = ""

    var hasPrep: Bool {
        !prep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasOutcome: Bool {
        !outcome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasNext: Bool {
        !next.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasAnyContent: Bool {
        hasPrep || hasOutcome || hasNext
    }
}

private enum SearchGroupKind: Hashable {
    case today
    case yesterday
    case lastSevenDays
    case upcoming
    case older

    var title: String {
        switch self {
        case .today:
            return "Today"
        case .yesterday:
            return "Yesterday"
        case .lastSevenDays:
            return "Last 7 Days"
        case .upcoming:
            return "Upcoming"
        case .older:
            return "Older"
        }
    }
}
