import SwiftUI

struct CalendarView: View {
    @StateObject var manager = CalendarManager.shared
    @State private var selectedDate = Date()
    @State private var showingAddEvent = false
    @State private var weekOffset = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Modern Week Picker
                    VStack(spacing: 15) {
                        HStack {
                            Text(selectedDate.formatted(.dateTime.month(.wide).year()))
                                .font(.title2.bold())
                            Spacer()
                            Button {
                                selectedDate = Date()
                            } label: {
                                Text("Oggi")
                                    .font(.subheadline.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.blue.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal)
                        
                        WeekScrollView(selectedDate: $selectedDate)
                    }
                    .padding(.vertical)
                    .background(.ultraThinMaterial)
                    
                    // Agenda List
                    ScrollView {
                        VStack(spacing: 15) {
                            let dayEvents = manager.events(for: selectedDate)
                            
                            if dayEvents.isEmpty {
                                VStack(spacing: 20) {
                                    Image(systemName: "calendar.badge.plus")
                                        .font(.system(size: 60))
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 60)
                                    Text("Nessun evento per oggi")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                ForEach(dayEvents) { event in
                                    EventCard(event: event)
                                        .transition(.move(edge: .trailing).combined(with: .opacity))
                                }
                            }
                            
                            Spacer(minLength: 100)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Calendario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddEvent.toggle()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingAddEvent) {
                AddEventView(isPresented: $showingAddEvent, initialDate: selectedDate)
            }
        }
    }
}

struct WeekScrollView: View {
    @Binding var selectedDate: Date
    let calendar = Calendar.current
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(-15..<15) { day in
                    let date = calendar.date(byAdding: .day, value: day, to: Date())!
                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                    
                    VStack(spacing: 8) {
                        Text(date.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.caption2.bold())
                            .foregroundStyle(isSelected ? .white : .secondary)
                        
                        Text(date.formatted(.dateTime.day()))
                            .font(.headline)
                            .foregroundStyle(isSelected ? .white : .primary)
                    }
                    .frame(width: 45, height: 70)
                    .background(isSelected ? Color.blue : Color.blue.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onTapGesture {
                        withAnimation(.spring()) {
                            selectedDate = date
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct EventCard: View {
    let event: BloomEvent
    @ObservedObject var manager = CalendarManager.shared
    
    var body: some View {
        HStack(spacing: 15) {
            // Time Column
            VStack(alignment: .trailing) {
                Text(event.startTime, format: .dateTime.hour().minute())
                    .font(.subheadline.bold())
                if let endTime = event.endTime {
                    Text(endTime, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 55)
            
            // Category Bar
            Rectangle()
                .fill(categoryColor)
                .frame(width: 4)
                .clipShape(Capsule())
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                    .strikethrough(event.isCompleted)
                
                if !event.notes.isEmpty {
                    Text(event.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Text(event.category)
                    .font(.system(size: 8, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(categoryColor.opacity(0.1))
                    .foregroundColor(categoryColor)
                    .clipShape(Capsule())
            }
            
            Spacer()
            
            Button {
                withAnimation {
                    manager.toggleComplete(event)
                }
            } label: {
                Image(systemName: event.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(event.isCompleted ? .green : .secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                withAnimation {
                    manager.deleteEvent(event)
                }
            } label: {
                Label("Elimina", systemImage: "trash")
            }
        }
    }
    
    var categoryColor: Color {
        switch event.category {
        case "Lavoro": return .orange
        case "Personale": return .green
        case "Importante": return .red
        default: return .blue
        }
    }
}

struct AddEventView: View {
    @Binding var isPresented: Bool
    let initialDate: Date
    
    @State private var title = ""
    @State private var date: Date
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600)
    @State private var category = "Generale"
    @State private var notes = ""
    
    init(isPresented: Binding<Bool>, initialDate: Date) {
        self._isPresented = isPresented
        self.initialDate = initialDate
        self._date = State(initialValue: initialDate)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Dettagli") {
                    TextField("Titolo evento", text: $title)
                    DatePicker("Data", selection: $date, displayedComponents: .date)
                    DatePicker("Inizio", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("Fine", selection: $endTime, displayedComponents: .hourAndMinute)
                }
                
                Section("Altro") {
                    Picker("Categoria", selection: $category) {
                        Text("Generale").tag("Generale")
                        Text("Lavoro").tag("Lavoro")
                        Text("Personale").tag("Personale")
                        Text("Importante").tag("Importante")
                    }
                    TextField("Note", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle("Nuovo Evento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annulla") { isPresented = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Salva") {
                        CalendarManager.shared.addEvent(title: title, date: date, startTime: startTime, endTime: endTime, category: category, notes: notes)
                        isPresented = false
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}
