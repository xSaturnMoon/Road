import SwiftUI

struct CalendarView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.gray.ignoresSafeArea()
                Text("Calendario").font(.largeTitle).foregroundColor(.white)
            }
            .navigationTitle("Calendario")
        }
    }
}

struct ShoppingView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.gray.ignoresSafeArea()
                Text("Spesa").font(.largeTitle).foregroundColor(.white)
            }
            .navigationTitle("Spesa")
        }
    }
}

struct WeatherView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.gray.ignoresSafeArea()
                Text("Meteo").font(.largeTitle).foregroundColor(.white)
            }
            .navigationTitle("Meteo")
        }
    }
}

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.gray.ignoresSafeArea()
                Text("Impostazioni").font(.largeTitle).foregroundColor(.white)
            }
            .navigationTitle("Impostazioni")
        }
    }
}
