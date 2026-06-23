import SwiftUI

struct SettingsView: View {
    @StateObject var auth = AuthManager.shared
    @ObservedObject private var motorcycle = MotorcycleStore.shared
    @State private var showingAuthModal = false
    @State private var showLogoutAlert = false
    @AppStorage("theme") private var theme: String = "Sistema"
    let themes = ["Sistema", "Chiaro", "Scuro"]

    private let displacementOptions = [50, 80, 95, 110, 125, 150, 200, 250, 300, 350, 400, 500, 650, 750, 900, 1000, 1200]

    var appVersion: String {
        if let url = Bundle.main.url(forResource: "version", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let v = json["version"] as? String { return v }
        return "1.0.0"
    }

    var body: some View {
        NavigationStack {
            Form {
                if let user = auth.currentUser {
                    Section {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 50, height: 50)
                                Text(String(user.email.prefix(1)).uppercased())
                                    .font(.title2.bold())
                                    .foregroundStyle(.blue)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.name)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Section("Account") {
                        Button(role: .destructive) {
                            showLogoutAlert = true
                        } label: {
                            Text("Esci")
                        }
                    }
                } else {
                    Section {
                        Button {
                            showingAuthModal = true
                        } label: {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.title2)
                                Text("Accedi o Registrati")
                            }
                        }
                    }
                }

                Section("Aspetto") {
                    Picker("Tema", selection: $theme) {
                        ForEach(themes, id: \.self) { Text($0) }
                    }
                }

                Section {
                    Picker("Modello", selection: $motorcycle.presetID) {
                        ForEach(MotorcyclePresets.all) { preset in
                            Text(preset.displayName).tag(preset.id)
                        }
                        Text("Personalizzata").tag(MotorcyclePresets.customID)
                    }
                    .onChange(of: motorcycle.presetID) { _, newID in
                        if let preset = MotorcyclePresets.preset(id: newID) {
                            motorcycle.applyPreset(preset)
                        } else {
                            motorcycle.useCustomProfile()
                        }
                    }

                    if motorcycle.isCustom {
                        TextField("Marca", text: $motorcycle.brand)
                            .textInputAutocapitalization(.words)

                        TextField("Modello", text: $motorcycle.model)
                            .textInputAutocapitalization(.words)

                        Picker("Cilindrata", selection: $motorcycle.displacementCC) {
                            ForEach(displacementOptions, id: \.self) { cc in
                                Text("\(cc) cc").tag(cc)
                            }
                        }

                        Picker("Motore", selection: Binding(
                            get: { motorcycle.stroke },
                            set: { motorcycle.stroke = $0 }
                        )) {
                            ForEach(EngineStroke.allCases) { stroke in
                                Text(stroke.rawValue).tag(stroke)
                            }
                        }
                    } else if let preset = motorcycle.selectedPreset {
                        LabeledContent("Marca", value: preset.brand)
                        LabeledContent("Modello", value: preset.model)
                        LabeledContent("Cilindrata", value: "\(preset.displacementCC) cc")
                        LabeledContent("Motore", value: preset.stroke.rawValue)
                    }

                    LabeledContent("Consumo stimato") {
                        Text(String(format: "%.1f L/100 km", motorcycle.fuelConsumptionL100))
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("La mia moto")
                } footer: {
                    Text("Valori basati su dati reali WMTC e consumi medi in uso reale. Il carburante del percorso considera anche il tipo di strada.")
                }

                Section("App") {
                    HStack {
                        Text("Versione")
                        Spacer()
                        Text(appVersion).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                if motorcycle.brand.isEmpty && motorcycle.model.isEmpty && !motorcycle.isCustom,
                   let preset = motorcycle.selectedPreset {
                    motorcycle.applyPreset(preset)
                }
            }
            .alert("Esci dall'account?", isPresented: $showLogoutAlert) {
                Button("Esci", role: .destructive) { auth.logout() }
                Button("Annulla", role: .cancel) {}
            }
            .sheet(isPresented: $showingAuthModal) {
                AuthView(isPresented: $showingAuthModal)
            }
        }
    }
}
