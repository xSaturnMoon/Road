import Foundation
import Combine
import UserNotifications

struct BloomEvent: Identifiable, Codable {
    var id = UUID()
    var title: String
    var date: Date
    var startTime: Date
    var endTime: Date?
    var hasEndTime: Bool = false
    var isCompleted: Bool = false
    var reminderId: String?
}

class CalendarManager: ObservableObject {
    static let shared = CalendarManager()

    @Published var events: [BloomEvent] = []

    private let eventsKey = "bloom_calendar_events"
    private let sb = SupabaseManager.shared

    init() {
        loadLocalEvents()
        requestNotificationPermission()
    }

    // MARK: - Local Persistence

    func loadLocalEvents() {
        if let data = UserDefaults.standard.data(forKey: eventsKey),
           let decoded = try? JSONDecoder().decode([BloomEvent].self, from: data) {
            self.events = decoded
        }
    }

    private func saveLocalEvents() {
        if let encoded = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(encoded, forKey: eventsKey)
        }
    }

    /// Called after login to replace local data with cloud data
    func replaceWithCloudData(_ cloudEvents: [BloomEvent]) {
        events = cloudEvents
        saveLocalEvents()
    }

    // MARK: - CRUD (Local + Cloud)

    func addEvent(title: String, date: Date, startTime: Date, endTime: Date?, hasEndTime: Bool, reminderEnabled: Bool) {
        var newEvent = BloomEvent(
            title: title,
            date: date,
            startTime: startTime,
            endTime: hasEndTime ? endTime : nil,
            hasEndTime: hasEndTime
        )
        if reminderEnabled {
            scheduleNotification(for: &newEvent)
        }
        events.append(newEvent)
        saveLocalEvents()
        syncToCloud(newEvent)
    }

    func deleteEvent(_ event: BloomEvent) {
        if let rid = event.reminderId {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [rid])
        }
        events.removeAll(where: { $0.id == event.id })
        saveLocalEvents()
        Task { try? await sb.deleteEvent(id: event.id) }
    }

    func toggleComplete(_ event: BloomEvent) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index].isCompleted.toggle()
            saveLocalEvents()
            syncToCloud(events[index])
        }
    }

    // MARK: - Cloud Sync

    private func syncToCloud(_ event: BloomEvent) {
        guard sb.isAuthenticated else { return }
        Task { try? await sb.upsertEvent(event) }
    }

    // MARK: - Notifications

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private func scheduleNotification(for event: inout BloomEvent) {
        let content = UNMutableNotificationContent()
        content.title = "Promemoria Bloom"
        content.body = "\(event.title) alle \(event.startTime.formatted(.dateTime.hour().minute()))"
        content.sound = .default

        let cal = Calendar.current
        var components = cal.dateComponents([.year, .month, .day], from: event.date)
        let time = cal.dateComponents([.hour, .minute], from: event.startTime)
        components.hour = time.hour
        components.minute = time.minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let id = UUID().uuidString
        event.reminderId = id
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Query

    func events(for date: Date) -> [BloomEvent] {
        events.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.startTime < $1.startTime }
    }

    func hasEvents(on date: Date) -> Bool {
        events.contains { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
}
