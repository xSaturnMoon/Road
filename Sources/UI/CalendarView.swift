import SwiftUI

struct CalendarView: View {
    @StateObject var manager = CalendarManager.shared
    @State private var showingAddEvent = false
    @State private var showingAllReminders = false
    @State private var selectedEvent: BloomEvent?
    @State private var currentMonth = Date()
    @State private var selectedAddDate = Date()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
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
                    .background(Color(uiColor: .systemBackground))
                    
                    // Agenda List with Card Aesthetic
                    List {
                        let days = daysInMonth(for: currentMonth)
                        ForEach(days, id: \.self) { date in
                            DayCardRow(date: date, selectedEvent: $selectedEvent, showingAddEvent: $showingAddEvent, selectedAddDate: $selectedAddDate)
                        }
                    }
                    .listStyle(.plain)
                    .background(Color.clear)
                    .id(currentMonth)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
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
                    Button {
                        withAnimation { currentMonth = Date() }
                    } label: {
                        Text("Oggi").bold()
                    }
                }
            }
            .sheet(isPresented: $showingAddEvent) {
                AddEventView(isPresented: $showingAddEvent, initialDate: selectedAddDate)
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

struct DayCardRow: View {
    let date: Date
    @Binding var selectedEvent: BloomEvent?
    @Binding var showingAddEvent: Bool
    @Binding var selectedAddDate: Date
    @StateObject var manager = CalendarManager.shared
    
    var body: some View {
        let events = manager.events(for: date)
        let isToday = Calendar.current.isDateInToday(date)
        
        VStack(alignment: .leading, spacing: 0) {
            // Day Header inside the card
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(date.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "it_IT"))).capitalized)
                        .font(.caption.bold())
                        .foregroundColor(isToday ? .blue : .secondary)
                    
                    Text(date.formatted(.dateTime.day().locale(Locale(identifier: "it_IT"))))
                        .font(.title3.bold())
                }
                Spacer()
            }
            .padding(.bottom, 12)
            
            if events.isEmpty {
                Text("Nessun impegno")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                VStack(spacing: 8) {
                    ForEach(events) { event in
                        SwipeableEventRow(event: event) {
                            selectedEvent = event
                        }
                    }
                }
            }
            
            HStack {
                Spacer()
                Button {
                    selectedAddDate = date
                    showingAddEvent = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .padding(.top, 10)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isToday ? Color.blue : Color.clear, lineWidth: isToday ? 1.5 : 0)
        )
        .padding(.horizontal)
        .padding(.vertical, 8)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

struct EventRowView: View {
    let event: BloomEvent
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
                
                if !event.reminders.isEmpty || event.reminderId != nil {
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
            .padding(12)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct SwipeableEventRow: View {
    let event: BloomEvent
    let onTap: () -> Void
    @StateObject var manager = CalendarManager.shared
    @State private var offset: CGFloat = 0
    
    var body: some View {
        ZStack(alignment: .trailing) {
            Button {
                withAnimation { manager.deleteEvent(event) }
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.white)
                    .frame(width: 60)
                    .frame(maxHeight: .infinity)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            
            EventRowView(event: event, onTap: onTap)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            if gesture.translation.width < 0 {
                                offset = gesture.translation.width
                            }
                        }
                        .onEnded { gesture in
                            withAnimation {
                                if offset < -50 {
                                    if gesture.translation.width < -100 {
                                        manager.deleteEvent(event)
                                    } else {
                                        offset = -70
                                    }
                                } else {
                                    offset = 0
                                }
                            }
                        }
                )
        }
    }
}

struct EditEventView: View {
    @Environment(\.dismiss) var dismiss
    @State var event: BloomEvent
    @State private var title: String
    @State private var date: Date
    @State private var startTime: Date
    @State private var newReminderTime: Date
    @State private var isAddingReminder: Bool = false
    @State private var reminders: [EventReminder]
    
    init(event: BloomEvent) {
        self._event = State(initialValue: event)
        self._title = State(initialValue: event.title)
        self._date = State(initialValue: event.date)
        self._startTime = State(initialValue: event.startTime)
        self._newReminderTime = State(initialValue: event.startTime)
        
        var existingReminders = event.reminders
        if existingReminders.isEmpty, let rt = event.reminderTime, let rid = event.reminderId {
            existingReminders.append(EventReminder(time: rt, notificationId: rid))
        }
        self._reminders = State(initialValue: existingReminders)
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
                    Toggle("Aggiungi Promemoria", isOn: $isAddingReminder)
                    
                    if isAddingReminder {
                        DatePicker("Orario", selection: $newReminderTime, displayedComponents: .hourAndMinute)
                        Button("Salva Promemoria") {
                            let newReminder = EventReminder(time: newReminderTime, notificationId: "")
                            reminders.append(newReminder)
                            isAddingReminder = false
                        }
                    }
                }
                
                if !reminders.isEmpty {
                    Section("Promemoria Programmati") {
                        ForEach(reminders) { reminder in
                            HStack {
                                Text(reminder.time.formatted(.dateTime.hour().minute()))
                                Spacer()
                                Button(role: .destructive) {
                                    reminders.removeAll(where: { $0.id == reminder.id })
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        CalendarManager.shared.deleteEvent(event)
                        dismiss()
                    } label: {
                        Text("Elimina Impegno").frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Modifica Impegno")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Salva") {
                        event.title = title
                        event.date = date
                        event.startTime = startTime
                        event.reminders = reminders
                        CalendarManager.shared.updateEvent(event)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

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
    @State private var startTime: Date
    
    init(isPresented: Binding<Bool>, initialDate: Date) {
        self._isPresented = isPresented
        self.initialDate = initialDate
        
        let now = Date()
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: initialDate)
        let nowComps = cal.dateComponents([.hour, .minute], from: now)
        comps.hour = nowComps.hour
        comps.minute = nowComps.minute
        
        self._startTime = State(initialValue: cal.date(from: comps) ?? initialDate)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Cosa") {
                    TextField("Esempio: Visita medica", text: $title)
                }
                Section("Quando (\(initialDate.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "it_IT")))))") {
                    DatePicker("Orario", selection: $startTime, displayedComponents: .hourAndMinute)
                }
            }
            .navigationTitle("Aggiungi Impegno")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Annulla") { isPresented = false } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Salva") {
                        CalendarManager.shared.addEvent(title: title, date: initialDate, startTime: startTime, endTime: nil, hasEndTime: false, reminderEnabled: false)
                        isPresented = false
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}
