import SwiftUI

struct CalendarView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear.ignoresSafeArea()
                Text("Calendario").font(.largeTitle).foregroundColor(.white)
            }
            .navigationTitle("Calendario")
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

struct ShoppingView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear.ignoresSafeArea()
                Text("Spesa").font(.largeTitle).foregroundColor(.white)
            }
            .navigationTitle("Spesa")
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

struct WeatherView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear.ignoresSafeArea()
                Text("Meteo").font(.largeTitle).foregroundColor(.white)
            }
            .navigationTitle("Meteo")
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear.ignoresSafeArea()
                Text("Impostazioni").font(.largeTitle).foregroundColor(.white)
            }
            .navigationTitle("Impostazioni")
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}
