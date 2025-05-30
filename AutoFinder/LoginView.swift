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
                    Color.primaryBlue.opacity(0.1),
                    Color.backgroundColor
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // 앱 로고 및 타이틀
                VStack(spacing: 24) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.primaryBlue)
                    
                    Text(AppConstants.appName)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.textPrimary)
                    
                    Text("당신에게 맞는 완벽한 차량을 찾아보세요")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
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
                VStack(spacing: 8) {
                    Text("AutoFinder v\(AppConstants.version)")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    
                    Text("AI 기반 개인화 차량 추천 서비스")
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
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
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case username
        case password
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // 로그인 타이틀
            Text("로그인")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.textPrimary)
            
            VStack(spacing: 16) {
                // 아이디 입력
                VStack(alignment: .leading, spacing: 4) {
                    Text("아이디")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.textPrimary)
                    
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.secondaryGray)
                            .frame(width: 20)
                        
                        TextField("아이디를 입력하세요", text: $username)
                            .textFieldStyle(PlainTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .textContentType(.username)
                            .focused($focusedField, equals: .username)
                            .submitLabel(.next)
                            .onSubmit {
                                focusedField = .password
                            }
                    }
                    .padding()
                    .background(Color.backgroundColor)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                focusedField == .username ?
                                Color.primaryBlue :
                                Color.secondaryGray.opacity(0.3),
                                lineWidth: focusedField == .username ? 2 : 1
                            )
                    )
                }
                
                // 비밀번호 입력
                VStack(alignment: .leading, spacing: 4) {
                    Text("비밀번호")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.textPrimary)
                    
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.secondaryGray)
                            .frame(width: 20)
                        
                        Group {
                            if isPasswordVisible {
                                TextField("비밀번호를 입력하세요", text: $password)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            } else {
                                SecureField("비밀번호를 입력하세요", text: $password)
                                    .textFieldStyle(PlainTextFieldStyle())
                            }
                        }
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.done)
                        .onSubmit {
                            performLogin()
                        }
                        
                        Button(action: {
                            isPasswordVisible.toggle()
                        }) {
                            Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(.secondaryGray)
                        }
                    }
                    .padding()
                    .background(Color.backgroundColor)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                focusedField == .password ?
                                Color.primaryBlue :
                                Color.secondaryGray.opacity(0.3),
                                lineWidth: focusedField == .password ? 2 : 1
                            )
                    )
                }
                
                // 로그인 유지 옵션
                HStack {
                    Button(action: {
                        rememberMe.toggle()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: rememberMe ? "checkmark.square.fill" : "square")
                                .foregroundColor(rememberMe ? Color.primaryBlue : Color.secondaryGray)
                            
                            Text("로그인 상태 유지")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }
                    }
                    
                    Spacer()
                }
            }
            
            // 로그인 버튼
            Button("로그인") {
                performLogin()
            }
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                (username.isEmpty || password.isEmpty || authManager.isLoading) ?
                Color.secondaryGray :
                Color.primaryBlue
            )
            .cornerRadius(12)
            .disabled(username.isEmpty || password.isEmpty || authManager.isLoading)
            .animation(.easeInOut(duration: 0.2), value: username.isEmpty || password.isEmpty)
            
            // 로딩 인디케이터
            if authManager.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.primaryBlue))
            }
            
            // 회원가입 링크
            HStack {
                Text("계정이 없으신가요?")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                
                Button("회원가입") {
                    withAnimation(.easeInOut) {
                        isShowingRegister = true
                    }
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primaryBlue)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cardBackground)
                .shadow(
                    color: Color.black.opacity(0.1),
                    radius: 8,
                    x: 0,
                    y: 2
                )
        )
        .onAppear {
            // 화면이 나타날 때 첫 번째 필드에 포커스
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedField = .username
            }
        }
        .onTapGesture {
            // 빈 공간 탭 시 키보드 숨기기
            focusedField = nil
        }
    }
    
    private func performLogin() {
        // 키보드 숨기기
        focusedField = nil
        
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

// MARK: - 회원가입 폼 뷰 (기존 코드와 동일하되 @FocusState 추가)
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
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case username
        case password
        case confirmPassword
    }
    
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
                    Text("아이디")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color(UIConstants.Colors.textPrimary))
                    
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(Color(UIConstants.Colors.secondaryGray))
                            .frame(width: 20)
                        
                        TextField("아이디를 입력하세요 (3자 이상)", text: $username)
                            .textFieldStyle(PlainTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .textContentType(.username)
                            .focused($focusedField, equals: .username)
                            .submitLabel(.next)
                            .onSubmit {
                                focusedField = .password
                            }
                            .onChange(of: username) { _ in
                                validateUsername()
                            }
                        
                        // 상태 표시
                        if isCheckingUsername {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                        } else if !usernameValidationMessage.isEmpty {
                            Image(systemName: usernameValidationMessage.contains("사용 가능") ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(usernameValidationMessage.contains("사용 가능") ? Color(UIConstants.Colors.successColor) : Color(UIConstants.Colors.accentColor))
                                .font(.title3)
                        }
                    }
                    .padding()
                    .background(Color(UIConstants.Colors.backgroundColor))
                    .cornerRadius(UIConstants.CornerRadius.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium)
                            .stroke(
                                focusedField == .username ?
                                Color(UIConstants.Colors.primaryBlue) :
                                Color(UIConstants.Colors.secondaryGray).opacity(0.3),
                                lineWidth: focusedField == .username ? 2 : 1
                            )
                    )
                    
                    // 검증 메시지
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
                    Text("비밀번호")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color(UIConstants.Colors.textPrimary))
                    
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(Color(UIConstants.Colors.secondaryGray))
                            .frame(width: 20)
                        
                        Group {
                            if isPasswordVisible {
                                TextField("비밀번호 (6자 이상)", text: $password)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            } else {
                                SecureField("비밀번호 (6자 이상)", text: $password)
                                    .textFieldStyle(PlainTextFieldStyle())
                            }
                        }
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .confirmPassword
                        }
                        
                        Button(action: {
                            isPasswordVisible.toggle()
                        }) {
                            Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(Color(UIConstants.Colors.secondaryGray))
                        }
                    }
                    .padding()
                    .background(Color(UIConstants.Colors.backgroundColor))
                    .cornerRadius(UIConstants.CornerRadius.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium)
                            .stroke(
                                focusedField == .password ?
                                Color(UIConstants.Colors.primaryBlue) :
                                Color(UIConstants.Colors.secondaryGray).opacity(0.3),
                                lineWidth: focusedField == .password ? 2 : 1
                            )
                    )
                    
                    if !password.isEmpty {
                        // 기존 PasswordStrengthView 사용 (중복 정의 제거)
                        VStack(alignment: .leading, spacing: UIConstants.Spacing.xs) {
                            HStack {
                                Text("비밀번호 강도:")
                                    .font(.caption)
                                    .foregroundColor(Color(UIConstants.Colors.textSecondary))
                                
                                let strength = calculatePasswordStrength(password)
                                Text(strength.displayName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(strength.color)
                            }
                            
                            // 강도 바
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color(UIConstants.Colors.backgroundColor))
                                        .frame(height: 4)
                                        .cornerRadius(2)
                                    
                                    let strength = calculatePasswordStrength(password)
                                    Rectangle()
                                        .fill(strength.color)
                                        .frame(width: geometry.size.width * strength.ratio, height: 4)
                                        .cornerRadius(2)
                                        .animation(.easeInOut(duration: 0.3), value: strength.ratio)
                                }
                            }
                            .frame(height: 4)
                        }
                    }
                }
                
                // 비밀번호 확인
                VStack(alignment: .leading, spacing: UIConstants.Spacing.xs) {
                    Text("비밀번호 확인")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color(UIConstants.Colors.textPrimary))
                    
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(Color(UIConstants.Colors.secondaryGray))
                            .frame(width: 20)
                        
                        Group {
                            if isConfirmPasswordVisible {
                                TextField("비밀번호 확인", text: $confirmPassword)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            } else {
                                SecureField("비밀번호 확인", text: $confirmPassword)
                                    .textFieldStyle(PlainTextFieldStyle())
                            }
                        }
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .confirmPassword)
                        .submitLabel(.done)
                        .onSubmit {
                            performRegister()
                        }
                        
                        Button(action: {
                            isConfirmPasswordVisible.toggle()
                        }) {
                            Image(systemName: isConfirmPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(Color(UIConstants.Colors.secondaryGray))
                        }
                    }
                    .padding()
                    .background(Color(UIConstants.Colors.backgroundColor))
                    .cornerRadius(UIConstants.CornerRadius.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium)
                            .stroke(
                                focusedField == .confirmPassword ?
                                Color(UIConstants.Colors.primaryBlue) :
                                Color(UIConstants.Colors.secondaryGray).opacity(0.3),
                                lineWidth: focusedField == .confirmPassword ? 2 : 1
                            )
                    )
                    
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
            }
            
            // 회원가입 버튼
            Button("회원가입") {
                performRegister()
            }
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                (!isFormValid || authManager.isLoading) ?
                Color(UIConstants.Colors.secondaryGray) :
                Color(UIConstants.Colors.primaryBlue)
            )
            .cornerRadius(UIConstants.CornerRadius.medium)
            .disabled(!isFormValid || authManager.isLoading)
            .animation(.easeInOut(duration: 0.2), value: isFormValid)
            
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
        .onAppear {
            // 화면이 나타날 때 첫 번째 필드에 포커스
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedField = .username
            }
        }
        .onTapGesture {
            // 빈 공간 탭 시 키보드 숨기기
            focusedField = nil
        }
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
        // 키보드 숨기기
        focusedField = nil
        
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

// MARK: - 비밀번호 강도 계산 헬퍼 (기존 것과 충돌 방지)
extension RegisterFormView {
    private func calculatePasswordStrength(_ password: String) -> PasswordStrengthLevel {
        var score = 0
        
        // 길이 점수
        if password.count >= 6 { score += 1 }
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        
        // 문자 종류 점수
        if password.range(of: "[a-z]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[A-Z]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[0-9]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[^a-zA-Z0-9]", options: .regularExpression) != nil { score += 1 }
        
        switch score {
        case 0...2: return .weak
        case 3...4: return .medium
        case 5...6: return .strong
        default: return .veryStrong
        }
    }
}

// MARK: - 비밀번호 강도 레벨 (기존 것과 충돌 방지)
enum PasswordStrengthLevel: Int {
    case weak = 1
    case medium = 2
    case strong = 3
    case veryStrong = 4
    
    var displayName: String {
        switch self {
        case .weak: return "약함"
        case .medium: return "보통"
        case .strong: return "강함"
        case .veryStrong: return "매우 강함"
        }
    }
    
    var color: Color {
        switch self {
        case .weak: return Color(UIConstants.Colors.accentColor)
        case .medium: return Color(UIConstants.Colors.warningColor)
        case .strong: return Color(UIConstants.Colors.successColor)
        case .veryStrong: return Color(UIConstants.Colors.primaryBlue)
        }
    }
    
    var ratio: Double {
        return Double(self.rawValue) / 4.0
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
        }
    }
}
