import EventKit
import EventKitUI
import SwiftUI
import UIKit

struct EventDetailView: View {
    @Environment(\.dismiss) private var dismiss

    fileprivate enum NoteCategory: String, CaseIterable, Identifiable {
        case prep = "Prep"
        case outcome = "Outcome"
        case next = "Next"

        var id: String { rawValue }

        var segmentIndex: Int {
            Self.allCases.firstIndex(of: self) ?? 0
        }

        init?(segmentIndex: Int) {
            guard Self.allCases.indices.contains(segmentIndex) else {
                return nil
            }

            self = Self.allCases[segmentIndex]
        }
    }

    let event: CalendarEvent

    @State private var selectedNoteCategory: NoteCategory = .prep
    @State private var prepText = ""
    @State private var outcomeText = ""
    @State private var nextText = ""
    @State private var prepRichTextData: Data?
    @State private var outcomeRichTextData: Data?
    @State private var nextRichTextData: Data?
    @State private var editorFocusRequest = 0
    @State private var isNextActionFlowPresented = false
    @State private var navigationTargetEvent: CalendarEvent?
    @State private var isNavigationTargetPresented = false

    private let eventStore = EKEventStore()

    private let eventScheduleFormatter: DateIntervalFormatter = {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayTitle)
                            .font(.system(size: 28, weight: .regular))
                            .foregroundStyle(.primary)

                        Text(eventScheduleText)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(.secondary)
                    }

                    noteCategoryPicker

                    VStack(alignment: .leading, spacing: 12) {
                        Text(selectedNoteCategory.rawValue)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)

                        RichNoteTextEditor(
                            plainText: selectedNoteText,
                            archivedRichText: selectedNoteRichTextData,
                            focusRequest: editorFocusRequest
                        )
                        .id(selectedNoteCategory)
                        .frame(minHeight: 280, alignment: .topLeading)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                topControlButton(
                    systemName: "chevron.left",
                    font: .system(size: 17, weight: .semibold),
                    action: { dismiss() }
                )
            }

            if selectedNoteCategory == .next {
                ToolbarItem(placement: .topBarTrailing) {
                    topControlButton(
                        systemName: "calendar.badge.plus",
                        font: .system(size: 18, weight: .medium),
                        action: { isNextActionFlowPresented = true }
                    )
                }
            }
        }
        .sheet(isPresented: $isNextActionFlowPresented) {
            NextActionFlowSheet(
                currentEvent: event,
                sourceNextText: trimmedNextText,
                eventStore: eventStore,
                onOpenEvent: { openedEvent in
                    navigationTargetEvent = openedEvent
                    isNavigationTargetPresented = true
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .navigationDestination(isPresented: $isNavigationTargetPresented) {
            if let navigationTargetEvent {
                EventDetailView(event: navigationTargetEvent)
            }
        }
        .onAppear {
            loadStoredNotes()
            requestEditorFocus()
        }
        .onChange(of: selectedNoteCategory, initial: false) { _, _ in
            requestEditorFocus()
        }
    }

    private var displayTitle: String {
        let trimmedTitle = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? "Untitled Event" : trimmedTitle
    }

    private var eventScheduleText: String {
        let dayText = event.startDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        let timeRangeText = eventScheduleFormatter.string(from: event.startDate, to: event.endDate)
        return "\(dayText) · \(timeRangeText)"
    }

    private var trimmedNextText: String {
        nextText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var noteCategoryPicker: some View {
        NoteCategorySegmentedControl(selection: $selectedNoteCategory)
            .frame(height: 32)
    }

    private var selectedNoteText: Binding<String> {
        Binding(
            get: {
                switch selectedNoteCategory {
                case .prep:
                    return prepText
                case .outcome:
                    return outcomeText
                case .next:
                    return nextText
                }
            },
            set: { newValue in
                switch selectedNoteCategory {
                case .prep:
                    prepText = newValue
                case .outcome:
                    outcomeText = newValue
                case .next:
                    nextText = newValue
                }

                UserDefaults.standard.set(newValue, forKey: storageKey(for: selectedNoteCategory))
            }
        )
    }

    private var selectedNoteRichTextData: Binding<Data?> {
        Binding(
            get: {
                switch selectedNoteCategory {
                case .prep:
                    return prepRichTextData
                case .outcome:
                    return outcomeRichTextData
                case .next:
                    return nextRichTextData
                }
            },
            set: { newValue in
                switch selectedNoteCategory {
                case .prep:
                    prepRichTextData = newValue
                case .outcome:
                    outcomeRichTextData = newValue
                case .next:
                    nextRichTextData = newValue
                }

                let key = richTextStorageKey(for: selectedNoteCategory)
                if let newValue {
                    UserDefaults.standard.set(newValue, forKey: key)
                } else {
                    UserDefaults.standard.removeObject(forKey: key)
                }
            }
        )
    }

    private func topControlButton(systemName: String, font: Font, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(font)
                .foregroundStyle(.primary)
                .frame(width: 40, height: 40)
                .background(Color(.systemBackground), in: Circle())
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func loadStoredNotes() {
        let defaults = UserDefaults.standard

        prepText = defaults.string(forKey: storageKey(for: .prep)) ?? ""
        outcomeText = defaults.string(forKey: storageKey(for: .outcome)) ?? ""
        nextText = defaults.string(forKey: storageKey(for: .next)) ?? ""

        prepRichTextData = defaults.data(forKey: richTextStorageKey(for: .prep))
        outcomeRichTextData = defaults.data(forKey: richTextStorageKey(for: .outcome))
        nextRichTextData = defaults.data(forKey: richTextStorageKey(for: .next))
    }

    private func requestEditorFocus() {
        editorFocusRequest += 1
    }

    private func storageKey(for category: NoteCategory) -> String {
        prepMetStorageKey(eventID: event.id, categoryName: category.rawValue)
    }

    private func richTextStorageKey(for category: NoteCategory) -> String {
        prepMetRichTextStorageKey(eventID: event.id, categoryName: category.rawValue)
    }
}

private struct NextActionFlowSheet: View {
    private enum Step {
        case options
        case existingEvent
        case confirmSelection
        case linkError
    }

    @Environment(\.dismiss) private var dismiss

    let currentEvent: CalendarEvent
    let sourceNextText: String
    let eventStore: EKEventStore
    let onOpenEvent: (CalendarEvent) -> Void

    @State private var step: Step = .options
    @State private var shouldCopyNextIntoPrep = false
    @State private var shouldOpenEventInPrepMet = true
    @State private var isEventCreationPresented = false
    @State private var selectedCandidateEvent: CalendarEvent?
    @State private var linkFailureEvent: CalendarEvent?
    @State private var linkErrorBackStep: Step = .options

    @State private var selectedExistingDate: Date
    @State private var displayedMonth: Date
    @State private var monthEventDates: Set<Date> = []
    @State private var isMonthJumpPickerPresented = false
    @State private var selectedMonthNumber: Int
    @State private var selectedYearNumber: Int
    @State private var monthTransitionDirection = 1
    @State private var eventsOnSelectedDate: [CalendarEvent] = []

    private let calendar = Calendar.current
    private let monthGridSpacing: CGFloat = 8
    private let monthDayCellHeight: CGFloat = 38

    private let listTimeFormatter: DateIntervalFormatter = {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    init(
        currentEvent: CalendarEvent,
        sourceNextText: String,
        eventStore: EKEventStore,
        onOpenEvent: @escaping (CalendarEvent) -> Void
    ) {
        self.currentEvent = currentEvent
        self.sourceNextText = sourceNextText
        self.eventStore = eventStore
        self.onOpenEvent = onOpenEvent

        let initialDate = Calendar.current.startOfDay(for: currentEvent.startDate)
        let initialMonth = Calendar.current.dateInterval(of: .month, for: initialDate)?.start
            ?? Calendar.current.startOfDay(for: initialDate)

        _selectedExistingDate = State(initialValue: initialDate)
        _displayedMonth = State(initialValue: initialMonth)
        _selectedMonthNumber = State(initialValue: Calendar.current.component(.month, from: initialDate))
        _selectedYearNumber = State(initialValue: Calendar.current.component(.year, from: initialDate))
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                sheetHeader

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch step {
                        case .options:
                            optionsStepContent
                        case .existingEvent:
                            existingEventStepContent
                        case .confirmSelection:
                            confirmationStepContent
                        case .linkError:
                            linkErrorStepContent
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .sheet(isPresented: $isEventCreationPresented) {
            CalendarEventCreationSheet(
                eventStore: eventStore,
                selectedDate: currentEvent.startDate
            ) { result in
                handleCalendarCreationResult(result)
            }
        }
        .onAppear {
            refreshMonthEventDates()
            refreshEventsOnSelectedDate()
        }
        .onChange(of: displayedMonth, initial: false) { _, _ in
            syncMonthJumpPicker(with: displayedMonth)
            refreshMonthEventDates()
        }
        .onChange(of: selectedMonthNumber, initial: false) { _, _ in
            guard isMonthJumpPickerPresented else { return }
            updateDisplayedMonthFromJumpPicker()
        }
        .onChange(of: selectedYearNumber, initial: false) { _, _ in
            guard isMonthJumpPickerPresented else { return }
            updateDisplayedMonthFromJumpPicker()
        }
    }

    private var sheetHeader: some View {
        HStack(spacing: 12) {
            Button(action: handleHeaderBack) {
                Image(systemName: headerBackSystemName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .background(Color(.systemBackground), in: Circle())
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(headerTitle)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            Color.clear
                .frame(width: 40, height: 40)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var optionsStepContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Use your Next note to prepare another event.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                optionToggleRow(
                    title: "Copy Next text into Prep",
                    isOn: $shouldCopyNextIntoPrep,
                    isEnabled: canCopyNextText
                )

                optionToggleRow(
                    title: "Open event in PrepMet",
                    isOn: $shouldOpenEventInPrepMet,
                    isEnabled: true
                )
            }

            VStack(spacing: 12) {
                optionActionButton(title: "New Event", action: {
                    step = .options
                    isEventCreationPresented = true
                })

                optionActionButton(title: "Existing Event", action: {
                    step = .existingEvent
                    selectedCandidateEvent = nil
                    refreshEventsOnSelectedDate()
                })
            }
        }
    }

    private var existingEventStepContent: some View {
        VStack(alignment: .leading, spacing: 16) {
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
                selectedDate: selectedExistingDate,
                monthEventDates: monthEventDates,
                onToggleMonthJumpPicker: toggleMonthJumpPicker,
                onChangeMonth: changeMonth,
                onSelectDate: handleExistingDateSelection
            )
            .padding(.horizontal, -12)

            Text(selectedExistingDateTitle)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)

            if eventsOnSelectedDate.isEmpty {
                Text("No events on this date")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(eventsOnSelectedDate) { listedEvent in
                        Button {
                            selectedCandidateEvent = listedEvent
                            step = .confirmSelection
                        } label: {
                            existingEventRow(for: listedEvent)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var confirmationStepContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let selectedCandidateEvent {
                VStack(alignment: .leading, spacing: 8) {
                    Text(selectedCandidateEvent.title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(confirmEventDateText(for: selectedCandidateEvent))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(.systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color(.separator), lineWidth: 0.5)
                )

                HStack(spacing: 12) {
                    Button("Cancel") {
                        step = .existingEvent
                    }
                    .buttonStyle(.bordered)

                    Button("Confirm") {
                        applyAction(to: selectedCandidateEvent, backStep: .confirmSelection)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private var linkErrorStepContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Event created, but PrepMet could not link it.")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)

            HStack(spacing: 12) {
                Button("Retry") {
                    guard let linkFailureEvent else { return }
                    applyAction(to: linkFailureEvent, backStep: linkErrorBackStep)
                }
                .buttonStyle(.borderedProminent)

                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var canCopyNextText: Bool {
        !sourceNextText.isEmpty
    }

    private var headerTitle: String {
        switch step {
        case .options:
            return "Next"
        case .existingEvent:
            return "Existing Event"
        case .confirmSelection:
            return "Confirm"
        case .linkError:
            return "Error"
        }
    }

    private var headerBackSystemName: String {
        "chevron.left"
    }

    private var selectedExistingDateTitle: String {
        if calendar.isDateInToday(selectedExistingDate) {
            return "Today"
        }

        if calendar.isDateInYesterday(selectedExistingDate) {
            return "Yesterday"
        }

        return selectedExistingDate.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private var monthTransition: AnyTransition {
        let insertionEdge: Edge = monthTransitionDirection > 0 ? .trailing : .leading
        let removalEdge: Edge = monthTransitionDirection > 0 ? .leading : .trailing

        return .asymmetric(
            insertion: .move(edge: insertionEdge).combined(with: .opacity),
            removal: .move(edge: removalEdge).combined(with: .opacity)
        )
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let firstWeekdayIndex = max(calendar.firstWeekday - 1, 0)
        return Array(symbols[firstWeekdayIndex...]) + Array(symbols[..<firstWeekdayIndex])
    }

    private var monthGridDays: [Date?] {
        guard
            let monthRange = calendar.range(of: .day, in: .month, for: displayedMonth),
            let firstDayOfMonth = calendar.date(
                from: calendar.dateComponents([.year, .month], from: displayedMonth)
            )
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

    private func optionToggleRow(
        title: String,
        isOn: Binding<Bool>,
        isEnabled: Bool
    ) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
        }
        .tint(.accentColor)
        .disabled(!isEnabled)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }

    private func optionActionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 18)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func existingEventRow(for listedEvent: CalendarEvent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(listedEvent.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(existingEventSubtitle(for: listedEvent))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 16)
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
    }

    private func existingEventSubtitle(for listedEvent: CalendarEvent) -> String {
        if calendar.isDateInToday(listedEvent.startDate) {
            return "Today, \(listedEvent.startDate.formatted(.dateTime.hour().minute()))"
        }

        return listTimeFormatter.string(from: listedEvent.startDate, to: listedEvent.endDate)
    }

    private func confirmEventDateText(for selectedEvent: CalendarEvent) -> String {
        let dayText = selectedEvent.startDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        let timeText = listTimeFormatter.string(from: selectedEvent.startDate, to: selectedEvent.endDate)
        return "\(dayText) · \(timeText)"
    }

    private func handleHeaderBack() {
        switch step {
        case .options:
            dismiss()
        case .existingEvent:
            step = .options
        case .confirmSelection:
            step = .existingEvent
        case .linkError:
            step = linkErrorBackStep
        }
    }

    private func handleCalendarCreationResult(_ result: CalendarEventCreationSheet.Result) {
        isEventCreationPresented = false

        switch result {
        case .cancelled:
            step = .options
        case .saved(let createdEvent):
            guard let linkedEvent = makeCalendarEvent(from: createdEvent) else {
                linkFailureEvent = CalendarEvent(
                    id: createdEvent.calendarItemIdentifier,
                    title: createdEvent.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                        ? createdEvent.title!
                        : "Untitled Event",
                    startDate: createdEvent.startDate ?? currentEvent.startDate,
                    endDate: createdEvent.endDate ?? currentEvent.endDate
                )
                linkErrorBackStep = .options
                step = .linkError
                return
            }

            applyAction(to: linkedEvent, backStep: .options)
        }
    }

    private func handleExistingDateSelection(_ date: Date) {
        selectedExistingDate = date
        refreshEventsOnSelectedDate()
    }

    private func applyAction(to targetEvent: CalendarEvent, backStep: Step) {
        guard ensurePrepMetRecord(for: targetEvent) else {
            linkFailureEvent = targetEvent
            linkErrorBackStep = backStep
            step = .linkError
            return
        }

        if shouldCopyNextIntoPrep && canCopyNextText {
            copyNextTextIntoPrep(of: targetEvent)
        }

        if shouldOpenEventInPrepMet {
            let eventToOpen = targetEvent
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                onOpenEvent(eventToOpen)
            }
        } else {
            dismiss()
        }
    }

    private func ensurePrepMetRecord(for targetEvent: CalendarEvent) -> Bool {
        let trimmedID = targetEvent.id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty else {
            return false
        }

        let defaults = UserDefaults.standard

        for category in EventDetailView.NoteCategory.allCases {
            let key = prepMetStorageKey(eventID: trimmedID, categoryName: category.rawValue)
            if defaults.object(forKey: key) == nil {
                defaults.set("", forKey: key)
            }
        }

        return true
    }

    private func copyNextTextIntoPrep(of targetEvent: CalendarEvent) {
        let nextTextToCopy = sourceNextText
        guard !nextTextToCopy.isEmpty else { return }

        let prepKey = prepMetStorageKey(eventID: targetEvent.id, categoryName: EventDetailView.NoteCategory.prep.rawValue)
        let prepRichTextKey = prepMetRichTextStorageKey(
            eventID: targetEvent.id,
            categoryName: EventDetailView.NoteCategory.prep.rawValue
        )

        let defaults = UserDefaults.standard
        let existingPrepText = defaults.string(forKey: prepKey) ?? ""
        let existingPrepRichText = defaults.data(forKey: prepRichTextKey)
        let trimmedExistingPrepText = existingPrepText.trimmingCharacters(in: .whitespacesAndNewlines)

        let updatedPrepText: String
        let updatedPrepAttributedText: NSAttributedString

        if trimmedExistingPrepText.isEmpty {
            updatedPrepText = nextTextToCopy
            updatedPrepAttributedText = PrepMetNoteEditorStyle.attributedText(
                for: nextTextToCopy,
                archivedRichText: nil
            )
        } else {
            updatedPrepText = "\(trimmedExistingPrepText)\n\n---\nCopied from Next\n\(nextTextToCopy)"

            let mutablePrepText = NSMutableAttributedString(
                attributedString: PrepMetNoteEditorStyle.attributedText(
                    for: existingPrepText,
                    archivedRichText: existingPrepRichText
                )
            )
            mutablePrepText.append(
                NSAttributedString(
                    string: "\n\n---\nCopied from Next\n",
                    attributes: PrepMetNoteEditorStyle.baseAttributes()
                )
            )
            mutablePrepText.append(
                NSAttributedString(
                    string: nextTextToCopy,
                    attributes: PrepMetNoteEditorStyle.baseAttributes()
                )
            )
            updatedPrepAttributedText = mutablePrepText
        }

        defaults.set(updatedPrepText, forKey: prepKey)

        if let archivedPrepText = PrepMetNoteEditorStyle.archive(updatedPrepAttributedText) {
            defaults.set(archivedPrepText, forKey: prepRichTextKey)
        } else {
            defaults.removeObject(forKey: prepRichTextKey)
        }
    }

    private func refreshEventsOnSelectedDate() {
        eventsOnSelectedDate = fetchEvents(for: selectedExistingDate)
            .filter { $0.id != currentEvent.id }
            .sorted { $0.startDate < $1.startDate }
    }

    private func refreshMonthEventDates() {
        monthEventDates = eventDates(inMonthContaining: displayedMonth)
    }

    private func fetchEvents(for date: Date) -> [CalendarEvent] {
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        return eventStore.events(matching: predicate).compactMap(makeCalendarEvent)
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

    private func toggleMonthJumpPicker() {
        if !isMonthJumpPickerPresented {
            syncMonthJumpPicker(with: displayedMonth)
        }

        withAnimation(.easeInOut(duration: 0.22)) {
            isMonthJumpPickerPresented.toggle()
        }
    }

    private func changeMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) else {
            return
        }

        setDisplayedMonth(newMonth, direction: value)
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
}

private struct CalendarEventCreationSheet: UIViewControllerRepresentable {
    enum Result {
        case cancelled
        case saved(EKEvent)
    }

    let eventStore: EKEventStore
    let selectedDate: Date
    let onComplete: (Result) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let controller = EKEventEditViewController()
        let event = EKEvent(eventStore: eventStore)
        let calendar = Calendar.current
        let startDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: selectedDate) ?? selectedDate

        event.startDate = startDate
        event.endDate = calendar.date(byAdding: .hour, value: 1, to: startDate) ?? startDate.addingTimeInterval(3600)

        controller.eventStore = eventStore
        controller.event = event
        controller.editViewDelegate = context.coordinator

        return controller
    }

    func updateUIViewController(_ uiViewController: EKEventEditViewController, context: Context) {}

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        private let onComplete: (Result) -> Void

        init(onComplete: @escaping (Result) -> Void) {
            self.onComplete = onComplete
        }

        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            if action == .saved, let event = controller.event {
                onComplete(.saved(event))
            } else {
                onComplete(.cancelled)
            }
        }
    }
}

private struct NoteCategorySegmentedControl: UIViewRepresentable {
    @Binding var selection: EventDetailView.NoteCategory

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeUIView(context: Context) -> UISegmentedControl {
        let control = UISegmentedControl(items: EventDetailView.NoteCategory.allCases.map(\.rawValue))
        control.selectedSegmentIndex = selection.segmentIndex
        control.backgroundColor = .secondarySystemFill
        control.selectedSegmentTintColor = .systemBackground
        control.apportionsSegmentWidthsByContent = false

        let normalAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold)
        ]
        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.systemBlue,
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold)
        ]

        control.setTitleTextAttributes(normalAttributes, for: .normal)
        control.setTitleTextAttributes(selectedAttributes, for: .selected)
        control.addTarget(
            context.coordinator,
            action: #selector(Coordinator.valueChanged(_:)),
            for: .valueChanged
        )

        return control
    }

    func updateUIView(_ control: UISegmentedControl, context: Context) {
        if control.selectedSegmentIndex != selection.segmentIndex {
            control.selectedSegmentIndex = selection.segmentIndex
        }
    }

    final class Coordinator: NSObject {
        @Binding private var selection: EventDetailView.NoteCategory

        init(selection: Binding<EventDetailView.NoteCategory>) {
            _selection = selection
        }

        @objc func valueChanged(_ sender: UISegmentedControl) {
            guard let category = EventDetailView.NoteCategory(segmentIndex: sender.selectedSegmentIndex) else {
                return
            }

            selection = category
        }
    }
}

private struct RichNoteTextEditor: UIViewRepresentable {
    @Binding var plainText: String
    @Binding var archivedRichText: Data?
    let focusRequest: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(plainText: $plainText, archivedRichText: $archivedRichText)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView(frame: .zero, textContainer: nil)
        context.coordinator.configure(textView)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.plainText = $plainText
        context.coordinator.archivedRichText = $archivedRichText
        context.coordinator.syncDisplayedContent(
            in: textView,
            plainText: plainText,
            archivedRichText: archivedRichText
        )
        context.coordinator.handleFocusRequest(focusRequest, in: textView)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width else {
            return nil
        }

        let fittedSize = uiView.sizeThatFits(
            CGSize(width: width, height: .greatestFiniteMagnitude)
        )

        return CGSize(width: width, height: max(280, fittedSize.height))
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var plainText: Binding<String>
        var archivedRichText: Binding<Data?>

        private weak var textView: UITextView?
        private var isApplyingViewUpdate = false
        private var lastSyncedRichText: Data?
        private var lastHandledFocusRequest = -1

        init(plainText: Binding<String>, archivedRichText: Binding<Data?>) {
            self.plainText = plainText
            self.archivedRichText = archivedRichText
        }

        func configure(_ textView: UITextView) {
            self.textView = textView

            textView.delegate = self
            textView.backgroundColor = .clear
            textView.font = PrepMetNoteEditorStyle.bodyFont
            textView.textColor = .label
            textView.tintColor = .systemBlue
            textView.adjustsFontForContentSizeCategory = true
            textView.isEditable = true
            textView.isSelectable = true
            textView.isScrollEnabled = false
            textView.allowsEditingTextAttributes = true
            textView.typingAttributes = PrepMetNoteEditorStyle.typingAttributes()
            textView.textContainerInset = .zero
            textView.textContainer.lineFragmentPadding = 0
            textView.usesStandardTextScaling = true
            textView.inputAccessoryView = makeAccessoryToolbar()

            if #available(iOS 18.0, *) {
                textView.writingToolsBehavior = .complete
                textView.allowedWritingToolsResultOptions = [.plainText, .richText, .list]
            }
        }

        func syncDisplayedContent(
            in textView: UITextView,
            plainText: String,
            archivedRichText: Data?
        ) {
            let desiredAttributedText = PrepMetNoteEditorStyle.attributedText(
                for: plainText,
                archivedRichText: archivedRichText
            )
            let desiredArchivedText = desiredAttributedText.length > 0
                ? PrepMetNoteEditorStyle.archive(desiredAttributedText)
                : nil

            guard
                desiredArchivedText != lastSyncedRichText
                    || textView.attributedText.string != desiredAttributedText.string
            else {
                return
            }

            let currentSelection = textView.selectedRange

            isApplyingViewUpdate = true
            textView.attributedText = desiredAttributedText
            textView.selectedRange = clampedSelection(
                currentSelection,
                textLength: desiredAttributedText.length
            )
            updateTypingAttributes(in: textView)
            isApplyingViewUpdate = false

            lastSyncedRichText = desiredArchivedText
        }

        func handleFocusRequest(_ focusRequest: Int, in textView: UITextView) {
            guard focusRequest != lastHandledFocusRequest else {
                return
            }

            lastHandledFocusRequest = focusRequest

            DispatchQueue.main.async { [weak textView] in
                textView?.becomeFirstResponder()
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            persistTextState(from: textView)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isApplyingViewUpdate else {
                return
            }

            updateTypingAttributes(in: textView)
        }

        @objc private func toggleBold() {
            toggleFontTrait(.traitBold)
        }

        @objc private func toggleItalic() {
            toggleFontTrait(.traitItalic)
        }

        @objc private func toggleUnderline() {
            guard let textView else { return }

            let selectedRange = textView.selectedRange
            if selectedRange.length == 0 {
                var typingAttributes = mergedTypingAttributes(textView.typingAttributes)
                let currentUnderlineStyle = (typingAttributes[.underlineStyle] as? Int) ?? 0
                typingAttributes[.underlineStyle] = currentUnderlineStyle == 0
                    ? NSUnderlineStyle.single.rawValue
                    : 0
                textView.typingAttributes = typingAttributes
                return
            }

            let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
            let shouldApplyUnderline = !selectionHasUnderline(in: mutableText, range: selectedRange)

            mutableText.enumerateAttribute(.underlineStyle, in: selectedRange, options: []) { _, range, _ in
                let underlineValue = shouldApplyUnderline ? NSUnderlineStyle.single.rawValue : 0
                mutableText.addAttribute(.underlineStyle, value: underlineValue, range: range)
            }

            applyAttributedText(mutableText, in: textView, selectedRange: selectedRange)
        }

        @objc private func showWritingTools() {
            guard let textView else { return }

            if #available(iOS 18.2, *), UIWritingToolsCoordinator.isWritingToolsAvailable {
                textView.showWritingTools(self)
            }
        }

        private func makeAccessoryToolbar() -> UIToolbar {
            let toolbar = UIToolbar()
            toolbar.tintColor = .label

            let boldItem = UIBarButtonItem(
                image: UIImage(systemName: "bold"),
                style: .plain,
                target: self,
                action: #selector(toggleBold)
            )
            let italicItem = UIBarButtonItem(
                image: UIImage(systemName: "italic"),
                style: .plain,
                target: self,
                action: #selector(toggleItalic)
            )
            let underlineItem = UIBarButtonItem(
                image: UIImage(systemName: "underline"),
                style: .plain,
                target: self,
                action: #selector(toggleUnderline)
            )

            let bulletsMenu = UIMenu(
                title: "List Style",
                children: [
                    UIAction(title: "Bulleted List", image: UIImage(systemName: "list.bullet")) { [weak self] _ in
                        self?.applyListStyle(.bulleted)
                    },
                    UIAction(title: "Dashed List", image: UIImage(systemName: "minus")) { [weak self] _ in
                        self?.applyListStyle(.dashed)
                    },
                    UIAction(title: "Numbered List", image: UIImage(systemName: "list.number")) { [weak self] _ in
                        self?.applyListStyle(.numbered)
                    }
                ]
            )

            let bulletsItem = UIBarButtonItem(
                title: nil,
                image: UIImage(systemName: "list.bullet"),
                primaryAction: nil,
                menu: bulletsMenu
            )

            var toolbarItems: [UIBarButtonItem] = [
                boldItem,
                italicItem,
                underlineItem,
                UIBarButtonItem(
                    barButtonSystemItem: .flexibleSpace,
                    target: nil,
                    action: nil
                ),
                bulletsItem
            ]

            if let writingToolsItem = makeWritingToolsItem() {
                toolbarItems.append(
                    UIBarButtonItem(
                        barButtonSystemItem: .flexibleSpace,
                        target: nil,
                        action: nil
                    )
                )
                toolbarItems.append(writingToolsItem)
            }

            toolbar.items = toolbarItems
            toolbar.sizeToFit()
            return toolbar
        }

        private func makeWritingToolsItem() -> UIBarButtonItem? {
            guard #available(iOS 18.2, *), UIWritingToolsCoordinator.isWritingToolsAvailable else {
                return nil
            }

            if let writingToolsImage = UIImage(systemName: "apple.intelligence") {
                return UIBarButtonItem(
                    image: writingToolsImage,
                    style: .plain,
                    target: self,
                    action: #selector(showWritingTools)
                )
            }

            return UIBarButtonItem(
                title: "Tools",
                style: .plain,
                target: self,
                action: #selector(showWritingTools)
            )
        }

        private func toggleFontTrait(_ trait: UIFontDescriptor.SymbolicTraits) {
            guard let textView else { return }

            let selectedRange = textView.selectedRange
            if selectedRange.length == 0 {
                var typingAttributes = mergedTypingAttributes(textView.typingAttributes)
                let currentFont = (typingAttributes[.font] as? UIFont) ?? PrepMetNoteEditorStyle.bodyFont
                let shouldEnable = !currentFont.fontDescriptor.symbolicTraits.contains(trait)
                typingAttributes[.font] = fontByTogglingTrait(
                    currentFont,
                    trait: trait,
                    shouldEnable: shouldEnable
                )
                textView.typingAttributes = typingAttributes
                return
            }

            let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
            let shouldEnableTrait = !selectionHasFontTrait(in: mutableText, range: selectedRange, trait: trait)

            mutableText.enumerateAttribute(.font, in: selectedRange, options: []) { value, range, _ in
                let currentFont = (value as? UIFont) ?? PrepMetNoteEditorStyle.bodyFont
                let updatedFont = fontByTogglingTrait(
                    currentFont,
                    trait: trait,
                    shouldEnable: shouldEnableTrait
                )
                mutableText.addAttribute(.font, value: updatedFont, range: range)
            }

            applyAttributedText(mutableText, in: textView, selectedRange: selectedRange)
        }

        private func applyListStyle(_ listStyle: NoteListStyle) {
            guard let textView else { return }

            let selectedRange = textView.selectedRange
            let fullText = textView.attributedText.string as NSString
            let paragraphRange = fullText.paragraphRange(for: selectedRange)
            let originalParagraphText = fullText.substring(with: paragraphRange)
            let updatedParagraphText = listStyle.formattedText(from: originalParagraphText)

            let replacementAttributes = PrepMetNoteEditorStyle.baseAttributes(
                font: currentEditingFont(in: textView)
            )
            let replacementText = NSAttributedString(
                string: updatedParagraphText,
                attributes: replacementAttributes
            )

            let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
            mutableText.replaceCharacters(in: paragraphRange, with: replacementText)

            let updatedSelection: NSRange
            if selectedRange.length == 0 {
                updatedSelection = NSRange(
                    location: min(mutableText.length, paragraphRange.location + replacementText.length),
                    length: 0
                )
            } else {
                updatedSelection = NSRange(location: paragraphRange.location, length: replacementText.length)
            }

            applyAttributedText(mutableText, in: textView, selectedRange: updatedSelection)
        }

        private func applyAttributedText(
            _ attributedText: NSAttributedString,
            in textView: UITextView,
            selectedRange: NSRange
        ) {
            isApplyingViewUpdate = true
            textView.attributedText = attributedText
            textView.selectedRange = clampedSelection(selectedRange, textLength: attributedText.length)
            updateTypingAttributes(in: textView)
            isApplyingViewUpdate = false
            persistTextState(from: textView)
        }

        private func persistTextState(from textView: UITextView) {
            guard !isApplyingViewUpdate else {
                return
            }

            let updatedPlainText = textView.attributedText.string
            let updatedArchivedText = textView.attributedText.length > 0
                ? PrepMetNoteEditorStyle.archive(textView.attributedText)
                : nil

            lastSyncedRichText = updatedArchivedText

            if plainText.wrappedValue != updatedPlainText {
                plainText.wrappedValue = updatedPlainText
            }

            if archivedRichText.wrappedValue != updatedArchivedText {
                archivedRichText.wrappedValue = updatedArchivedText
            }
        }

        private func updateTypingAttributes(in textView: UITextView) {
            let textLength = textView.attributedText.length
            guard textLength > 0 else {
                textView.typingAttributes = PrepMetNoteEditorStyle.typingAttributes()
                return
            }

            let selectionLocation = min(textView.selectedRange.location, textLength)
            let attributeIndex = max(0, min(textLength - 1, selectionLocation == textLength ? selectionLocation - 1 : selectionLocation))
            let inheritedAttributes = textView.attributedText.attributes(at: attributeIndex, effectiveRange: nil)
            textView.typingAttributes = mergedTypingAttributes(inheritedAttributes)
        }

        private func mergedTypingAttributes(_ attributes: [NSAttributedString.Key: Any]) -> [NSAttributedString.Key: Any] {
            var mergedAttributes = PrepMetNoteEditorStyle.typingAttributes()
            for (key, value) in attributes {
                mergedAttributes[key] = value
            }
            return mergedAttributes
        }

        private func currentEditingFont(in textView: UITextView) -> UIFont {
            let textLength = textView.attributedText.length
            if textLength > 0 {
                let selectionLocation = min(textView.selectedRange.location, textLength)
                let attributeIndex = max(0, min(textLength - 1, selectionLocation == textLength ? selectionLocation - 1 : selectionLocation))
                if let currentFont = textView.attributedText.attribute(.font, at: attributeIndex, effectiveRange: nil) as? UIFont {
                    return currentFont
                }
            }

            return (textView.typingAttributes[.font] as? UIFont) ?? PrepMetNoteEditorStyle.bodyFont
        }

        private func selectionHasFontTrait(
            in attributedText: NSAttributedString,
            range: NSRange,
            trait: UIFontDescriptor.SymbolicTraits
        ) -> Bool {
            var selectionHasTrait = true

            attributedText.enumerateAttribute(.font, in: range, options: []) { value, _, stop in
                let font = (value as? UIFont) ?? PrepMetNoteEditorStyle.bodyFont
                if !font.fontDescriptor.symbolicTraits.contains(trait) {
                    selectionHasTrait = false
                    stop.pointee = true
                }
            }

            return selectionHasTrait
        }

        private func selectionHasUnderline(
            in attributedText: NSAttributedString,
            range: NSRange
        ) -> Bool {
            var selectionHasUnderline = true

            attributedText.enumerateAttribute(.underlineStyle, in: range, options: []) { value, _, stop in
                let underlineValue = (value as? Int) ?? 0
                if underlineValue == 0 {
                    selectionHasUnderline = false
                    stop.pointee = true
                }
            }

            return selectionHasUnderline
        }

        private func fontByTogglingTrait(
            _ font: UIFont,
            trait: UIFontDescriptor.SymbolicTraits,
            shouldEnable: Bool
        ) -> UIFont {
            let currentTraits = font.fontDescriptor.symbolicTraits
            let updatedTraits: UIFontDescriptor.SymbolicTraits

            if shouldEnable {
                updatedTraits = currentTraits.union(trait)
            } else {
                updatedTraits = UIFontDescriptor.SymbolicTraits(rawValue: currentTraits.rawValue & ~trait.rawValue)
            }

            guard let updatedDescriptor = font.fontDescriptor.withSymbolicTraits(updatedTraits) else {
                return font
            }

            return UIFont(descriptor: updatedDescriptor, size: font.pointSize)
        }

        private func clampedSelection(_ selection: NSRange, textLength: Int) -> NSRange {
            let location = min(max(0, selection.location), textLength)
            let length = min(max(0, selection.length), textLength - location)
            return NSRange(location: location, length: length)
        }
    }
}

private enum NoteListStyle {
    case bulleted
    case dashed
    case numbered

    func formattedText(from text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var nextNumber = 1

        return lines.map { line in
            let cleanedLine = Self.removingExistingListPrefix(from: line)
            let prefix = prefix(for: nextNumber)

            if self == .numbered {
                nextNumber += 1
            }

            if cleanedLine.isEmpty {
                return prefix
            }

            return prefix + cleanedLine
        }
        .joined(separator: "\n")
    }

    private func prefix(for index: Int) -> String {
        switch self {
        case .bulleted:
            return "• "
        case .dashed:
            return "- "
        case .numbered:
            return "\(index). "
        }
    }

    private static func removingExistingListPrefix(from line: String) -> String {
        line.replacingOccurrences(
            of: #"^\s*(?:•|-|\d+\.)\s*"#,
            with: "",
            options: .regularExpression
        )
    }
}

private enum PrepMetNoteEditorStyle {
    static var bodyFont: UIFont {
        UIFont.preferredFont(forTextStyle: .body)
    }

    static func baseAttributes(font: UIFont? = nil) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 8

        return [
            .font: font ?? bodyFont,
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ]
    }

    static func typingAttributes(font: UIFont? = nil) -> [NSAttributedString.Key: Any] {
        baseAttributes(font: font)
    }

    static func attributedText(for plainText: String, archivedRichText: Data?) -> NSAttributedString {
        if
            let archivedRichText,
            let decodedText = decodeAttributedText(from: archivedRichText),
            decodedText.string == plainText
        {
            return decodedText
        }

        return NSAttributedString(
            string: plainText,
            attributes: baseAttributes()
        )
    }

    static func archive(_ attributedText: NSAttributedString) -> Data? {
        try? NSKeyedArchiver.archivedData(
            withRootObject: attributedText,
            requiringSecureCoding: true
        )
    }

    static func decodeAttributedText(from data: Data) -> NSAttributedString? {
        let allowedClasses: [AnyClass] = [
            NSAttributedString.self,
            NSMutableAttributedString.self,
            UIFont.self,
            UIColor.self,
            NSDictionary.self,
            NSArray.self,
            NSString.self,
            NSNumber.self,
            NSURL.self,
            NSParagraphStyle.self,
            NSMutableParagraphStyle.self,
            NSTextAttachment.self,
            NSTextList.self,
            NSTextTab.self,
            NSShadow.self
        ]

        return try? NSKeyedUnarchiver.unarchivedObject(
            ofClasses: allowedClasses,
            from: data
        ) as? NSAttributedString
    }
}

private func prepMetStorageKey(eventID: String, categoryName: String) -> String {
    "PrepMet.\(eventID).\(categoryName)"
}

private func prepMetRichTextStorageKey(eventID: String, categoryName: String) -> String {
    "PrepMet.\(eventID).\(categoryName).richText"
}

#Preview {
    NavigationStack {
        EventDetailView(
            event: CalendarEvent(
                id: "preview",
                title: "Team Sync",
                startDate: Date(),
                endDate: Date().addingTimeInterval(3600)
            )
        )
    }
}
