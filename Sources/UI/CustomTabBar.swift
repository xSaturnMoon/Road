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
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
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
                        .foregroundColor(selectedTab == tab && !showSettings ? Color(white: 0.9) : Color.white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                }
            }
            .frame(maxWidth: 280)
            .modifier(CapsuleGlass())
            
            // Settings Button
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showSettings = true
                }
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(showSettings ? Color(white: 0.9) : Color.white.opacity(0.4))
                    .frame(width: 60, height: 60)
                    .modifier(CircleGlass())
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
    }
}

// MARK: - Official Glass Modifiers (from Lapis/iStore)
struct CapsuleGlass: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .opacity(0.7)
            )
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .environment(\.colorScheme, .dark)
    }
}

struct CircleGlass: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                Circle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.7)
            )
            .background(
                Circle()
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .environment(\.colorScheme, .dark)
    }
}
