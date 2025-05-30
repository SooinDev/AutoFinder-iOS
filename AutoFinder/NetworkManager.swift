import Foundation
import Alamofire
import Combine

// MARK: - 네트워크 매니저 (싱글톤)
class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    
    // MARK: - Properties
    private let session: Session
    private var cancellables = Set<AnyCancellable>()
    
    // 네트워크 상태 모니터링
    @Published var isConnected: Bool = true
    @Published var isLoading: Bool = false
    
    // 인증 토큰
    private var authToken: String? {
        get {
            return AuthManager.shared.accessToken
        }
    }
    
    // MARK: - Initialization
    private init() {
        // Alamofire 세션 설정
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        
        // 네트워크 로깅 (디버그 모드에서만)
        let eventMonitor = DebugConstants.enableNetworkLogging ?
            NetworkEventLogger() : nil
        
        self.session = Session(
            configuration: configuration,
            eventMonitors: eventMonitor != nil ? [eventMonitor!] : []
        )
        
        // 네트워크 연결 상태 모니터링
        setupNetworkMonitoring()
    }
    
    // MARK: - Network Monitoring
    private func setupNetworkMonitoring() {
        let monitor = NetworkReachabilityManager()
        monitor?.startListening { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .reachable:
                    self?.isConnected = true
                case .notReachable:
                    self?.isConnected = false
                case .unknown:
                    self?.isConnected = false
                }
            }
        }
    }
    
    // MARK: - Generic Request Method
    func request<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        encoding: ParameterEncoding = URLEncoding.default,
        headers: HTTPHeaders? = nil,
        requiresAuth: Bool = true
    ) -> AnyPublisher<T, NetworkError> {
        
        // 네트워크 연결 확인
        guard isConnected else {
            return Fail(error: NetworkError.noInternetConnection)
                .eraseToAnyPublisher()
        }
        
        // URL 생성
        let url = APIConstants.baseURL + endpoint
        
        // 헤더 설정
        var requestHeaders = headers ?? HTTPHeaders()
        
        // 인증 토큰 추가
        if requiresAuth, let token = authToken {
            requestHeaders.add(.authorization(bearerToken: token))
        }
        
        // Content-Type 설정
        if method != .get {
            requestHeaders.add(.contentType("application/json"))
        }
        
        // 로딩 상태 업데이트
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        return session.request(
            url,
            method: method,
            parameters: parameters,
            encoding: encoding,
            headers: requestHeaders
        )
        .validate()
        .publishDecodable(type: T.self)
        .value()
        .mapError { error -> NetworkError in
            DispatchQueue.main.async {
                self.isLoading = false
            }
            
            // Alamofire 에러를 NetworkError로 변환
            if let afError = error as? AFError {
                switch afError {
                case .responseValidationFailed(let reason):
                    if case .unacceptableStatusCode(let code) = reason {
                        return NetworkError.from(httpStatusCode: code)
                    }
                    return .invalidResponse
                case .sessionTaskFailed(let sessionError):
                    return NetworkError.from(alamofireError: sessionError)
                default:
                    return .unknown
                }
            }
            
            return NetworkError.from(alamofireError: error)
        }
        .handleEvents(receiveCompletion: { _ in
            DispatchQueue.main.async {
                self.isLoading = false
            }
        })
        .eraseToAnyPublisher()
    }
    
    // MARK: - Request with Custom Error Handling
    func requestWithErrorHandling<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        encoding: ParameterEncoding = URLEncoding.default,
        headers: HTTPHeaders? = nil,
        requiresAuth: Bool = true
    ) -> AnyPublisher<T, NetworkError> {
        
        return session.request(
            APIConstants.baseURL + endpoint,
            method: method,
            parameters: parameters,
            encoding: encoding,
            headers: buildHeaders(custom: headers, requiresAuth: requiresAuth)
        )
        .validate(statusCode: 200..<300)
        .publishData()
        .tryMap { dataResponse -> T in
            // HTTP 응답 코드 확인
            if let httpResponse = dataResponse.response,
               !(200..<300).contains(httpResponse.statusCode) {
                
                // 에러 응답 파싱 시도
                if let data = dataResponse.data,
                   let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    let apiError = APIError(
                        error: errorResponse.error,
                        message: errorResponse.message,
                        details: errorResponse.details,
                        code: errorResponse.code,
                        timestamp: errorResponse.timestamp
                    )
                    throw apiError.toNetworkError()
                }
                
                throw NetworkError.from(httpStatusCode: httpResponse.statusCode)
            }
            
            // 성공 응답 파싱
            guard let data = dataResponse.data else {
                throw NetworkError.invalidResponse
            }
            
            do {
                let decoder = JSONDecoder()
                return try decoder.decode(T.self, from: data)
            } catch {
                // JSON 파싱 실패
                print("JSON Parsing Error: \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Response data: \(jsonString)")
                }
                throw NetworkError.parsingFailed
            }
        }
        .mapError { error -> NetworkError in
            if let networkError = error as? NetworkError {
                return networkError
            }
            return NetworkError.from(alamofireError: error)
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Helper Methods
    private func buildHeaders(custom: HTTPHeaders?, requiresAuth: Bool) -> HTTPHeaders {
        var headers = custom ?? HTTPHeaders()
        
        if requiresAuth, let token = authToken {
            headers.add(.authorization(bearerToken: token))
        }
        
        headers.add(.contentType("application/json"))
        headers.add(.accept("application/json"))
        
        return headers
    }
    
    // MARK: - Upload Method
    func upload<T: Codable>(
        endpoint: String,
        data: Data,
        fileName: String,
        mimeType: String = "image/jpeg",
        parameters: Parameters? = nil
    ) -> AnyPublisher<T, NetworkError> {
        
        return session.upload(
            multipartFormData: { multipartFormData in
                multipartFormData.append(
                    data,
                    withName: "file",
                    fileName: fileName,
                    mimeType: mimeType
                )
                
                if let parameters = parameters {
                    for (key, value) in parameters {
                        if let data = "\(value)".data(using: .utf8) {
                            multipartFormData.append(data, withName: key)
                        }
                    }
                }
            },
            to: APIConstants.baseURL + endpoint,
            headers: buildHeaders(custom: nil, requiresAuth: true)
        )
        .validate()
        .publishDecodable(type: T.self)
        .value()
        .mapError { error -> NetworkError in
            return NetworkError.from(alamofireError: error)
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Retry Logic
    func requestWithRetry<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        encoding: ParameterEncoding = URLEncoding.default,
        headers: HTTPHeaders? = nil,
        requiresAuth: Bool = true,
        maxRetries: Int = 3,
        retryDelay: TimeInterval = 1.0
    ) -> AnyPublisher<T, NetworkError> {
        
        return requestWithErrorHandling(
            endpoint: endpoint,
            method: method,
            parameters: parameters,
            encoding: encoding,
            headers: headers,
            requiresAuth: requiresAuth
        )
        .retry(maxRetries)
        .catch { error -> AnyPublisher<T, NetworkError> in
            // 재시도 가능한 에러인 경우 딜레이 후 재시도
            if error.isRetryable && maxRetries > 0 {
                return Just(())
                    .delay(for: .seconds(retryDelay), scheduler: DispatchQueue.global())
                    .flatMap { _ in
                        self.requestWithRetry(
                            endpoint: endpoint,
                            method: method,
                            parameters: parameters,
                            encoding: encoding,
                            headers: headers,
                            requiresAuth: requiresAuth,
                            maxRetries: maxRetries - 1,
                            retryDelay: retryDelay * 2 // 지수 백오프
                        )
                    }
                    .eraseToAnyPublisher()
            } else {
                return Fail(error: error)
                    .eraseToAnyPublisher()
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - URL Query Items
    func buildURL(endpoint: String, queryItems: [URLQueryItem]) -> String {
        var components = URLComponents(string: APIConstants.baseURL + endpoint)
        components?.queryItems = queryItems
        return components?.url?.absoluteString ?? (APIConstants.baseURL + endpoint)
    }
}

// MARK: - Request Logging
private class NetworkEventLogger: EventMonitor {
    func requestDidResume(_ request: Request) {
        if DebugConstants.enableNetworkLogging {
            print("🌐 Request Started: \(request.description)")
        }
    }
    
    func request<Value>(_ request: DataRequest, didParseResponse response: DataResponse<Value, AFError>) {
        if DebugConstants.enableNetworkLogging {
            print("🌐 Response: \(response.debugDescription)")
        }
    }
}

// MARK: - NetworkManager Extensions for Specific Endpoints
extension NetworkManager {
    
    // MARK: - Authentication
    func login(username: String, password: String, rememberMe: Bool = false) -> AnyPublisher<LoginResponse, NetworkError> {
        let request = LoginRequest(username: username, password: password, rememberMe: rememberMe)
        
        return requestWithErrorHandling(
            endpoint: APIConstants.Endpoints.login,
            method: .post,
            parameters: try? request.asDictionary(),
            encoding: JSONEncoding.default,
            requiresAuth: false
        )
    }
    
    func register(username: String, password: String) -> AnyPublisher<User, NetworkError> {
        let request = RegisterRequest(username: username, password: password)
        
        return requestWithErrorHandling(
            endpoint: APIConstants.Endpoints.register,
            method: .post,
            parameters: try? request.asDictionary(),
            encoding: JSONEncoding.default,
            requiresAuth: false
        )
    }
    
    func getCurrentUser() -> AnyPublisher<User, NetworkError> {
        return requestWithErrorHandling(
            endpoint: APIConstants.Endpoints.me,
            method: .get,
            requiresAuth: true
        )
    }
    
    // MARK: - Cars
    func getCars(filters: CarFilterParams) -> AnyPublisher<PaginatedResponse<Car>, NetworkError> {
        let url = buildURL(endpoint: APIConstants.Endpoints.cars, queryItems: filters.queryItems)
        
        return session.request(url)
            .validate()
            .publishDecodable(type: PaginatedResponse<Car>.self)
            .value()
            .mapError { NetworkError.from(alamofireError: $0) }
            .eraseToAnyPublisher()
    }
    
    func getCarDetail(carId: Int) -> AnyPublisher<Car, NetworkError> {
        let endpoint = String(format: APIConstants.Endpoints.carDetail, carId)
        return requestWithErrorHandling(endpoint: endpoint, requiresAuth: false)
    }
    
    // MARK: - Favorites
    func addFavorite(carId: Int, userId: Int) -> AnyPublisher<String, NetworkError> {
        let endpoint = String(format: APIConstants.Endpoints.addFavorite, carId)
        let parameters = ["userId": userId]
        
        return requestWithErrorHandling(
            endpoint: endpoint,
            method: .post,
            parameters: parameters,
            encoding: URLEncoding.queryString
        )
    }
    
    func removeFavorite(carId: Int, userId: Int) -> AnyPublisher<String, NetworkError> {
        let endpoint = String(format: APIConstants.Endpoints.removeFavorite, carId)
        let parameters = ["userId": userId]
        
        return requestWithErrorHandling(
            endpoint: endpoint,
            method: .delete,
            parameters: parameters,
            encoding: URLEncoding.queryString
        )
    }
    
    func getUserFavorites(userId: Int) -> AnyPublisher<[Car], NetworkError> {
        let parameters = ["userId": userId]
        
        return requestWithErrorHandling(
            endpoint: APIConstants.Endpoints.favorites,
            parameters: parameters,
            encoding: URLEncoding.queryString
        )
    }
}

// MARK: - Codable Extension for Parameters
extension Encodable {
    func asDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        guard let dictionary = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
            throw NSError()
        }
        return dictionary
    }
}
