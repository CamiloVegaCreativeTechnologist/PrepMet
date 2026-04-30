import Combine
import EventKit
import SwiftUI

struct CalendarEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
}

@MainActor
final class CalendarPermissionManager: ObservableObject {
    enum PermissionState: Equatable {
        case notDetermined
        case granted
        case denied
        case error(String)
    }

    @Published private(set) var permissionState: PermissionState = .notDetermined
    @Published private(set) var events: [CalendarEvent] = []

    private let eventStore = EKEventStore()
    var calendarStore: EKEventStore { eventStore }

    init() {
        refreshPermissionState()
    }

    func refreshPermissionState() {
        if #available(iOS 17.0, *) {
            switch EKEventStore.authorizationStatus(for: .event) {
            case .notDetermined:
                permissionState = .notDetermined
                events = []
            case .fullAccess, .authorized:
                permissionState = .granted
                fetchEvents(for: Date())
            case .denied, .restricted, .writeOnly:
                permissionState = .denied
                events = []
            @unknown default:
                permissionState = .error("Unknown calendar permission state.")
                events = []
            }
        } else {
            switch EKEventStore.authorizationStatus(for: .event) {
            case .notDetermined:
                permissionState = .notDetermined
                events = []
            case .fullAccess, .authorized:
                permissionState = .granted
                fetchEvents(for: Date())
            case .writeOnly, .denied, .restricted:
                permissionState = .denied
                events = []
            @unknown default:
                permissionState = .error("Unknown calendar permission state.")
                events = []
            }
        }
    }

    func requestCalendarPermission() {
        Task {
            do {
                let granted: Bool

                if #available(iOS 17.0, *) {
                    granted = try await eventStore.requestFullAccessToEvents()
                } else {
                    granted = try await withCheckedThrowingContinuation { continuation in
                        eventStore.requestAccess(to: .event) { granted, error in
                            if let error {
                                continuation.resume(throwing: error)
                            } else {
                                continuation.resume(returning: granted)
                            }
                        }
                    }
                }

                permissionState = granted ? .granted : .denied
                if granted {
                    fetchEvents(for: Date())
                } else {
                    events = []
                }
            } catch {
                events = []
                permissionState = .error(error.localizedDescription)
            }
        }
    }

    func fetchTodayEvents() {
        fetchEvents(for: Date())
    }

    func fetchEvents(for date: Date) {
        guard case .granted = permissionState else {
            events = []
            return
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            events = []
            return
        }

        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        events = eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .compactMap { event in
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
    }

    func eventDates(inMonthContaining date: Date) -> Set<Date> {
        guard case .granted = permissionState else {
            return []
        }

        let calendar = Calendar.current
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
}
