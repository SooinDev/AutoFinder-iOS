import SwiftUI
import Combine

// MARK: - 로그인 뷰
struct LoginView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var isShowingRegister = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        ZStack {
            // 배경 그라데이션
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(UIConstants.Colors.primaryBlue).opacity(0.1),
                    Color(UIConstants.Colors.backgroundColor)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: UIConstants.Spacing.xl) {
                Spacer()
                
                // 앱 로고 및 타이틀
                VStack(spacing: UIConstants.Spacing.lg) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 80))
                        .foregroundColor(Color(UIConstants.Colors.primaryBlue))
                    
                    Text(AppConstants.appName)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(Color(UIConstants.Colors.textPrimary))
                    
                    Text("당신에게 맞는 완벽한 차량을 찾아보세요")
                        .font(.subheadline)
                        .foregroundColor(Color(UIConstants.Colors.textSecondary))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // 로그인 폼
                if isShowingRegister {
                    RegisterFormView(
                        isShowingRegister: $isShowingRegister,
                        showingAlert: $showingAlert,
                        alertMessage: $alertMessage
                    )
                } else {
                    LoginFormView(
                        isShowingRegister: $isShowingRegister,
                        showingAlert: $showingAlert,
                        alertMessage: $alertMessage
                    )
                }
                
                Spacer()
                
                // 하단 정보
                VStack(spacing: UIConstants.Spacing.sm) {
                    Text("AutoFinder v\(AppConstants.version)")
                        .font(.caption)
                        .foregroundColor(Color(UIConstants.Colors.textSecondary))
                    
                    Text("AI 기반 개인화 차량 추천 서비스")
                        .font(.caption2)
                        .foregroundColor(Color(UIConstants.Colors.textSecondary))
                }
            }
            .padding()
        }
        .alert("알림", isPresented: $showingAlert) {
            Button("확인") {}
        } message: {
            Text(alertMessage)
        }
        .onReceive(authManager.$authError) { error in
            if let error = error {
                alertMessage = error.localizedDescription
                showingAlert = true
                authManager.clearError()
            }
        }
    }
}

// MARK: - 로그인 폼 뷰
struct LoginFormView: View {
    @StateObject private var authManager = AuthManager.shared
    @Binding var isShowingRegister: Bool
    @Binding var showingAlert: Bool
    @Binding var alertMessage: String
    
    @State private var username = ""
    @State private var password = ""
    @State private var rememberMe = false
    @State private var isPasswordVisible = false
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        VStack(spacing: UIConstants.Spacing.lg) {
            // 로그인 타이틀
            Text("로그인")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Color(UIConstants.Colors.textPrimary))
            
            VStack(spacing: UIConstants.Spacing.md) {
                // 아이디 입력
                CustomTextField(
                    text: $username,
                    placeholder: "아이디",
                    systemImage: "person.fill"
                )
                .textContentType(.username)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                
                // 비밀번호 입력
                CustomSecureField(
                    text: $password,
                    placeholder: "비밀번호",
                    systemImage: "lock.fill",
                    isVisible: $isPasswordVisible
                )
                .textContentType(.password)
                
                // 로그인 유지 옵션
                HStack {
                    Button(action: {
                        rememberMe.toggle()
                    }) {
                        HStack(spacing: UIConstants.Spacing.xs) {
                            Image(systemName: rememberMe ? "checkmark.square.fill" : "square")
                                .foregroundColor(rememberMe ? Color(UIConstants.Colors.primaryBlue) : Color(UIConstants.Colors.secondaryGray))
                            
                            Text("로그인 상태 유지")
                                .font(.caption)
                                .foregroundColor(Color(UIConstants.Colors.textSecondary))
                        }
                    }
                    
                    Spacer()
                }
            }
            
            // 로그인 버튼
            Button("로그인") {
                performLogin()
            }
            .buttonStyle(PrimaryButtonStyle(theme: ThemeManager.shared))
            .disabled(username.isEmpty || password.isEmpty || authManager.isLoading)
            .opacity((username.isEmpty || password.isEmpty || authManager.isLoading) ? 0.6 : 1.0)
            
            // 로딩 인디케이터
            if authManager.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(UIConstants.Colors.primaryBlue)))
            }
            
            // 회원가입 링크
            HStack {
                Text("계정이 없으신가요?")
                    .font(.caption)
                    .foregroundColor(Color(UIConstants.Colors.textSecondary))
                
                Button("회원가입") {
                    withAnimation(.easeInOut) {
                        isShowingRegister = true
                    }
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color(UIConstants.Colors.primaryBlue))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: UIConstants.CornerRadius.large)
                .fill(Color(UIConstants.Colors.cardBackground))
                .shadow(
                    color: Color.black.opacity(UIConstants.Shadow.opacity),
                    radius: UIConstants.Shadow.radius,
                    x: UIConstants.Shadow.offset.width,
                    y: UIConstants.Shadow.offset.height
                )
        )
    }
    
    private func performLogin() {
        // 입력 검증
        if let error = validateLoginInput() {
            alertMessage = error
            showingAlert = true
            return
        }
        
        // 로그인 실행
        authManager.login(
            username: username,
            password: password,
            rememberMe: rememberMe
        )
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            },
            receiveValue: { _ in
                // 로그인 성공 - AuthManager에서 처리
            }
        )
        .store(in: &cancellables)
    }
    
    private func validateLoginInput() -> String? {
        if username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "아이디를 입력해주세요"
        }
        
        if password.isEmpty {
            return "비밀번호를 입력해주세요"
        }
        
        return nil
    }
}

// MARK: - 회원가입 폼 뷰
struct RegisterFormView: View {
    @StateObject private var authManager = AuthManager.shared
    @Binding var isShowingRegister: Bool
    @Binding var showingAlert: Bool
    @Binding var alertMessage: String
    
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isPasswordVisible = false
    @State private var isConfirmPasswordVisible = false
    @State private var isCheckingUsername = false
    @State private var usernameValidationMessage = ""
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        VStack(spacing: UIConstants.Spacing.lg) {
            // 회원가입 타이틀
            Text("회원가입")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Color(UIConstants.Colors.textPrimary))
            
            VStack(spacing: UIConstants.Spacing.md) {
                // 아이디 입력
                VStack(alignment: .leading, spacing: UIConstants.Spacing.xs) {
                    CustomTextField(
                        text: $username,
                        placeholder: "아이디 (3자 이상)",
                        systemImage: "person.fill"
                    )
                    .textContentType(.username)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onChange(of: username) { _ in
                        validateUsername()
                    }
                    
                    if !usernameValidationMessage.isEmpty {
                        HStack {
                            Image(systemName: usernameValidationMessage.contains("사용 가능") ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(usernameValidationMessage.contains("사용 가능") ? Color(UIConstants.Colors.successColor) : Color(UIConstants.Colors.accentColor))
                                .font(.caption)
                            
                            Text(usernameValidationMessage)
                                .font(.caption)
                                .foregroundColor(usernameValidationMessage.contains("사용 가능") ? Color(UIConstants.Colors.successColor) : Color(UIConstants.Colors.accentColor))
                        }
                    }
                }
                
                // 비밀번호 입력
                VStack(alignment: .leading, spacing: UIConstants.Spacing.xs) {
                    CustomSecureField(
                        text: $password,
                        placeholder: "비밀번호 (6자 이상)",
                        systemImage: "lock.fill",
                        isVisible: $isPasswordVisible
                    )
                    .textContentType(.newPassword)
                    
                    if !password.isEmpty {
                        PasswordStrengthView(password: password)
                    }
                }
                
                // 비밀번호 확인
                CustomSecureField(
                    text: $confirmPassword,
                    placeholder: "비밀번호 확인",
                    systemImage: "lock.fill",
                    isVisible: $isConfirmPasswordVisible
                )
                .textContentType(.newPassword)
                
                if !confirmPassword.isEmpty && password != confirmPassword {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(UIConstants.Colors.accentColor))
                            .font(.caption)
                        
                        Text("비밀번호가 일치하지 않습니다")
                            .font(.caption)
                            .foregroundColor(Color(UIConstants.Colors.accentColor))
                    }
                }
            }
            
            // 회원가입 버튼
            Button("회원가입") {
                performRegister()
            }
            .buttonStyle(PrimaryButtonStyle(theme: ThemeManager.shared))
            .disabled(!isFormValid || authManager.isLoading)
            .opacity((!isFormValid || authManager.isLoading) ? 0.6 : 1.0)
            
            // 로딩 인디케이터
            if authManager.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(UIConstants.Colors.primaryBlue)))
            }
            
            // 로그인 링크
            HStack {
                Text("이미 계정이 있으신가요?")
                    .font(.caption)
                    .foregroundColor(Color(UIConstants.Colors.textSecondary))
                
                Button("로그인") {
                    withAnimation(.easeInOut) {
                        isShowingRegister = false
                    }
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color(UIConstants.Colors.primaryBlue))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: UIConstants.CornerRadius.large)
                .fill(Color(UIConstants.Colors.cardBackground))
                .shadow(
                    color: Color.black.opacity(UIConstants.Shadow.opacity),
                    radius: UIConstants.Shadow.radius,
                    x: UIConstants.Shadow.offset.width,
                    y: UIConstants.Shadow.offset.height
                )
        )
    }
    
    private var isFormValid: Bool {
        return !username.isEmpty &&
               !password.isEmpty &&
               !confirmPassword.isEmpty &&
               password == confirmPassword &&
               password.count >= 6 &&
               usernameValidationMessage.contains("사용 가능")
    }
    
    private func validateUsername() {
        guard !username.isEmpty else {
            usernameValidationMessage = ""
            return
        }
        
        // 로컬 검증
        if let localError = authManager.validateUsername(username) {
            usernameValidationMessage = localError
            return
        }
        
        // 서버 검증 (디바운스)
        isCheckingUsername = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if self.username == username { // 사용자가 계속 타이핑하지 않았을 때만
                self.checkUsernameAvailability(username)
            }
        }
    }
    
    private func checkUsernameAvailability(_ username: String) {
        authManager.checkUsernameAvailability(username: username)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    self.isCheckingUsername = false
                    if case .failure(_) = completion {
                        self.usernameValidationMessage = "아이디 확인 실패"
                    }
                },
                receiveValue: { isAvailable in
                    self.usernameValidationMessage = isAvailable ? "사용 가능한 아이디입니다" : "이미 사용 중인 아이디입니다"
                }
            )
            .store(in: &cancellables)
    }
    
    private func performRegister() {
        // 입력 검증
        if let error = validateRegisterInput() {
            alertMessage = error
            showingAlert = true
            return
        }
        
        // 회원가입 실행
        authManager.register(username: username, password: password)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        self.alertMessage = error.localizedDescription
                        self.showingAlert = true
                    }
                },
                receiveValue: { user in
                    // 회원가입 성공
                    self.alertMessage = "회원가입이 완료되었습니다. 로그인해주세요."
                    self.showingAlert = true
                    
                    // 로그인 화면으로 전환
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation(.easeInOut) {
                            self.isShowingRegister = false
                        }
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func validateRegisterInput() -> String? {
        if let usernameError = authManager.validateUsername(username) {
            return usernameError
        }
        
        if let passwordError = authManager.validatePassword(password) {
            return passwordError
        }
        
        if let confirmError = authManager.validatePasswordConfirmation(password, confirmPassword) {
            return confirmError
        }
        
        if !usernameValidationMessage.contains("사용 가능") {
            return "아이디 사용 가능 여부를 확인해주세요"
        }
        
        return nil
    }
}

// MARK: - 커스텀 텍스트 필드
struct CustomTextField: View {
    @Binding var text: String
    let placeholder: String
    let systemImage: String
    
    var body: some View {
        HStack(spacing: UIConstants.Spacing.sm) {
            Image(systemName: systemImage)
                .foregroundColor(Color(UIConstants.Colors.secondaryGray))
                .frame(width: 20)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding()
        .background(Color(UIConstants.Colors.backgroundColor))
        .cornerRadius(UIConstants.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium)
                .stroke(Color(UIConstants.Colors.secondaryGray).opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - 커스텀 보안 필드
struct CustomSecureField: View {
    @Binding var text: String
    let placeholder: String
    let systemImage: String
    @Binding var isVisible: Bool
    
    var body: some View {
        HStack(spacing: UIConstants.Spacing.sm) {
            Image(systemName: systemImage)
                .foregroundColor(Color(UIConstants.Colors.secondaryGray))
                .frame(width: 20)
            
            if isVisible {
                TextField(placeholder, text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
            } else {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
            }
            
            Button(action: {
                isVisible.toggle()
            }) {
                Image(systemName: isVisible ? "eye.slash.fill" : "eye.fill")
                    .foregroundColor(Color(UIConstants.Colors.secondaryGray))
            }
        }
        .padding()
        .background(Color(UIConstants.Colors.backgroundColor))
        .cornerRadius(UIConstants.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium)
                .stroke(Color(UIConstants.Colors.secondaryGray).opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - 비밀번호 강도 표시
//struct PasswordStrengthView: View {
//    let password: String
//    
//    private var strength: PasswordStrength {
//        return calculatePasswordStrength(password)
//    }
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: UIConstants.Spacing.xs) {
//            HStack {
//                Text("비밀번호 강도:")
//                    .font(.caption)
//                    .foregroundColor(Color(UIConstants.Colors.textSecondary))
//                
//                Text(strength.description)
//                    .font(.caption)
//                    .fontWeight(.medium)
//                    .foregroundColor(strength.color)
//            }
//            
//            // 강도 바
//            HStack(spacing: 2) {
//                ForEach(0..<4, id: \.self) { index in
//                    Rectangle()
//                        .fill(index < strength.level ? strength.color : Color(UIConstants.Colors.secondaryGray).opacity(0.3))
//                        .frame(height: 3)
//                        .cornerRadius(1.5)
//                }
//            }
//        }
//    }
//    
//    private func calculatePasswordStrength(_ password: String) -> PasswordStrength {
//        var score = 0
//        
//        // 길이 체크
//        if password.count >= 6 { score += 1 }
//        if password.count >= 8 { score += 1 }
//        
//        // 문자 종류 체크
//        if password.rangeOfCharacter(from: .lowercaseLetters) != nil { score += 1 }
//        if password.rangeOfCharacter(from: .uppercaseLetters) != nil { score += 1 }
//        if password.rangeOfCharacter(from: .decimalDigits) != nil { score += 1 }
//        if password.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:,.<>?")) != nil { score += 1 }
//        
//        // 점수에 따른 강도 반환
//        switch score {
//        case 0...2: return .weak
//        case 3...4: return .medium
//        case 5...6: return .strong
//        default: return .veryStrong
//        }
//    }
//}

// MARK: - 비밀번호 강도 열거형
//enum PasswordStrength {
//    case weak
//    case medium
//    case strong
//    case veryStrong
//    
//    var description: String {
//        switch self {
//        case .weak: return "약함"
//        case .medium: return "보통"
//        case .strong: return "강함"
//        case .veryStrong: return "매우 강함"
//        }
//    }
//    
//    var color: Color {
//        switch self {
//        case .weak: return Color(UIConstants.Colors.accentColor)
//        case .medium: return Color(UIConstants.Colors.warningColor)
//        case .strong: return Color(UIConstants.Colors.successColor)
//        case .veryStrong: return Color(UIConstants.Colors.primaryBlue)
//        }
//    }
//    
//    var level: Int {
//        switch self {
//        case .weak: return 1
//        case .medium: return 2
//        case .strong: return 3
//        case .veryStrong: return 4
//        }
//    }
//}

// MARK: - 소셜 로그인 뷰 (향후 확장용)
struct SocialLoginView: View {
    var body: some View {
        VStack(spacing: UIConstants.Spacing.md) {
            HStack {
                Rectangle()
                    .fill(Color(UIConstants.Colors.secondaryGray).opacity(0.3))
                    .frame(height: 1)
                
                Text("또는")
                    .font(.caption)
                    .foregroundColor(Color(UIConstants.Colors.textSecondary))
                    .padding(.horizontal, UIConstants.Spacing.sm)
                
                Rectangle()
                    .fill(Color(UIConstants.Colors.secondaryGray).opacity(0.3))
                    .frame(height: 1)
            }
            
            // Apple 로그인 (향후 구현)
            Button(action: {
                // Apple 로그인 구현
            }) {
                HStack {
                    Image(systemName: "applelogo")
                        .font(.title3)
                    
                    Text("Apple로 계속하기")
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.black)
                .cornerRadius(UIConstants.CornerRadius.medium)
            }
            
            // Google 로그인 (향후 구현)
            Button(action: {
                // Google 로그인 구현
            }) {
                HStack {
                    Image(systemName: "globe")
                        .font(.title3)
                    
                    Text("Google로 계속하기")
                        .fontWeight(.medium)
                }
                .foregroundColor(Color(UIConstants.Colors.textPrimary))
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white)
                .cornerRadius(UIConstants.CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium)
                        .stroke(Color(UIConstants.Colors.secondaryGray).opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
}

// MARK: - 프리뷰
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LoginView()
                .preferredColorScheme(.light)
                .previewDisplayName("Login View - Light")
            
            LoginView()
                .preferredColorScheme(.dark)
                .previewDisplayName("Login View - Dark")
            
            // 회원가입 상태 프리뷰
            LoginView()
                .onAppear {
                    // 회원가입 상태로 설정하는 코드는 실제 프리뷰에서는 동작하지 않음
                }
                .previewDisplayName("Register View")
            
            // 개별 컴포넌트 프리뷰
            VStack {
                CustomTextField(
                    text: .constant("test@example.com"),
                    placeholder: "이메일",
                    systemImage: "envelope.fill"
                )
                
                CustomSecureField(
                    text: .constant("password123"),
                    placeholder: "비밀번호",
                    systemImage: "lock.fill",
                    isVisible: .constant(false)
                )
                
                PasswordStrengthView(password: "Password123!")
            }
            .padding()
            .previewDisplayName("Form Components")
        }
    }
}
