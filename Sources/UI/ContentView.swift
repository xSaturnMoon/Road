import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .calendar
    @State private var showSettings: Bool = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main Content Area
            Group {
                if showSettings {
                    SettingsView()
                } else {
                    switch selectedTab {
                    case .calendar:
                        CalendarView()
                    case .shopping:
                        ShoppingView()
                    case .weather:
                        WeatherView()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Floating Tab Bar
            CustomTabBar(selectedTab: $selectedTab, showSettings: $showSettings)
        }
    }
}
