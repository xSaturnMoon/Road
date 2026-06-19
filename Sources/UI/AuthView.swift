import SwiftUI

struct AuthView: View {
    @Binding var isPresented: Bool
    @StateObject private var auth = AuthManager.shared
    @Environment(\.colorScheme) private var colorScheme

    @State private var isLogin = true
    @State private var email = ""
    @State private var name = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var appeared = false
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @FocusState private var focused: Field?

    enum Field { case email, name, password, confirm }

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                scrollContent
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            LinearGradient(
                colors: [Color(hex: "0A0F1E"), Color(hex: "0D1B2A"), Color(hex: "091520")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // Glow top-left
            Circle()
                .fill(Color(hex: "1D4ED8").opacity(0.35))
                .frame(width: 400)
                .blur(radius: 100)
                .offset(x: -100, y: -200)

            // Glow bottom-right
            Circle()
                .fill(Color(hex: "0EA5E9").opacity(0.18))
                .frame(width: 300)
                .blur(radius: 80)
                .offset(x: 150, y: 300)
        }
    }

    // MARK: - Content

    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                logoSection
                    .padding(.top, 60)

                formCard
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Logo

    private var logoSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(hex: "1D4ED8").opacity(0.25))
                    .frame(width: 80, height: 80)
                    .blur(radius: 16)

                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 76, height: 76)
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )

                Image(systemName: "road.lanes")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color(hex: "93C5FD")],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            }
            .scaleEffect(appeared ? 1 : 0.85)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 6) {
                Text("Road")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(isLogin ? "Bentornato" : "Crea il tuo account")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .animation(.easeInOut(duration: 0.2), value: isLogin)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
        }
    }

    // MARK: - Form Card

    private var formCard: some View {
        VStack(spacing: 20) {
            // Segment
            segmentPicker

            // Fields
            VStack(spacing: 12) {
                if !isLogin {
                    inputField(
                        placeholder: "Nome completo",
                        text: $name,
                        icon: "person",
                        field: .name
                    )
                    .transition(.asymmetric(
                        insertion: .push(from: .top).combined(with: .opacity),
                        removal: .push(from: .bottom).combined(with: .opacity)
                    ))
                }

                inputField(
                    placeholder: "Email",
                    text: $email,
                    icon: "envelope",
                    field: .email,
                    keyboard: .emailAddress
                )
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

                passwordField(
                    placeholder: "Password",
                    text: $password,
                    show: $showPassword,
                    field: .password
                )

                if !isLogin {
                    passwordField(
                        placeholder: "Conferma password",
                        text: $confirmPassword,
                        show: $showConfirmPassword,
                        field: .confirm
                    )
                    .transition(.asymmetric(
                        insertion: .push(from: .top).combined(with: .opacity),
                        removal: .push(from: .bottom).combined(with: .opacity)
                    ))
                }
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.86), value: isLogin)

            // Error
            if let err = auth.authError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.9))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .transition(.opacity)
            }

            // Submit button
            submitButton

            // Divider + toggle
            VStack(spacing: 16) {
                HStack {
                    Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                    Text("oppure")
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.35))
                        .padding(.horizontal, 10)
                    Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                }

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        isLogin.toggle()
                        auth.authError = nil
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(isLogin ? "Non hai un account?" : "Hai già un account?")
                            .foregroundStyle(Color.white.opacity(0.5))
                        Text(isLogin ? "Registrati" : "Accedi")
                            .foregroundStyle(Color(hex: "60A5FA"))
                            .fontWeight(.semibold)
                    }
                    .font(.system(size: 14))
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.4), radius: 40, y: 20)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 30)
    }

    // MARK: - Segment Picker

    private var segmentPicker: some View {
        HStack(spacing: 0) {
            segmentTab("Accedi", selected: isLogin) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { isLogin = true }
            }
            segmentTab("Registrati", selected: !isLogin) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { isLogin = false }
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func segmentTab(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(selected ? .white : Color.white.opacity(0.4))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background {
                    if selected {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(hex: "1D4ED8").opacity(0.7))
                            .shadow(color: Color(hex: "3B82F6").opacity(0.4), radius: 8, y: 2)
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selected)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Input Fields

    private func inputField(
        placeholder: String,
        text: Binding<String>,
        icon: String,
        field: Field,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(focused == field ? Color(hex: "60A5FA") : Color.white.opacity(0.35))
                .frame(width: 18)
                .animation(.easeInOut(duration: 0.15), value: focused == field)

            TextField(placeholder, text: text)
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .tint(Color(hex: "60A5FA"))
                .keyboardType(keyboard)
                .focused($focused, equals: field)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(fieldBackground(active: focused == field))
    }

    private func passwordField(
        placeholder: String,
        text: Binding<String>,
        show: Binding<Bool>,
        field: Field
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "lock")
                .font(.system(size: 15))
                .foregroundStyle(focused == field ? Color(hex: "60A5FA") : Color.white.opacity(0.35))
                .frame(width: 18)
                .animation(.easeInOut(duration: 0.15), value: focused == field)

            Group {
                if show.wrappedValue {
                    TextField(placeholder, text: text)
                        .focused($focused, equals: field)
                } else {
                    SecureField(placeholder, text: text)
                        .focused($focused, equals: field)
                }
            }
            .font(.system(size: 15))
            .foregroundStyle(.white)
            .tint(Color(hex: "60A5FA"))

            Button {
                show.wrappedValue.toggle()
            } label: {
                Image(systemName: show.wrappedValue ? "eye.slash" : "eye")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.white.opacity(0.35))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(fieldBackground(active: focused == field))
    }

    private func fieldBackground(active: Bool) -> some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color.white.opacity(active ? 0.08 : 0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        active ? Color(hex: "3B82F6").opacity(0.6) : Color.white.opacity(0.08),
                        lineWidth: 1
                    )
            )
            .animation(.easeInOut(duration: 0.15), value: active)
    }

    // MARK: - Submit

    private var submitButton: some View {
        Button(action: submit) {
            ZStack {
                if auth.isLoading {
                    ProgressView().tint(.white)
                } else {
                    HStack(spacing: 8) {
                        Text(isLogin ? "Accedi" : "Crea Account")
                            .font(.system(size: 16, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "2563EB"), Color(hex: "1D4ED8")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color(hex: "3B82F6").opacity(0.4), radius: 12, y: 4)
            )
        }
        .disabled(auth.isLoading)
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func submit() {
        focused = nil
        if isLogin {
            auth.login(email: email, password: password)
        } else {
            guard password == confirmPassword else {
                auth.authError = "Le password non coincidono."
                return
            }
            auth.signUp(email: email, name: name, password: password)
        }
    }
}

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int & 0xFF)         / 255
        self.init(red: r, green: g, blue: b)
    }
}