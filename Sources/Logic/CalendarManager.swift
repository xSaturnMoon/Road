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
    
    init() {
        loadEvents()
        requestNotificationPermission()
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
    
    func loadEvents() {
        if let data = UserDefaults.standard.data(forKey: eventsKey),
           let decoded = try? JSONDecoder().decode([BloomEvent].self, from: data) {
            self.events = decoded
        }
    }
    
    func saveEvents() {
        if let encoded = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(encoded, forKey: eventsKey)
        }
    }
    
    func addEvent(title: String, date: Date, startTime: Date, endTime: Date?, hasEndTime: Bool, reminderEnabled: Bool) {
        var newEvent = BloomEvent(title: title, date: date, startTime: startTime, endTime: hasEndTime ? endTime : nil, hasEndTime: hasEndTime)
        
        if reminderEnabled {
            scheduleNotification(for: &newEvent)
        }
        
        events.append(newEvent)
        saveEvents()
    }
    
    func scheduleNotification(for event: inout BloomEvent) {
        let content = UNMutableNotificationContent()
        content.title = "Promemoria Bloom"
        content.body = "Evento: \(event.title) alle \(event.startTime.formatted(.dateTime.hour().minute()))"
        content.sound = .default
        
        // Combine date and time
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: event.date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: event.startTime)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let id = UUID().uuidString
        event.reminderId = id
        
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    func deleteEvent(_ event: BloomEvent) {
        if let rid = event.reminderId {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [rid])
        }
        events.removeAll(where: { $0.id == event.id })
        saveEvents()
    }
    
    func toggleComplete(_ event: BloomEvent) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index].isCompleted.toggle()
            saveEvents()
        }
    }
    
    func events(for date: Date) -> [BloomEvent] {
        events.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            .sorted(by: { $0.startTime < $1.startTime })
    }
    
    func hasEvents(on date: Date) -> Bool {
        events.contains { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
}
