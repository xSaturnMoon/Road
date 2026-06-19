import SwiftUI

struct AuthView: View {
    @Binding var isPresented: Bool
    @StateObject private var auth = AuthManager.shared

    @State private var isLogin = true
    @State private var email = ""
    @State private var name = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @FocusState private var focused: Field?

    enum Field { case email, name, password, confirm }

    var body: some View {
        ZStack {
            // Premium gradient background
            LinearGradient(
                colors: [
                    Color(hex: "0F0F1A"),
                    Color(hex: "1A1A2E"),
                    Color(hex: "16213E")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Animated gradient orbs
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "4F46E5").opacity(0.15), Color(hex: "7C3AED").opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 350, height: 350)
                    .blur(radius: 100)
                    .offset(x: -100, y: -150)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "06B6D4").opacity(0.12), Color(hex: "3B82F6").opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 300, height: 300)
                    .blur(radius: 90)
                    .offset(x: 120, y: 100)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Premium logo section
                VStack(spacing: 20) {
                    // Logo with glow
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "4F46E5"), Color(hex: "7C3AED")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .shadow(color: Color(hex: "4F46E5").opacity(0.4), radius: 20, x: 0, y: 10)

                        Image(systemName: "road.lanes")
                            .font(.system(size: 36, weight: .thin))
                            .foregroundStyle(.white)
                    }

                    VStack(spacing: 8) {
                        Text("Road")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text("Premium Navigation for 125cc")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                            .letterSpacing(0.5)
                    }
                }
                .padding(.bottom, 50)

                // Premium glass card
                VStack(spacing: 24) {
                    // Premium segment control
                    HStack(spacing: 0) {
                        premiumSegBtn("Sign In", selected: isLogin) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                isLogin = true
                            }
                        }
                        premiumSegBtn("Sign Up", selected: !isLogin) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                isLogin = false
                            }
                        }
                    }
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )

                    if !isLogin {
                        premiumField("Full Name", text: $name, icon: "person.fill")
                            .focused($focused, equals: .name)
                    }

                    premiumField("Email Address", text: $email, icon: "envelope.fill", keyboard: .emailAddress)
                        .focused($focused, equals: .email)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    premiumField("Password", text: $password, icon: "lock.fill", secure: true)
                        .focused($focused, equals: .password)

                    if !isLogin {
                        premiumField("Confirm Password", text: $confirmPassword, icon: "lock.shield.fill", secure: true)
                            .focused($focused, equals: .confirm)
                    }

                    if let err = auth.authError {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.red.opacity(0.9))
                            Text(err)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.red.opacity(0.9))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(.red.opacity(0.2), lineWidth: 1)
                        )
                    }

                    // Premium CTA button
                    Button {
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
                    } label: {
                        ZStack {
                            // Button background gradient
                            LinearGradient(
                                colors: [
                                    Color(hex: "4F46E5"),
                                    Color(hex: "7C3AED"),
                                    Color(hex: "6366F1")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .ignoresSafeArea()

                            // Button content
                            if auth.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.2)
                            } else {
                                Text(isLogin ? "Sign In" : "Create Account")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color(hex: "4F46E5").opacity(0.4), radius: 20, x: 0, y: 8)
                    }
                    .disabled(auth.isLoading)
                    .buttonStyle(.plain)
                }
                .padding(28)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 40, y: 20)
                .padding(.horizontal, 24)

                Spacer()
                Spacer()
            }
        }
    }

    @ViewBuilder
    func premiumSegBtn(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(selected ? .white : .white.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    selected
                        ? LinearGradient(
                            colors: [Color(hex: "4F46E5"), Color(hex: "7C3AED")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .in(RoundedRectangle(cornerRadius: 10))
                        : nil
                )
                .padding(4)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    func premiumField(_ placeholder: String, text: Binding<String>, icon: String, keyboard: UIKeyboardType = .default, secure: Bool = false) -> some View {
        HStack(spacing: 14) {
            // Icon with gradient background
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "4F46E5").opacity(0.2), Color(hex: "7C3AED").opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "4F46E5"), Color(hex: "7C3AED")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Text field
            if secure {
                SecureField(placeholder, text: text)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .tint(Color(hex: "7C3AED"))
            } else {
                TextField(placeholder, text: text)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .tint(Color(hex: "7C3AED"))
                    .keyboardType(keyboard)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
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
