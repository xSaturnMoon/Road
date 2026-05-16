import SwiftUI

struct CalendarView: View {
    @StateObject var manager = CalendarManager.shared
    @State private var showingAddEvent = false
    @State private var showingAllReminders = false
    
    // Generate dates grouped by month for the next 12 months
    var groupedDates: [(String, [Date])] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var results: [(String, [Date])] = []
        
        // Let's show the next 6 months for a better balance
        for monthOffset in 0..<6 {
            guard let firstOfMonth = calendar.date(byAdding: .month, value: monthOffset, to: today),
                  let monthRange = calendar.range(of: .day, in: .month, for: firstOfMonth) else { continue }
            
            let monthName = firstOfMonth.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "it_IT"))).capitalized
            var monthDates: [Date] = []
            
            let startDay = (monthOffset == 0) ? calendar.component(.day, from: today) : 1
            
            for day in startDay...monthRange.count {
                if let date = calendar.date(bySetting: .day, value: day, of: firstOfMonth) {
                    monthDates.append(date)
                }
            }
            
            if !monthDates.isEmpty {
                results.append((monthName, monthDates))
            }
        }
        
        return results
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground).ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 20, pinnedViews: [.sectionHeaders]) {
                        ForEach(groupedDates, id: \.0) { monthName, dates in
                            Section(header: MonthHeader(title: monthName)) {
                                ForEach(dates, id: \.self) { date in
                                    DayCardView(date: date)
                                        .padding(.horizontal)
                                }
                            }
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            .navigationTitle("Calendario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingAllReminders = true
                    } label: {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.orange)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddEvent = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline)
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

struct MonthHeader: View {
    let title: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.title2.bold())
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
            Spacer()
        }
        .background(.ultraThinMaterial)
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
                    
                    Text(date.formatted(.dateTime.day().locale(Locale(identifier: "it_IT"))))
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
            
            // Events List
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
                        .padding(12)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(isToday ? Color.blue.opacity(0.4) : Color.clear, lineWidth: 2)
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
    @State private var title = ""
    @State private var date = Date()
    @State private var startTime = Date()
    @State private var reminderEnabled = true
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Cosa") {
                    TextField("Esempio: Visita medica", text: $title)
                        .font(.body)
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
