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
    @FocusState private var focused: Field?

    enum Field { case email, name, password, confirm }

    var body: some View {
        ZStack {
            background

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    header
                    authCard
                }
                .padding(.horizontal, 24)
                .padding(.top, 56)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) {
                appeared = true
            }
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "050508"),
                    Color(hex: "0C1020"),
                    Color(hex: "101828")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.blue.opacity(0.22))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: -120, y: -260)

            Circle()
                .fill(Color.cyan.opacity(0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 80)
                .offset(x: 140, y: 120)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.06))
                    .frame(width: 88, height: 88)
                    .glassEffect(.regular, in: Circle())

                Image(systemName: "road.lanes")
                    .font(.system(size: 36, weight: .thin))
                    .foregroundStyle(.white.opacity(0.95))
            }
            .scaleEffect(appeared ? 1 : 0.88)
            .opacity(appeared ? 1 : 0)

            Text("Road")
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Text("Your premium 125cc navigator")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.55))
        }
        .offset(y: appeared ? 0 : 16)
        .opacity(appeared ? 1 : 0)
    }

    private var authCard: some View {
        VStack(spacing: 18) {
            HStack(spacing: 6) {
                segmentButton("Sign In", selected: isLogin) {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) { isLogin = true }
                }
                segmentButton("Sign Up", selected: !isLogin) {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) { isLogin = false }
                }
            }
            .padding(4)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))

            VStack(spacing: 12) {
                if !isLogin {
                    authField("Full name", text: $name, icon: "person")
                        .focused($focused, equals: .name)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                authField("Email", text: $email, icon: "envelope", keyboard: .emailAddress)
                    .focused($focused, equals: .email)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                authField("Password", text: $password, icon: "lock", secure: true)
                    .focused($focused, equals: .password)

                if !isLogin {
                    authField("Confirm password", text: $confirmPassword, icon: "lock.fill", secure: true)
                        .focused($focused, equals: .confirm)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.86), value: isLogin)

            if let err = auth.authError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }

            Button(action: submit) {
                ZStack {
                    if auth.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text(isLogin ? "Continue" : "Create Account")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "3B82F6"), Color(hex: "2563EB")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 16)
                )
            }
            .disabled(auth.isLoading)
        }
        .padding(22)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(.white.opacity(0.14), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.28), radius: 30, y: 18)
        .offset(y: appeared ? 0 : 24)
        .opacity(appeared ? 1 : 0)
    }

    private func segmentButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(selected ? .white : .white.opacity(0.45))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background {
                    if selected {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.white.opacity(0.14))
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func authField(
        _ placeholder: String,
        text: Binding<String>,
        icon: String,
        keyboard: UIKeyboardType = .default,
        secure: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
                .frame(width: 20)

            if secure {
                SecureField(placeholder, text: text)
                    .foregroundStyle(.white)
                    .tint(.blue)
            } else {
                TextField(placeholder, text: text)
                    .foregroundStyle(.white)
                    .tint(.blue)
                    .keyboardType(keyboard)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 14))
    }

    private func submit() {
        focused = nil
        if isLogin {
            auth.login(email: email, password: password)
        } else {
            guard password == confirmPassword else {
                auth.authError = "Passwords do not match."
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
