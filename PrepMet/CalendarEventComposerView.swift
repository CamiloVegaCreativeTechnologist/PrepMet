import EventKit
import EventKitUI
import SwiftUI

struct CalendarEventComposerView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool

    let eventStore: EKEventStore
    let selectedDate: Date

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
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
        private let parent: CalendarEventComposerView

        init(parent: CalendarEventComposerView) {
            self.parent = parent
        }

        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            parent.isPresented = false
        }
    }
}
