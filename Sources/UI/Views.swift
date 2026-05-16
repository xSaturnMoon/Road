import SwiftUI

struct CalendarView: View {
    var body: some View {
        VStack {
            Spacer()
            Text("Calendario")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .shadow(radius: 10)
            Spacer()
        }
    }
}

struct ShoppingView: View {
    var body: some View {
        VStack {
            Spacer()
            Text("Spesa")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .shadow(radius: 10)
            Spacer()
        }
    }
}

struct WeatherView: View {
    var body: some View {
        VStack {
            Spacer()
            Text("Meteo")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .shadow(radius: 10)
            Spacer()
        }
    }
}

struct SettingsView: View {
    var body: some View {
        VStack {
            Spacer()
            Text("Impostazioni")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .shadow(radius: 10)
            Spacer()
        }
    }
}
