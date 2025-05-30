import Foundation
import Combine
import KeychainAccess
import Alamofire

// MARK: - 인증 관리자 (싱글톤)
class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    // MARK: - Published Properties
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User?
    @Published var isLoading: Bool = false
    @Published var authError: NetworkError?
    
    // MARK: - Private Properties
    private let keychain: Keychain
    private let networkManager = NetworkManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Token Properties
    var accessToken: String? {
        get {
            return try? keychain.get(KeychainConstants.accessTokenKey)
        }
        set {
            if let token = newValue {
                try? keychain.set(token, key: KeychainConstants.accessTokenKey)
            } else {
                try? keychain.remove(KeychainConstants.accessTokenKey)
            }
        }
    }
    
    var userId: Int? {
        get {
            if let userIdString = try? keychain.get(KeychainConstants.userIdKey) {
                return Int(userIdString)
            }
            return nil
        }
        set {
            if let id = newValue {
                try? keychain.set("\(id)", key: KeychainConstants.userIdKey)
            } else {
                try? keychain.remove(KeychainConstants.userIdKey)
            }
        }
    }
    
    var username: String? {
        get {
            return try? keychain.get(KeychainConstants.usernameKey)
        }
        set {
            if let name = newValue {
                try? keychain.set(name, key: KeychainConstants.usernameKey)
            } else {
                try? keychain.remove(KeychainConstants.usernameKey)
            }
        }
    }
    
    // MARK: - Initialization
    private init() {
        self.keychain = Keychain(service: KeychainConstants.service)
        
        // 저장된 토큰으로 자동 로그인 시도
        checkAuthenticationStatus()
    }
    
    // MARK: - Authentication Status Check
    private func checkAuthenticationStatus() {
        guard let token = accessToken, !token.isEmpty else {
            DispatchQueue.main.async {
                self.isAuthenticated = false
                self.currentUser = nil
            }
            return
        }
        
        // 토큰 유효성 검증을 위해 현재 사용자 정보 요청
        validateToken()
    }
    
    private func validateToken() {
        isLoading = true
        
        networkManager.getCurrentUser()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    
                    if case .failure(let error) = completion {
                        switch error {
                        case .unauthorized, .tokenExpired:
                            // 토큰이 만료되었거나 유효하지 않음
                            self?.logout()
                        default:
                            // 네트워크 오류 등은 기존 인증 상태 유지
                            self?.authError = error
                        }
                    }
                },
                receiveValue: { [weak self] user in
                    self?.currentUser = user
                    self?.isAuthenticated = true
                    self?.authError = nil
                    
                    // 사용자 정보 업데이트
                    self?.userId = user.id
                    self?.username = user.username
                    
                    // 로그인 성공 알림
                    NotificationCenter.default.post(
                        name: Notification.Name(NotificationNames.userDidLogin),
                        object: user
                    )
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Login
    func login(username: String, password: String, rememberMe: Bool = false) -> AnyPublisher<Void, NetworkError> {
        guard !username.isEmpty && !password.isEmpty else {
            return Fail(error: NetworkError.invalidCredentials)
                .eraseToAnyPublisher()
        }
        
        isLoading = true
        authError = nil
        
        return networkManager.login(username: username, password: password, rememberMe: rememberMe)
            .flatMap { [weak self] loginResponse -> AnyPublisher<User, NetworkError> in
                // 토큰 저장
                self?.accessToken = loginResponse.token
                self?.userId = loginResponse.userId
                
                // 사용자 정보 조회
                return self?.networkManager.getCurrentUser() ??
                    Fail(error: NetworkError.unknown).eraseToAnyPublisher()
            }
            .receive(on: DispatchQueue.main)
            .handleEvents(
                receiveOutput: { [weak self] user in
                    self?.currentUser = user
                    self?.isAuthenticated = true
                    self?.username = user.username
                    self?.isLoading = false
                    self?.authError = nil
                    
                    // 로그인 성공 알림
                    NotificationCenter.default.post(
                        name: Notification.Name(NotificationNames.userDidLogin),
                        object: user
                    )
                },
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    
                    if case .failure(let error) = completion {
                        self?.authError = error
                        // 실패 시 저장된 토큰 제거
                        self?.clearAuthData()
                    }
                }
            )
            .map { _ in () }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Register
    func register(username: String, password: String) -> AnyPublisher<User, NetworkError> {
        guard !username.isEmpty && !password.isEmpty else {
            return Fail(error: NetworkError.invalidData)
                .eraseToAnyPublisher()
        }
        
        guard password.count >= 6 else {
            return Fail(error: NetworkError.custom("비밀번호는 6자 이상이어야 합니다"))
                .eraseToAnyPublisher()
        }
        
        isLoading = true
        authError = nil
        
        return networkManager.register(username: username, password: password)
            .receive(on: DispatchQueue.main)
            .handleEvents(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    
                    if case .failure(let error) = completion {
                        self?.authError = error
                    }
                }
            )
            .eraseToAnyPublisher()
    }
    
    // MARK: - Logout
    func logout() {
        // 서버에 로그아웃 요청 (토큰 무효화)
        networkManager.request(
            endpoint: APIConstants.Endpoints.logout,
            method: .post,
            requiresAuth: true
        )
        .sink(
            receiveCompletion: { _ in },
            receiveValue: { (_: String) in }
        )
        .store(in: &cancellables)
        
        // 로컬 데이터 삭제
        performLogout()
    }
    
    private func performLogout() {
        DispatchQueue.main.async {
            // 인증 상태 업데이트
            self.isAuthenticated = false
            self.currentUser = nil
            self.authError = nil
            
            // 저장된 인증 데이터 삭제
            self.clearAuthData()
            
            // 로그아웃 알림
            NotificationCenter.default.post(
                name: Notification.Name(NotificationNames.userDidLogout),
                object: nil
            )
        }
    }
    
    private func clearAuthData() {
        accessToken = nil
        userId = nil
        username = nil
        
        // 추가 사용자 데이터 삭제 (캐시, 설정 등)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.userPreferences)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.searchHistory)
    }
    
    // MARK: - Token Refresh (향후 구현)
    private func refreshToken() -> AnyPublisher<Void, NetworkError> {
        // 현재 백엔드에서 리프레시 토큰을 지원하지 않으므로
        // 향후 필요시 구현
        return Fail(error: NetworkError.tokenExpired)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Username Validation
    func checkUsernameAvailability(username: String) -> AnyPublisher<Bool, NetworkError> {
        guard !username.isEmpty else {
            return Fail(error: NetworkError.invalidData)
                .eraseToAnyPublisher()
        }
        
        return networkManager.request(
            endpoint: APIConstants.Endpoints.checkUsername,
            method: .get,
            parameters: ["username": username],
            encoding: URLEncoding.queryString,
            requiresAuth: false
        )
        .map { (response: String) in
            return response.contains("사용 가능")
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Validation Helpers
    func validateUsername(_ username: String) -> String? {
        guard !username.isEmpty else {
            return "아이디를 입력해주세요"
        }
        
        guard username.count >= 3 else {
            return "아이디는 3자 이상이어야 합니다"
        }
        
        guard username.count <= 20 else {
            return "아이디는 20자 이하여야 합니다"
        }
        
        // 영문, 숫자, 언더스코어만 허용
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        guard username.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
            return "아이디는 영문, 숫자, 언더스코어만 사용 가능합니다"
        }
        
        return nil
    }
    
    func validatePassword(_ password: String) -> String? {
        guard !password.isEmpty else {
            return "비밀번호를 입력해주세요"
        }
        
        guard password.count >= 6 else {
            return "비밀번호는 6자 이상이어야 합니다"
        }
        
        guard password.count <= 50 else {
            return "비밀번호는 50자 이하여야 합니다"
        }
        
        return nil
    }
    
    func validatePasswordConfirmation(_ password: String, _ confirmation: String) -> String? {
        guard password == confirmation else {
            return "비밀번호가 일치하지 않습니다"
        }
        return nil
    }
    
    // MARK: - Auto-login Check
    func hasValidSession() -> Bool {
        return accessToken != nil && !accessToken!.isEmpty && isAuthenticated
    }
    
    // MARK: - Force Logout (토큰 만료 등의 경우)
    func forceLogout(reason: String = "세션이 만료되었습니다") {
        DispatchQueue.main.async {
            self.authError = NetworkError.custom(reason)
            self.performLogout()
        }
    }
    
    // MARK: - Reset Error
    func clearError() {
        authError = nil
    }
}

// MARK: - AuthManager Extensions
extension AuthManager {
    
    // MARK: - User Info Helpers
    var isLoggedIn: Bool {
        return isAuthenticated && currentUser != nil
    }
    
    var userDisplayName: String {
        return currentUser?.displayName ?? username ?? "사용자"
    }
    
    var isAdmin: Bool {
        return currentUser?.isAdmin ?? false
    }
    
    // MARK: - Session Management
    func refreshUserData() {
        guard isAuthenticated else { return }
        
        validateToken()
    }
    
    // MARK: - Keychain Management
    func clearAllKeychainData() {
        try? keychain.removeAll()
    }
    
    // MARK: - Debug Helpers
    #if DEBUG
    func debugAuthState() {
        print("=== Auth Debug Info ===")
        print("Authenticated: \(isAuthenticated)")
        print("Has Token: \(accessToken != nil)")
        print("Current User: \(currentUser?.username ?? "None")")
        print("User ID: \(userId ?? -1)")
        print("Auth Error: \(authError?.localizedDescription ?? "None")")
        print("======================")
    }
    #endif
}

// MARK: - Notification Extension
extension Notification.Name {
    static let userDidLogin = Notification.Name(NotificationNames.userDidLogin)
    static let userDidLogout = Notification.Name(NotificationNames.userDidLogout)
}

// MARK: - AuthManager State enum
extension AuthManager {
    enum AuthState {
        case unauthenticated
        case authenticating
        case authenticated(User)
        case error(NetworkError)
        
        var isLoading: Bool {
            switch self {
            case .authenticating:
                return true
            default:
                return false
            }
        }
        
        var user: User? {
            switch self {
            case .authenticated(let user):
                return user
            default:
                return nil
            }
        }
        
        var error: NetworkError? {
            switch self {
            case .error(let error):
                return error
            default:
                return nil
            }
        }
    }
    
    var authState: AuthState {
        if isLoading {
            return .authenticating
        } else if let error = authError {
            return .error(error)
        } else if isAuthenticated, let user = currentUser {
            return .authenticated(user)
        } else {
            return .unauthenticated
        }
    }
}
