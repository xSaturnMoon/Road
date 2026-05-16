import Foundation
import Combine

struct BloomEvent: Identifiable, Codable {
    var id = UUID()
    var title: String
    var date: Date
    var startTime: Date
    var endTime: Date?
    var category: String = "Generale" // Generale, Lavoro, Personale, Importante
    var notes: String = ""
    var isCompleted: Bool = false
}

class CalendarManager: ObservableObject {
    static let shared = CalendarManager()
    
    @Published var events: [BloomEvent] = []
    
    private let eventsKey = "bloom_calendar_events"
    
    init() {
        loadEvents()
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
        // In a real app, here we would also sync to cloud via AuthManager
    }
    
    func addEvent(title: String, date: Date, startTime: Date, endTime: Date?, category: String, notes: String) {
        let newEvent = BloomEvent(title: title, date: date, startTime: startTime, endTime: endTime, category: category, notes: notes)
        events.append(newEvent)
        saveEvents()
    }
    
    func deleteEvent(_ event: BloomEvent) {
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
}
