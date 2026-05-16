import SwiftUI

struct CalendarView: View {
    @StateObject var manager = CalendarManager.shared
    @State private var selectedDate = Date()
    @State private var showingAddEvent = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Standard Month Calendar
                    DatePicker("Data", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding()
                    
                    // Events List
                    List {
                        let dayEvents = manager.events(for: selectedDate)
                        
                        if dayEvents.isEmpty {
                            Section {
                                ContentUnavailableView {
                                    Label("Nessun Evento", systemImage: "calendar.badge.plus")
                                } description: {
                                    Text("Non ci sono eventi programmati per questa giornata.")
                                } actions: {
                                    Button("Aggiungi Evento") {
                                        showingAddEvent = true
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                            .listRowBackground(Color.clear)
                        } else {
                            Section("Eventi di oggi") {
                                ForEach(dayEvents) { event in
                                    EventRow(event: event)
                                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
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
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Calendario")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddEvent.toggle()
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline)
                    }
                }
            }
            .sheet(isPresented: $showingAddEvent) {
                AddEventView(isPresented: $showingAddEvent, initialDate: selectedDate)
            }
        }
    }
}

struct EventRow: View {
    let event: BloomEvent
    @ObservedObject var manager = CalendarManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            VStack {
                Text(event.startTime, format: .dateTime.hour().minute())
                    .font(.headline)
                if let end = event.endTime {
                    Text(end, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 50)
            
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
                
                HStack {
                    Circle()
                        .fill(categoryColor)
                        .frame(width: 8, height: 8)
                    Text(event.category)
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
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
        .clipShape(RoundedRectangle(cornerRadius: 15))
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
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var category = "Generale"
    @State private var notes = ""
    
    init(isPresented: Binding<Bool>, initialDate: Date) {
        self._isPresented = isPresented
        self.initialDate = initialDate
        self._date = State(initialValue: initialDate)
        self._startTime = State(initialValue: initialDate)
        self._endTime = State(initialValue: initialDate.addingTimeInterval(3600))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Informazioni Principali") {
                    TextField("Titolo evento", text: $title)
                    DatePicker("Data", selection: $date, displayedComponents: .date)
                }
                
                Section("Orario") {
                    DatePicker("Dalle", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("Alle", selection: $endTime, displayedComponents: .hourAndMinute)
                }
                
                Section("Dettagli") {
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
