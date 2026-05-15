import SwiftUI

enum Tab {
    case calendar
    case shopping
    case weather
    case settings
}

struct ContentView: View {
    @State private var selectedTab: Tab = .calendar
    @State private var showSettings: Bool = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            CalendarView()
                .tabItem {
                    Label("Calendario", systemImage: "calendar")
                }
                .tag(Tab.calendar)
            
            ShoppingView()
                .tabItem {
                    Label("Spesa", systemImage: "cart")
                }
                .tag(Tab.shopping)
            
            WeatherView()
                .tabItem {
                    Label("Meteo", systemImage: "cloud.sun")
                }
                .tag(Tab.weather)
            
            SettingsView()
                .tabItem {
                    Label("Impostazioni", systemImage: "gearshape")
                }
                .tag(Tab.settings)
        }
        .tint(.primary)
    }
}
