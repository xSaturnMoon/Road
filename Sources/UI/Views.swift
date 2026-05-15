import SwiftUI

struct CalendarView: View {
    var body: some View {
        Color.gray.ignoresSafeArea()
            .overlay(Text("Calendario").font(.largeTitle).foregroundColor(.white))
    }
}

struct ShoppingView: View {
    var body: some View {
        Color.gray.ignoresSafeArea()
            .overlay(Text("Spesa").font(.largeTitle).foregroundColor(.white))
    }
}

struct WeatherView: View {
    var body: some View {
        Color.gray.ignoresSafeArea()
            .overlay(Text("Meteo").font(.largeTitle).foregroundColor(.white))
    }
}

struct SettingsView: View {
    var body: some View {
        Color.gray.ignoresSafeArea()
            .overlay(Text("Impostazioni").font(.largeTitle).foregroundColor(.white))
    }
}
