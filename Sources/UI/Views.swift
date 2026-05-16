import SwiftUI

struct CalendarView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(0..<20) { i in
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.blue.opacity(0.1))
                            .frame(height: 80)
                            .overlay(Text("Evento \(i + 1)").bold())
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Calendario")
        }
    }
}

struct ShoppingView: View {
    var body: some View {
        NavigationStack {
            List {
                ForEach(0..<15) { i in
                    Text("Prodotto \(i + 1)")
                }
            }
            .navigationTitle("Spesa")
        }
    }
}

struct WeatherView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(0..<5) { i in
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.orange.gradient)
                            .frame(height: 150)
                            .overlay(Text("Previsione \(i + 1)").font(.title).bold().foregroundColor(.white))
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Meteo")
        }
    }
}

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Generale") {
                    Text("Profilo")
                    Text("Notifiche")
                }
                Section("Avanzate") {
                    Text("Privacy")
                    Text("Informazioni")
                }
            }
            .navigationTitle("Impostazioni")
        }
    }
}

