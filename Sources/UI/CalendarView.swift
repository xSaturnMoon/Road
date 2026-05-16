import SwiftUI

struct CalendarView: View {
    @StateObject var manager = CalendarManager.shared
    @State private var showingAddEvent = false
    @State private var showingAllReminders = false
    @State private var selectedEvent: CalendarEvent?
    @State private var currentMonth = Date()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Month Selector Header
                HStack {
                    Button { changeMonth(by: -1) } label: {
                        Image(systemName: "chevron.left.circle.fill").font(.title2).foregroundColor(.secondary.opacity(0.5))
                    }
                    Spacer()
                    Text(currentMonth.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "it_IT"))).capitalized)
                        .font(.title2.bold())
                    Spacer()
                    Button { changeMonth(by: 1) } label: {
                        Image(systemName: "chevron.right.circle.fill").font(.title2).foregroundColor(.secondary.opacity(0.5))
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                
                // Agenda List
                List {
                    let days = daysInMonth(for: currentMonth)
                    ForEach(days, id: \.self) { date in
                        Section {
                            let events = manager.events(for: date)
                            if events.isEmpty {
                                Text("Nessun impegno")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .italic()
                                    .listRowBackground(Color.clear)
                            } else {
                                ForEach(events) { event in
                                    EventRowView(event: event) {
                                        selectedEvent = event
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            withAnimation { manager.deleteEvent(event) }
                                        } label: { Label("Elimina", systemImage: "trash") }
                                    }
                                }
                            }
                        } header: {
                            HStack {
                                Text(date.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "it_IT"))).capitalized)
                                Text(date.formatted(.dateTime.day().locale(Locale(identifier: "it_IT"))))
                                if Calendar.current.isDateInToday(date) {
                                    Text("OGGI").font(.caption2.bold()).padding(.horizontal, 6).padding(.vertical, 2).background(.blue).foregroundColor(.white).clipShape(Capsule())
                                }
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Calendario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showingAllReminders = true } label: {
                        Image(systemName: "bell.fill").foregroundColor(.orange)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingAddEvent = true } label: {
                        Image(systemName: "plus").font(.headline)
                    }
                }
            }
            .sheet(isPresented: $showingAddEvent) {
                AddEventView(isPresented: $showingAddEvent, initialDate: currentMonth)
            }
            .sheet(item: $selectedEvent) { event in
                EditEventView(event: event)
            }
            .sheet(isPresented: $showingAllReminders) {
                AllRemindersView(isPresented: $showingAllReminders)
            }
        }
    }
    
    func changeMonth(by value: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: currentMonth) {
            withAnimation { currentMonth = newMonth }
        }
    }
    
    func daysInMonth(for date: Date) -> [Date] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: date),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else { return [] }
        return range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth)
        }
    }
}

struct EventRowView: View {
    let event: CalendarEvent
    let onTap: () -> Void
    @StateObject var manager = CalendarManager.shared
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .strikethrough(event.isCompleted)
                    
                    Text(event.startTime.formatted(.dateTime.hour().minute()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                
                if event.reminderId != nil {
                    Image(systemName: "bell.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                Button {
                    withAnimation { manager.toggleComplete(event) }
                } label: {
                    Image(systemName: event.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(event.isCompleted ? .green : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .buttonStyle(.plain)
    }
}

struct EditEventView: View {
    @Environment(\.dismiss) var dismiss
    @State var event: CalendarEvent
    @State private var title: String
    @State private var date: Date
    @State private var startTime: Date
    @State private var reminderEnabled: Bool
    
    init(event: CalendarEvent) {
        self._event = State(initialValue: event)
        self._title = State(initialValue: event.title)
        self._date = State(initialValue: event.date)
        self._startTime = State(initialValue: event.startTime)
        self._reminderEnabled = State(initialValue: event.reminderId != nil)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Cosa") {
                    TextField("Titolo", text: $title)
                }
                Section("Quando") {
                    DatePicker("Giorno", selection: $date, displayedComponents: .date)
                    DatePicker("Orario", selection: $startTime, displayedComponents: .hourAndMinute)
                }
                Section("Notifiche") {
                    Toggle("Avvisami con un suono", isOn: $reminderEnabled)
                }
                Section {
                    Button(role: .destructive) {
                        CalendarManager.shared.deleteEvent(event)
                        dismiss()
                    } label: {
                        Text("Elimina Impegno")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Modifica Impegno")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Salva") {
                        CalendarManager.shared.deleteEvent(event) // Delete old and add new as a simple "edit"
                        CalendarManager.shared.addEvent(title: title, date: date, startTime: startTime, endTime: nil, hasEndTime: false, reminderEnabled: reminderEnabled)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

// Keeping AddEventView and AllRemindersView from previous turn but ensuring consistency
struct AllRemindersView: View {
    @Binding var isPresented: Bool
    @StateObject var manager = CalendarManager.shared
    
    var body: some View {
        NavigationStack {
            List {
                let futureReminders = manager.events.filter { $0.reminderId != nil && $0.date >= Calendar.current.startOfDay(for: Date()) }
                    .sorted(by: { $0.date < $1.date })
                
                if futureReminders.isEmpty {
                    ContentUnavailableView("Nessun Promemoria", systemImage: "bell.slash", description: Text("Tutti i tuoi promemoria appariranno qui."))
                } else {
                    ForEach(futureReminders) { event in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(event.title).font(.headline)
                                Text("\(event.date.formatted(.dateTime.day().month().locale(Locale(identifier: "it_IT")))) alle \(event.startTime.formatted(.dateTime.hour().minute()))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "bell.fill").foregroundColor(.orange)
                        }
                    }
                }
            }
            .navigationTitle("Promemoria Attivi")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") { isPresented = false }
                }
            }
        }
    }
}

struct AddEventView: View {
    @Binding var isPresented: Bool
    let initialDate: Date
    @State private var title = ""
    @State private var date: Date
    @State private var startTime = Date()
    @State private var reminderEnabled = true
    
    init(isPresented: Binding<Bool>, initialDate: Date) {
        self._isPresented = isPresented
        self.initialDate = initialDate
        self._date = State(initialValue: initialDate)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Cosa") {
                    TextField("Esempio: Visita medica", text: $title)
                }
                Section("Quando") {
                    DatePicker("Giorno", selection: $date, displayedComponents: .date)
                    DatePicker("Orario", selection: $startTime, displayedComponents: .hourAndMinute)
                }
                Section("Notifiche") {
                    Toggle("Avvisami con un suono", isOn: $reminderEnabled)
                }
            }
            .navigationTitle("Aggiungi Impegno")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Annulla") { isPresented = false } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Salva") {
                        CalendarManager.shared.addEvent(title: title, date: date, startTime: startTime, endTime: nil, hasEndTime: false, reminderEnabled: reminderEnabled)
                        isPresented = false
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}
