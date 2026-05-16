import SwiftUI

struct CalendarView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    Text("Schermata Calendario vuota")
                        .font(.title)
                        .foregroundStyle(.secondary)
                        .padding(.top, 100)
                }
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Calendario")
        }
    }
}
