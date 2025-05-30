import SwiftUI
import Combine

// MARK: - 회원가입 뷰
struct RegisterView: View {
    @StateObject private var authManager = AuthManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    // 입력 필드
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var agreeToTerms = false
    @State private var agreeToPrivacy = false
    @State private var agreeToMarketing = false
    
    // UI 상태
    @State private var isPasswordVisible = false
    @State private var isConfirmPasswordVisible = false
    @State private var showingTerms = false
    @State private var showingPrivacy = false
    @State private var isCheckingUsername = false
    @State private var usernameCheckResult: UsernameCheckResult?
    @State private var cancellables = Set<AnyCancellable>()
    
    // 실시간 검증 결과
    private var usernameValidation: String? {
        return authManager.validateUsername(username)
    }
    
    private var passwordValidation: String? {
        return authManager.validatePassword(password)
    }
    
    private var confirmPasswordValidation: String? {
        return authManager.validatePasswordConfirmation(password, confirmPassword)
    }
    
    private var isFormValid: Bool {
        return usernameValidation == nil &&
               passwordValidation == nil &&
               confirmPasswordValidation == nil &&
               !username.isEmpty &&
               !password.isEmpty &&
               !confirmPassword.isEmpty &&
               agreeToTerms &&
               agreeToPrivacy &&
               usernameCheckResult?.isAvailable == true
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: UIConstants.Spacing.lg) {
                    // 헤더
                    RegisterHeaderView()
                    
                    // 입력 폼
                    VStack(spacing: UIConstants.Spacing.md) {
                        // 아이디 입력
                        UsernameInputView(
                            username: $username,
                            isChecking: isCheckingUsername,
                            checkResult: usernameCheckResult,
                            validation: usernameValidation,
                            onUsernameChange: checkUsernameAvailability
                        )
                        
                        // 비밀번호 입력
                        PasswordInputView(
                            password: $password,
                            isVisible: $isPasswordVisible,
                            validation: passwordValidation,
                            placeholder: "비밀번호 (6자 이상)"
                        )
                        
                        // 비밀번호 확인 입력
                        PasswordInputView(
                            password: $confirmPassword,
                            isVisible: $isConfirmPasswordVisible,
                            validation: confirmPasswordValidation,
                            placeholder: "비밀번호 확인"
                        )
                    }
                    
                    // 약관 동의
                    TermsAgreementView(
                        agreeToTerms: $agreeToTerms,
                        agreeToPrivacy: $agreeToPrivacy,
                        agreeToMarketing: $agreeToMarketing,
                        showingTerms: $showingTerms,
                        showingPrivacy: $showingPrivacy
                    )
                    
                    // 회원가입 버튼
                    RegisterButtonView(
                        isEnabled: isFormValid,
                        isLoading: authManager.isLoading,
                        onRegister: performRegister
                    )
                    
                    // 에러 메시지
                    if let error = authManager.authError {
                        ErrorMessageView(error: error)
                    }
                    
                    // 로그인으로 이동
                    LoginRedirectView()
                }
                .padding()
            }
            .navigationTitle("회원가입")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingTerms) {
            TermsOfServiceView()
        }
        .sheet(isPresented: $showingPrivacy) {
            PrivacyPolicyView()
        }
        .onTapGesture {
            hideKeyboard()
        }
        .onReceive(authManager.$authError) { error in
            if error == nil && authManager.isAuthenticated {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    private func checkUsernameAvailability() {
        guard !username.isEmpty && usernameValidation == nil else {
            usernameCheckResult = nil
            return
        }
        
        isCheckingUsername = true
        usernameCheckResult = nil
        
        authManager.checkUsernameAvailability(username: username)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isCheckingUsername = false
                    if case .failure(let error) = completion {
                        usernameCheckResult = .error(error.localizedDescription)
                    }
                },
                receiveValue: { isAvailable in
                    usernameCheckResult = isAvailable ? .available : .unavailable
                }
            )
            .store(in: &cancellables)
    }
    
    private func performRegister() {
        hideKeyboard()
        
        authManager.register(username: username, password: password)
            .sink(
                receiveCompletion: { completion in
                    // .success 대신 .finished 사용
                    if case .finished = completion {
                        // 회원가입 성공 후 자동 로그인
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            performAutoLogin()
                        }
                    }
                },
                receiveValue: { _ in
                    // 회원가입 성공
                }
            )
            .store(in: &cancellables)
    }
    
    private func performAutoLogin() {
        authManager.login(username: username, password: password)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - 회원가입 헤더
struct RegisterHeaderView: View {
    var body: some View {
        VStack(spacing: UIConstants.Spacing.md) {
            // 앱 로고
            Image(systemName: "car.fill")
                .font(.system(size: 60))
                .foregroundColor(Color(UIConstants.Colors.primaryBlue))
            
            VStack(spacing: UIConstants.Spacing.xs) {
                Text("AutoFinder 회원가입")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(Color(UIConstants.Colors.textPrimary))
                
                Text("나만의 차량 추천을 받아보세요")
                    .font(.subheadline)
                    .foregroundColor(Color(UIConstants.Colors.textSecondary))
            }
        }
        .padding(.top, UIConstants.Spacing.lg)
    }
}

// MARK: - 아이디 입력 뷰
struct UsernameInputView: View {
    @Binding var username: String
    let isChecking: Bool
    let checkResult: UsernameCheckResult?
    let validation: String?
    let onUsernameChange: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.xs) {
            Text("아이디")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Color(UIConstants.Colors.textPrimary))
            
            HStack {
                TextField("아이디를 입력하세요", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onChange(of: username) { _ in
                        // 디바운스를 위한 딜레이
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            onUsernameChange()
                        }
                    }
                
                // 상태 표시
                if isChecking {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                } else if let result = checkResult {
                    Image(systemName: result.iconName)
                        .foregroundColor(result.color)
                        .font(.title3)
                }
            }
            
            // 검증 메시지
            if let validation = validation {
                Text(validation)
                    .font(.caption)
                    .foregroundColor(Color(UIConstants.Colors.accentColor))
            } else if let result = checkResult {
                Text(result.message)
                    .font(.caption)
                    .foregroundColor(result.color)
            }
        }
    }
}

// MARK: - 비밀번호 입력 뷰
struct PasswordInputView: View {
    @Binding var password: String
    @Binding var isVisible: Bool
    let validation: String?
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.xs) {
            Text(placeholder.contains("확인") ? "비밀번호 확인" : "비밀번호")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Color(UIConstants.Colors.textPrimary))
            
            HStack {
                if isVisible {
                    TextField(placeholder, text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                } else {
                    SecureField(placeholder, text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Button(action: {
                    isVisible.toggle()
                }) {
                    Image(systemName: isVisible ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(Color(UIConstants.Colors.secondaryGray))
                }
            }
            
            // 검증 메시지
            if let validation = validation {
                Text(validation)
                    .font(.caption)
                    .foregroundColor(Color(UIConstants.Colors.accentColor))
            }
            
            // 비밀번호 강도 표시 (첫 번째 비밀번호만)
            if !placeholder.contains("확인") && !password.isEmpty {
                PasswordStrengthView(password: password)
            }
        }
    }
}

// MARK: - 비밀번호 강도 표시
struct PasswordStrengthView: View {
    let password: String
    
    private var strength: PasswordStrength {
        return calculatePasswordStrength(password)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.xs) {
            HStack {
                Text("비밀번호 강도:")
                    .font(.caption)
                    .foregroundColor(Color(UIConstants.Colors.textSecondary))
                
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
    
    private func calculatePasswordStrength(_ password: String) -> PasswordStrength {
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

// MARK: - 약관 동의 뷰
struct TermsAgreementView: View {
    @Binding var agreeToTerms: Bool
    @Binding var agreeToPrivacy: Bool
    @Binding var agreeToMarketing: Bool
    @Binding var showingTerms: Bool
    @Binding var showingPrivacy: Bool
    
    private var allAgreed: Bool {
        return agreeToTerms && agreeToPrivacy
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.sm) {
            Text("약관 동의")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Color(UIConstants.Colors.textPrimary))
            
            VStack(spacing: UIConstants.Spacing.sm) {
                // 전체 동의
                HStack {
                    Button(action: {
                        let newValue = !allAgreed
                        agreeToTerms = newValue
                        agreeToPrivacy = newValue
                        agreeToMarketing = newValue
                    }) {
                        HStack {
                            Image(systemName: allAgreed ? "checkmark.square.fill" : "square")
                                .foregroundColor(allAgreed ? Color(UIConstants.Colors.primaryBlue) : Color(UIConstants.Colors.secondaryGray))
                                .font(.title3)
                            
                            Text("전체 동의")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(Color(UIConstants.Colors.textPrimary))
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color(UIConstants.Colors.backgroundColor))
                .cornerRadius(UIConstants.CornerRadius.medium)
                
                // 개별 약관
                VStack(spacing: UIConstants.Spacing.xs) {
                    AgreementItemView(
                        isAgreed: $agreeToTerms,
                        title: "이용약관 동의 (필수)",
                        isRequired: true,
                        onDetailTap: { showingTerms = true }
                    )
                    
                    AgreementItemView(
                        isAgreed: $agreeToPrivacy,
                        title: "개인정보 처리방침 동의 (필수)",
                        isRequired: true,
                        onDetailTap: { showingPrivacy = true }
                    )
                    
                    AgreementItemView(
                        isAgreed: $agreeToMarketing,
                        title: "마케팅 정보 수신 동의 (선택)",
                        isRequired: false,
                        onDetailTap: nil
                    )
                }
            }
        }
    }
}

// MARK: - 약관 항목 뷰
struct AgreementItemView: View {
    @Binding var isAgreed: Bool
    let title: String
    let isRequired: Bool
    let onDetailTap: (() -> Void)?
    
    var body: some View {
        HStack {
            Button(action: {
                isAgreed.toggle()
            }) {
                HStack {
                    Image(systemName: isAgreed ? "checkmark.square.fill" : "square")
                        .foregroundColor(isAgreed ? Color(UIConstants.Colors.primaryBlue) : Color(UIConstants.Colors.secondaryGray))
                    
                    Text(title)
                        .font(.caption)
                        .foregroundColor(Color(UIConstants.Colors.textPrimary))
                        .multilineTextAlignment(.leading)
                }
            }
            
            Spacer()
            
            if let onDetailTap = onDetailTap {
                Button("보기") {
                    onDetailTap()
                }
                .font(.caption)
                .foregroundColor(Color(UIConstants.Colors.primaryBlue))
            }
        }
        .padding(.horizontal, UIConstants.Spacing.sm)
    }
}

// MARK: - 회원가입 버튼
struct RegisterButtonView: View {
    let isEnabled: Bool
    let isLoading: Bool
    let onRegister: () -> Void
    
    var body: some View {
        Button(action: onRegister) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                    
                    Text("회원가입 중...")
                        .fontWeight(.semibold)
                } else {
                    Text("회원가입")
                        .fontWeight(.semibold)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                isEnabled ?
                Color(UIConstants.Colors.primaryBlue) :
                Color(UIConstants.Colors.secondaryGray)
            )
            .cornerRadius(UIConstants.CornerRadius.medium)
        }
        .disabled(!isEnabled || isLoading)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }
}

// MARK: - 에러 메시지 뷰
struct ErrorMessageView: View {
    let error: NetworkError
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Color(UIConstants.Colors.accentColor))
            
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(Color(UIConstants.Colors.accentColor))
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding()
        .background(Color(UIConstants.Colors.accentColor).opacity(0.1))
        .cornerRadius(UIConstants.CornerRadius.small)
    }
}

// MARK: - 로그인 리다이렉트 뷰
struct LoginRedirectView: View {
    var body: some View {
        HStack {
            Text("이미 계정이 있으신가요?")
                .font(.subheadline)
                .foregroundColor(Color(UIConstants.Colors.textSecondary))
            
            Button("로그인") {
                // 로그인 화면으로 이동 (부모 뷰에서 처리)
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(Color(UIConstants.Colors.primaryBlue))
        }
        .padding(.top, UIConstants.Spacing.lg)
    }
}

// MARK: - 이용약관 뷰
struct TermsOfServiceView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: UIConstants.Spacing.md) {
                    Text(termsOfServiceText)
                        .font(.body)
                        .foregroundColor(Color(UIConstants.Colors.textPrimary))
                        .lineLimit(nil)
                }
                .padding()
            }
            .navigationTitle("이용약관")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private var termsOfServiceText: String {
        return """
        AutoFinder 이용약관
        
        제1조 (목적)
        이 약관은 AutoFinder(이하 "회사")가 제공하는 차량 검색 및 추천 서비스(이하 "서비스")의 이용과 관련하여 회사와 이용자 간의 권리, 의무 및 책임사항을 규정함을 목적으로 합니다.
        
        제2조 (정의)
        1. "서비스"라 함은 회사가 제공하는 차량 검색, 추천, 즐겨찾기 등의 모든 서비스를 의미합니다.
        2. "이용자"라 함은 본 약관에 따라 회사가 제공하는 서비스를 받는 회원 및 비회원을 의미합니다.
        3. "회원"이라 함은 회사에 개인정보를 제공하여 회원등록을 한 자로서, 회사의 서비스를 지속적으로 이용할 수 있는 자를 의미합니다.
        
        제3조 (약관의 효력 및 변경)
        1. 본 약관은 서비스를 이용하고자 하는 모든 이용자에 대하여 그 효력을 발생합니다.
        2. 회사는 필요하다고 인정되는 경우 본 약관을 변경할 수 있으며, 변경된 약관은 서비스 내 공지사항을 통해 공지합니다.
        
        제4조 (서비스의 제공 및 변경)
        1. 회사는 다음과 같은 서비스를 제공합니다:
           - 차량 검색 및 필터링 서비스
           - AI 기반 개인화 추천 서비스
           - 즐겨찾기 및 비교 서비스
           - 차량 관련 정보 제공 서비스
        2. 회사는 서비스의 내용을 변경할 수 있으며, 이 경우 변경 사유와 내용을 명시하여 사전에 공지합니다.
        
        제5조 (서비스 이용시간)
        1. 서비스 이용은 연중무휴, 1일 24시간 원칙으로 합니다.
        2. 단, 정기점검 등의 필요에 의해 회사가 정한 날이나 시간은 예외로 합니다.
        
        제6조 (회원가입)
        1. 이용자는 회사가 정한 가입 양식에 따라 회원정보를 기입한 후 본 약관에 동의한다는 의사표시를 함으로써 회원가입을 신청합니다.
        2. 회사는 제1항과 같이 회원으로 가입할 것을 신청한 이용자 중 다음 각 호에 해당하지 않는 한 회원으로 등록합니다:
           - 가입신청자가 본 약관에 의하여 이전에 회원자격을 상실한 적이 있는 경우
           - 등록 내용에 허위, 기재누락, 오기가 있는 경우
           - 기타 회원으로 등록하는 것이 회사의 기술상 현저히 지장이 있다고 판단되는 경우
        
        제7조 (개인정보보호)
        회사는 관련법령이 정하는 바에 따라 이용자의 개인정보를 보호하기 위해 노력합니다. 개인정보의 보호 및 사용에 대해서는 관련법령 및 회사의 개인정보처리방침이 적용됩니다.
        
        제8조 (회원의 의무)
        1. 이용자는 다음 행위를 하여서는 안 됩니다:
           - 신청 또는 변경시 허위내용의 등록
           - 타인의 정보 도용
           - 회사가 게시한 정보의 변경
           - 회사가 정한 정보 이외의 정보(컴퓨터 프로그램 등) 등의 송신 또는 게시
           - 회사 기타 제3자의 저작권 등 지적재산권에 대한 침해
           - 회사 기타 제3자의 명예를 손상시키거나 업무를 방해하는 행위
           - 외설 또는 폭력적인 메시지, 화상, 음성, 기타 공서양속에 반하는 정보를 회사에 공개 또는 게시하는 행위
        
        제9조 (저작권의 귀속 및 이용제한)
        1. 회사가 작성한 저작물에 대한 저작권 기타 지적재산권은 회사에 귀속합니다.
        2. 이용자는 회사를 이용함으로써 얻은 정보 중 회사에게 지적재산권이 귀속된 정보를 회사의 사전 승낙 없이 복제, 송신, 출판, 배포, 방송 기타 방법에 의하여 영리목적으로 이용하거나 제3자에게 이용하게 하여서는 안됩니다.
        
        제10조 (손해배상)
        회사는 무료로 제공되는 서비스와 관련하여 관련법에 특별한 규정이 없는 한 책임을 지지 않습니다.
        
        제11조 (면책조항)
        1. 회사는 천재지변 또는 이에 준하는 불가항력으로 인하여 서비스를 제공할 수 없는 경우에는 서비스 제공에 관한 책임이 면제됩니다.
        2. 회사는 이용자의 귀책사유로 인한 서비스 이용의 장애에 대하여는 책임을 지지 않습니다.
        3. 회사는 이용자가 서비스를 이용하여 기대하는 수익을 상실한 것에 대하여 책임을 지지 않으며, 그 밖의 서비스를 통하여 얻은 자료로 인한 손해에 관하여 책임을 지지 않습니다.
        
        제12조 (재판권 및 준거법)
        1. 회사와 이용자 간에 발생한 분쟁에 관한 소송은 대한민국 법원에 제기합니다.
        2. 회사와 이용자 간에 제기된 소송에는 대한민국법을 적용합니다.
        
        부칙
        본 약관은 2024년 1월 1일부터 시행됩니다.
        """
    }
}

// MARK: - 개인정보처리방침 뷰
struct PrivacyPolicyView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: UIConstants.Spacing.md) {
                    Text(privacyPolicyText)
                        .font(.body)
                        .foregroundColor(Color(UIConstants.Colors.textPrimary))
                        .lineLimit(nil)
                }
                .padding()
            }
            .navigationTitle("개인정보처리방침")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private var privacyPolicyText: String {
        return """
        AutoFinder 개인정보처리방침
        
        AutoFinder(이하 "회사")는 정보통신망 이용촉진 및 정보보호 등에 관한 법률, 개인정보보호법 등 관련 법령상의 개인정보보호 규정을 준수하며, 관련 법령에 의거한 개인정보처리방침을 정하여 이용자 권익 보호에 최선을 다하고 있습니다.
        
        1. 개인정보의 처리목적
        회사는 다음의 목적을 위하여 개인정보를 처리합니다:
        - 회원 가입 및 관리
        - 서비스 제공에 관한 계약 이행 및 서비스 제공에 따른 요금정산
        - 개인 맞춤서비스 제공
        - 마케팅 및 광고에의 활용
        - 서비스 개선을 위한 통계분석
        
        2. 개인정보의 처리 및 보유기간
        회사는 법령에 따른 개인정보 보유·이용기간 또는 정보주체로부터 개인정보를 수집시에 동의받은 개인정보 보유·이용기간 내에서 개인정보를 처리·보유합니다.
        
        3. 개인정보의 제3자 제공
        회사는 원칙적으로 이용자의 개인정보를 외부에 제공하지 않습니다. 다만, 아래의 경우에는 예외로 합니다:
        - 이용자들이 사전에 동의한 경우
        - 법령의 규정에 의거하거나, 수사 목적으로 법령에 정해진 절차와 방법에 따라 수사기관의 요구가 있는 경우
        
        4. 개인정보처리의 위탁
        회사는 원활한 개인정보 업무처리를 위하여 다음과 같이 개인정보 처리업무를 위탁하고 있습니다:
        - 위탁받는 자(수탁자): Amazon Web Services
        - 위탁하는 업무의 내용: 데이터 보관 및 관리
        
        5. 정보주체의 권리·의무 및 행사방법
        이용자는 개인정보주체로서 다음과 같은 권리를 행사할 수 있습니다:
        - 개인정보 처리정지 요구권
        - 개인정보 열람요구권
        - 개인정보 정정·삭제요구권
        - 개인정보 처리정지 요구권
        
        6. 처리하는 개인정보 항목
        회사는 다음의 개인정보 항목을 처리하고 있습니다:
        - 필수항목: 아이디, 비밀번호
        - 선택항목: 마케팅 수신동의 여부
        - 자동수집항목: IP주소, 쿠키, MAC주소, 서비스 이용기록, 방문기록, 불량 이용기록 등
        
        7. 개인정보의 파기
        회사는 원칙적으로 개인정보 처리목적이 달성된 경우에는 지체없이 해당 개인정보를 파기합니다.
        
        8. 개인정보 보호책임자
        회사는 개인정보 처리에 관한 업무를 총괄해서 책임지고, 개인정보 처리와 관련한 정보주체의 불만처리 및 피해구제 등을 위하여 아래와 같이 개인정보 보호책임자를 지정하고 있습니다:
        - 개인정보 보호책임자: AutoFinder 팀
        - 연락처: contact@autofinder.com
        
        9. 개인정보 처리방침 변경
        이 개인정보처리방침은 시행일로부터 적용되며, 법령 및 방침에 따른 변경내용의 추가, 삭제 및 정정이 있는 경우에는 변경사항의 시행 7일 전부터 공지사항을 통하여 고지할 것입니다.
        
        시행일자: 2024년 1월 1일
        """
    }
}

// MARK: - 지원 모델들
enum UsernameCheckResult {
    case available
    case unavailable
    case error(String)
    
    var isAvailable: Bool {
        switch self {
        case .available: return true
        default: return false
        }
    }
    
    var message: String {
        switch self {
        case .available: return "사용 가능한 아이디입니다"
        case .unavailable: return "이미 사용 중인 아이디입니다"
        case .error(let message): return message
        }
    }
    
    var color: Color {
        switch self {
        case .available: return Color(UIConstants.Colors.successColor)
        case .unavailable: return Color(UIConstants.Colors.accentColor)
        case .error: return Color(UIConstants.Colors.accentColor)
        }
    }
    
    var iconName: String {
        switch self {
        case .available: return "checkmark.circle.fill"
        case .unavailable: return "xmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}

enum PasswordStrength: Int {
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
struct RegisterView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            RegisterView()
                .preferredColorScheme(.light)
                .previewDisplayName("Register View - Light")
            
            RegisterView()
                .preferredColorScheme(.dark)
                .previewDisplayName("Register View - Dark")
            
            TermsOfServiceView()
                .previewDisplayName("Terms of Service")
            
            PrivacyPolicyView()
                .previewDisplayName("Privacy Policy")
        }
    }
}
