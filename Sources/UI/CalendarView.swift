import SwiftUI

struct CalendarView: View {
    @StateObject var manager = CalendarManager.shared
    @State private var selectedDate = Date()
    @State private var showingAddEvent = false
    @State private var currentMonth = Date()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Monthly Calendar with Indicators
                    VStack(spacing: 15) {
                        HStack {
                            Text(currentMonth.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "it_IT"))).capitalized)
                                .font(.headline.bold())
                            Spacer()
                            HStack(spacing: 20) {
                                Button { changeMonth(by: -1) } label: { Image(systemName: "chevron.left") }
                                Button { changeMonth(by: 1) } label: { Image(systemName: "chevron.right") }
                            }
                        }
                        .padding(.horizontal)
                        
                        CalendarGridView(selectedDate: $selectedDate, currentMonth: currentMonth)
                    }
                    .padding(.vertical)
                    .background(.ultraThinMaterial)
                    
                    // Events for selected day
                    List {
                        let dayEvents = manager.events(for: selectedDate)
                        
                        if dayEvents.isEmpty {
                            Section {
                                ContentUnavailableView("Nessun impegno", systemImage: "calendar.badge.plus", description: Text("Goditi il tempo libero!"))
                            }
                            .listRowBackground(Color.clear)
                        } else {
                            Section("Programma del giorno") {
                                ForEach(dayEvents) { event in
                                    SimpleEventRow(event: event)
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                withAnimation { manager.deleteEvent(event) }
                                            } label: { Label("Elimina", systemImage: "trash") }
                                        }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Calendario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingAddEvent = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAddEvent) {
                AddEventView(isPresented: $showingAddEvent, initialDate: selectedDate)
            }
        }
    }
    
    func changeMonth(by value: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: currentMonth) {
            withAnimation { currentMonth = newMonth }
        }
    }
}

struct CalendarGridView: View {
    @Binding var selectedDate: Date
    let currentMonth: Date
    let calendar = Calendar.current
    @StateObject var manager = CalendarManager.shared
    
    var body: some View {
        let days = generateDays()
        let columns = Array(repeating: GridItem(.flexible()), count: 7)
        
        VStack(spacing: 10) {
            HStack {
                ForEach(["L", "M", "M", "G", "V", "S", "D"], id: \.self) { day in
                    Text(day).font(.caption2.bold()).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
            }
            
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(days, id: \.self) { date in
                    if let date = date {
                        VStack(spacing: 4) {
                            Text("\(calendar.component(.day, from: date))")
                                .font(.system(size: 16, weight: isSameDay(date, selectedDate) ? .bold : .regular))
                                .foregroundColor(isSameDay(date, selectedDate) ? .white : .primary)
                                .frame(width: 32, height: 32)
                                .background(isSameDay(date, selectedDate) ? Color.blue : Color.clear)
                                .clipShape(Circle())
                            
                            if manager.hasEvents(on: date) {
                                Circle()
                                    .fill(isSameDay(date, selectedDate) ? .white : .blue)
                                    .frame(width: 4, height: 4)
                            } else {
                                Spacer().frame(height: 4)
                            }
                        }
                        .onTapGesture {
                            withAnimation { selectedDate = date }
                        }
                    } else {
                        Spacer().frame(height: 40)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    func generateDays() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else { return [] }
        let firstDayOfMonth = monthInterval.start
        let weekday = calendar.component(.weekday, from: firstDayOfMonth)
        let offset = (weekday + 5) % 7 // Align to Monday
        
        var days: [Date?] = Array(repeating: nil, count: offset)
        let numberOfDays = calendar.range(of: .day, in: .month, for: currentMonth)!.count
        for i in 0..<numberOfDays {
            days.append(calendar.date(byAdding: .day, value: i, to: firstDayOfMonth))
        }
        return days
    }
    
    func isSameDay(_ d1: Date, _ d2: Date) -> Bool {
        calendar.isDate(d1, inSameDayAs: d2)
    }
}

struct SimpleEventRow: View {
    let event: BloomEvent
    @ObservedObject var manager = CalendarManager.shared
    
    var body: some View {
        HStack(spacing: 15) {
            VStack(alignment: .trailing) {
                Text(event.startTime, format: .dateTime.hour().minute())
                    .font(.headline)
                if event.hasEndTime, let end = event.endTime {
                    Text(end, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 50)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.headline)
                    .strikethrough(event.isCompleted)
                
                if event.reminderId != nil {
                    Label("Notifica attiva", systemImage: "bell.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            Button {
                withAnimation { manager.toggleComplete(event) }
            } label: {
                Image(systemName: event.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(event.isCompleted ? .green : .secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 15))
    }
}

struct AddEventView: View {
    @Binding var isPresented: Bool
    let initialDate: Date
    @State private var title = ""
    @State private var date: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var hasEndTime = false
    @State private var reminderEnabled = true
    
    init(isPresented: Binding<Bool>, initialDate: Date) {
        self._isPresented = isPresented
        self.initialDate = initialDate
        self._date = State(initialValue: initialDate)
        self._startTime = State(initialValue: Date())
        self._endTime = State(initialValue: Date().addingTimeInterval(3600))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Evento") {
                    TextField("Cosa devi fare?", text: $title)
                    DatePicker("Giorno", selection: $date, displayedComponents: .date)
                }
                
                Section("Orario") {
                    DatePicker("Inizio", selection: $startTime, displayedComponents: .hourAndMinute)
                    Toggle("Imposta Fine", isOn: $hasEndTime)
                    if hasEndTime {
                        DatePicker("Fine", selection: $endTime, displayedComponents: .hourAndMinute)
                    }
                }
                
                Section("Notifiche") {
                    Toggle("Invia Promemoria", isOn: $reminderEnabled)
                }
            }
            .navigationTitle("Nuovo Impegno")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Annulla") { isPresented = false } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Salva") {
                        CalendarManager.shared.addEvent(title: title, date: date, startTime: startTime, endTime: endTime, hasEndTime: hasEndTime, reminderEnabled: reminderEnabled)
                        isPresented = false
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}
