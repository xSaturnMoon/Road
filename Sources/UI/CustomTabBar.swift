import SwiftUI

enum Tab: String, CaseIterable {
    case calendar = "Calendario"
    case shopping = "Spesa"
    case weather = "Meteo"
    
    var icon: String {
        switch self {
        case .calendar: return "calendar"
        case .shopping: return "cart"
        case .weather: return "cloud.sun"
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: Tab
    @Binding var showSettings: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Main Pill
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.spring()) {
                            selectedTab = tab
                            showSettings = false
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 20, weight: .medium))
                            Text(tab.rawValue)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(selectedTab == tab && !showSettings ? .white : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                }
            }
            .frame(maxWidth: 280)
            .background(.ultraThinMaterial)
            .environment(\.colorScheme, .dark) // Force dark glass effect
            .clipShape(Capsule())
            
            // Settings Button
            Button(action: {
                withAnimation(.spring()) {
                    showSettings = true
                }
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(showSettings ? .white : .gray)
                    .frame(width: 60, height: 60)
                    .background(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}
