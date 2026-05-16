import SwiftUI

struct CalendarView: View {
    @StateObject var manager = CalendarManager.shared
    @State private var showingAddEvent = false
    @State private var showingAllReminders = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        // Header with Month
                        HStack {
                            Text(Date().formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "it_IT"))).capitalized)
                                .font(.title.bold())
                            Spacer()
                            
                            Button {
                                showingAllReminders = true
                            } label: {
                                Image(systemName: "bell.fill")
                                    .font(.title3)
                                    .foregroundColor(.orange)
                                    .padding(10)
                                    .background(.orange.opacity(0.1))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // Continuous Day List (Like news+)
                        // We show the next 30 days for simplicity and clarity
                        VStack(spacing: 15) {
                            ForEach(0..<31) { dayOffset in
                                let day = Calendar.current.date(byAdding: .day, value: dayOffset, to: Date())!
                                DayCardView(date: day)
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            .navigationTitle("Calendario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddEvent = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingAddEvent) {
                AddEventView(isPresented: $showingAddEvent)
            }
            .sheet(isPresented: $showingAllReminders) {
                AllRemindersView(isPresented: $showingAllReminders)
            }
        }
    }
}

struct DayCardView: View {
    let date: Date
    @StateObject var manager = CalendarManager.shared
    
    var body: some View {
        let events = manager.events(for: date)
        let isToday = Calendar.current.isDateInToday(date)
        
        VStack(alignment: .leading, spacing: 12) {
            // Day Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(date.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "it_IT"))).capitalized)
                        .font(.caption.bold())
                        .foregroundColor(isToday ? .blue : .secondary)
                    
                    Text(date.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "it_IT"))))
                        .font(.title3.bold())
                }
                Spacer()
                if isToday {
                    Text("OGGI")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.blue)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
            
            // Events List inside the card
            if events.isEmpty {
                Text("Nessun impegno")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                VStack(spacing: 8) {
                    ForEach(events) { event in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.title)
                                    .font(.headline)
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
                                withAnimation {
                                    manager.toggleComplete(event)
                                }
                            } label: {
                                Image(systemName: event.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(event.isCompleted ? .green : .secondary)
                            }
                        }
                        .padding(10)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                withAnimation { manager.deleteEvent(event) }
                            } label: { Label("Elimina", systemImage: "trash") }
                        }
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isToday ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 2)
        )
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
                    Section {
                        Text("Nessun promemoria attivo")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(futureReminders) { event in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(event.title).font(.headline)
                                Text("\(event.date.formatted(.dateTime.day().month())) alle \(event.startTime.formatted(.dateTime.hour().minute()))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "bell.fill").foregroundColor(.orange)
                        }
                    }
                }
            }
            .navigationTitle("Tutti i Promemoria")
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
    @State private var title = ""
    @State private var date = Date()
    @State private var startTime = Date()
    @State private var reminderEnabled = true
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Cosa") {
                    TextField("Esempio: Visita medica", text: $title)
                        .font(.title3)
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
