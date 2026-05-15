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
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
                        .foregroundColor(selectedTab == tab && !showSettings ? .white : .white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                }
            }
            .frame(maxWidth: 280)
            .background(.thinMaterial)
            .environment(\.colorScheme, .dark)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 15, x: 0, y: 8)
            
            // Settings Button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showSettings = true
                }
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(showSettings ? .white : .white.opacity(0.5))
                    .frame(width: 60, height: 60)
                    .background(.thinMaterial)
                    .environment(\.colorScheme, .dark)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 15, x: 0, y: 8)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
    }
}
