import Foundation
import Combine
import Alamofire

// MARK: - RecommendationService
final class RecommendationService: ObservableObject {
    static let shared = RecommendationService()
    
    // MARK: - Published Properties
    @Published var recommendations: [RecommendedCar] = []
    @Published var isLoading = false
    @Published var error: NetworkError?
    @Published var lastUpdateTime: Date?
    @Published var aiStatus: AIServiceStatus = .unknown
    
    // MARK: - Private Properties
    private let networkManager = NetworkManager.shared
    private let authManager = AuthManager.shared
    private let favoriteService = FavoriteService.shared
    private let cacheManager = CacheManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupObservers()
        setupPeriodicStatusCheck()
    }
    
    // MARK: - Public Methods
    func loadRecommendations(count: Int? = nil, forceRefresh: Bool = false) -> AnyPublisher<Void, NetworkError> {
        guard authManager.isAuthenticated else {
            return Fail(error: NetworkError.unauthorized).eraseToAnyPublisher()
        }
        
        let requestCount = min(count ?? RecommendationConstants.defaultCount, RecommendationConstants.maxCount)
        
        if !forceRefresh, let cached = getCachedRecommendations(count: requestCount) {
            updateRecommendationsState(cached)
            return Just(()).setFailureType(to: NetworkError.self).eraseToAnyPublisher()
        }
        
        return performRecommendationRequest(count: requestCount)
    }
    
    func loadPersonalizedRecommendations(count: Int? = nil) -> AnyPublisher<Void, NetworkError> {
        guard !favoriteService.isEmpty else {
            return loadPopularRecommendations(count: count)
        }
        return loadRecommendations(count: count, forceRefresh: true)
    }
    
    func loadPopularRecommendations(count: Int? = nil) -> AnyPublisher<Void, NetworkError> {
        let requestCount = count ?? RecommendationConstants.defaultCount
        
        return CarService.shared.loadPopularCars(limit: requestCount)
            .map { cars in
                cars.map { car in
                    RecommendedCar(
                        car: car,
                        similarityScore: 0.5,
                        recommendationReason: "인기 차량"
                    )
                }
            }
            .receive(on: DispatchQueue.main)
            .handleEvents(
                receiveOutput: { [weak self] recommendedCars in
                    self?.updateRecommendationsFromCars(recommendedCars)
                },
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.handleError(error)
                    }
                }
            )
            .map { _ in () }
            .eraseToAnyPublisher()
    }
    
    func getSimilarCarRecommendations(basedOn car: Car, count: Int = 5) -> AnyPublisher<[RecommendedCar], NetworkError> {
        CarService.shared.getSimilarCars(carId: car.id, limit: count)
            .map { cars in
                cars.map { similarCar in
                    RecommendedCar(
                        car: similarCar,
                        similarityScore: 0.7,
                        recommendationReason: "'\(car.model)'과 유사한 차량"
                    )
                }
            }
            .eraseToAnyPublisher()
    }
    
    func getRecommendationsByPriceRange(min: Int, max: Int, count: Int = 10) -> AnyPublisher<[RecommendedCar], NetworkError> {
        var filters = CarFilterParams()
        filters.minPrice = min
        filters.maxPrice = max
        filters.size = count
        
        return networkManager.getCars(filters: filters)
            .map { response in
                response.content.map { car in
                    RecommendedCar(
                        car: car,
                        similarityScore: 0.6,
                        recommendationReason: "\(min)-\(max)만원 가격대 추천"
                    )
                }
            }
            .eraseToAnyPublisher()
    }
    
    func getRecommendationsByBrand(_ brand: String, count: Int = 10) -> AnyPublisher<[RecommendedCar], NetworkError> {
        var filters = CarFilterParams()
        filters.model = brand
        filters.size = count
        
        return networkManager.getCars(filters: filters)
            .map { response in
                response.content.map { car in
                    RecommendedCar(
                        car: car,
                        similarityScore: 0.6,
                        recommendationReason: "\(brand) 브랜드 추천"
                    )
                }
            }
            .eraseToAnyPublisher()
    }
    
    func getRecommendationDebugInfo() -> AnyPublisher<RecommendationDebugInfo, NetworkError> {
        let publisher: AnyPublisher<RecommendationDebugInfo, NetworkError> = networkManager.requestWithErrorHandling(
            endpoint: APIConstants.Endpoints.aiDebug,
            requiresAuth: true
        )
        return publisher
    }
    
    func checkAIStatus() {
        let publisher: AnyPublisher<AIServiceStatusResponse, NetworkError> = networkManager.requestWithErrorHandling(
            endpoint: APIConstants.Endpoints.aiStatus,
            requiresAuth: false
        )
        
        publisher
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure = completion {
                        self?.aiStatus = .unavailable
                    }
                },
                receiveValue: { [weak self] (response: AIServiceStatusResponse) in
                    self?.aiStatus = response.aiServiceAvailable ? .available : .unavailable
                }
            )
            .store(in: &cancellables)
    }
    
    func clearError() {
        DispatchQueue.main.async {
            self.error = nil
        }
    }
    
    func refresh() -> AnyPublisher<Void, NetworkError> {
        loadRecommendations(forceRefresh: true)
    }
    
    func submitRecommendationFeedback(carId: Int, rating: Int, feedback: String?) {
        UserBehaviorService.shared.trackAction(.feedback, carId: carId, value: "rating_\(rating)")
        if let feedback = feedback, !feedback.isEmpty {
            UserBehaviorService.shared.trackAction(.feedback, carId: carId, value: "text_feedback")
        }
    }
    
    var recommendationQuality: RecommendationQuality {
        guard !recommendations.isEmpty else {
            return RecommendationQuality.empty
        }
        
        let averageScore = recommendations.map(\.similarityScore).reduce(0, +) / Double(recommendations.count)
        let uniqueBrands = Set(recommendations.map(\.car.brandName)).count
        let diversity = Double(uniqueBrands) / Double(recommendations.count)
        let recentCars = recommendations.filter(\.car.isNewCar).count
        let freshness = Double(recentCars) / Double(recommendations.count)
        let personalization = calculatePersonalizationScore()
        let overall = (averageScore * 0.4) + (diversity * 0.2) + (freshness * 0.2) + (personalization * 0.2)
        
        return RecommendationQuality(
            averageScore: averageScore,
            diversity: diversity,
            freshness: freshness,
            personalization: personalization,
            overall: overall
        )
    }
}

// MARK: - Private Methods
private extension RecommendationService {
    func setupObservers() {
        // 즐겨찾기 변경 감지
        NotificationCenter.default.publisher(for: Notification.Name(NotificationNames.favoriteDidUpdate))
            .sink { [weak self] _ in
                self?.invalidateRecommendationCache()
            }
            .store(in: &cancellables)
        
        // 로그인 상태 변경 감지
        authManager.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    self?.checkAIStatus()
                } else {
                    self?.clearRecommendations()
                }
            }
            .store(in: &cancellables)
    }
    
    func setupPeriodicStatusCheck() {
        Timer.publish(every: RecommendationConstants.statusCheckInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                if self?.authManager.isAuthenticated == true {
                    self?.checkAIStatus()
                }
            }
            .store(in: &cancellables)
    }
    
    func getCachedRecommendations(count: Int) -> [RecommendedCar]? {
        let cacheKey = CacheKeys.recommendations(authManager.userId ?? 0, count)
        return cacheManager.get(key: cacheKey)
    }
    
    func performRecommendationRequest(count: Int) -> AnyPublisher<Void, NetworkError> {
        setLoadingState(true)
        
        let publisher: AnyPublisher<AIRecommendationResponse, NetworkError> = networkManager.requestWithErrorHandling(
            endpoint: APIConstants.Endpoints.aiRecommend,
            parameters: ["limit": count],
            encoding: URLEncoding.default,
            requiresAuth: true
        )
        
        return publisher
            .receive(on: DispatchQueue.main)
            .handleEvents(
                receiveOutput: { [weak self] response in
                    self?.handleSuccessfulResponse(response, count: count)
                },
                receiveCompletion: { [weak self] completion in
                    self?.setLoadingState(false)
                    if case .failure(let error) = completion {
                        self?.handleRecommendationError(error, count: count)
                    }
                }
            )
            .map { _ in () }
            .eraseToAnyPublisher()
    }
    
    func handleSuccessfulResponse(_ response: AIRecommendationResponse, count: Int) {
        updateRecommendations(response)
        cacheRecommendations(response.recommendations, count: count)
    }
    
    func handleRecommendationError(_ error: NetworkError, count: Int) {
        self.error = error
        if error == .serverUnavailable || error == .serviceUnavailable {
            loadFallbackRecommendations(count: count)
        }
    }
    
    func loadFallbackRecommendations(count: Int) {
        let filters = favoriteService.recommendationFilters
        setLoadingState(true)
        
        CarService.shared.loadCars(filters: filters)
            .sink(
                receiveCompletion: { [weak self] completion in
                    DispatchQueue.main.async {
                        self?.setLoadingState(false)
                        if case .failure(let error) = completion {
                            self?.error = error
                        }
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.createFallbackRecommendations(count: count)
                }
            )
            .store(in: &cancellables)
    }
    
    func createFallbackRecommendations(count: Int) {
        let cars = Array(CarService.shared.cars.prefix(count))
        let fallbackRecommendations = cars.map { car in
            RecommendedCar(
                car: car,
                similarityScore: 0.4,
                recommendationReason: "선호도 기반 추천"
            )
        }
        
        DispatchQueue.main.async {
            self.recommendations = fallbackRecommendations
            self.lastUpdateTime = Date()
            self.error = nil
        }
    }
    
    func updateRecommendations(_ response: AIRecommendationResponse) {
        recommendations = response.recommendations
        lastUpdateTime = Date()
        UserBehaviorService.shared.trackAction(.view, carId: nil, value: "ai_recommendations_\(response.recommendations.count)")
    }
    
    func updateRecommendationsState(_ recommendations: [RecommendedCar]) {
        DispatchQueue.main.async {
            self.recommendations = recommendations
            self.lastUpdateTime = Date()
            self.isLoading = false
        }
    }
    
    func updateRecommendationsFromCars(_ recommendedCars: [RecommendedCar]) {
        recommendations = recommendedCars
        lastUpdateTime = Date()
        isLoading = false
        error = nil
    }
    
    func cacheRecommendations(_ recommendations: [RecommendedCar], count: Int) {
        let cacheKey = CacheKeys.recommendations(authManager.userId ?? 0, count)
        cacheManager.set(
            key: cacheKey,
            value: recommendations,
            expiration: RecommendationConstants.cacheExpirationTime
        )
    }
    
    func clearRecommendations() {
        DispatchQueue.main.async {
            self.recommendations.removeAll()
            self.lastUpdateTime = nil
            self.aiStatus = .unknown
            self.error = nil
            self.isLoading = false
        }
        invalidateRecommendationCache()
    }
    
    func invalidateRecommendationCache() {
        guard let userId = authManager.userId else { return }
        cacheManager.removeAll(pattern: "recommendations_\(userId)")
    }
    
    func setLoadingState(_ loading: Bool) {
        isLoading = loading
        if loading {
            error = nil
        }
    }
    
    func handleError(_ error: NetworkError) {
        self.error = error
        isLoading = false
    }
    
    func calculatePersonalizationScore() -> Double {
        guard !favoriteService.favoriteCarIds.isEmpty,
              !favoriteService.favoriteCars.isEmpty else {
            return 0
        }
        
        let favoriteBrands = Set(favoriteService.favoriteCars.map(\.brandName))
        guard !favoriteBrands.isEmpty else { return 0 }
        
        let recommendedBrands = Set(recommendations.map(\.car.brandName))
        let intersection = favoriteBrands.intersection(recommendedBrands)
        
        return Double(intersection.count) / Double(favoriteBrands.count)
    }
}

// MARK: - Preference Management Extensions
extension RecommendationService {
    func getPreferences() -> RecommendationPreferences {
        // UserDefaults나 다른 저장소에서 설정 로드
        return RecommendationPreferences() // 기본값 반환
    }
    
    func updatePreferences(_ preferences: RecommendationPreferences) {
        // UserDefaults나 다른 저장소에 설정 저장
        // 설정 변경 후 추천 새로고침
        refresh()
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
    }
    
    func resetUserData() {
        // 사용자 추천 데이터 초기화
        clearRecommendations()
        invalidateRecommendationCache()
    }
    
    func retrainModel() {
        let publisher: AnyPublisher<EmptyResponse, NetworkError> = networkManager.requestWithErrorHandling(
            endpoint: APIConstants.Endpoints.aiRetrain,
            method: .post,
            requiresAuth: true
        )
        
        publisher
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { (_: EmptyResponse) in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.refresh()
                            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
                            .store(in: &self.cancellables)
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func getDebugInfo() -> AnyPublisher<[String: Any], NetworkError> {
        getRecommendationDebugInfo()
            .map { debugInfo in
                // RecommendationDebugInfo를 Dictionary로 변환
                [
                    "userPreferences": debugInfo.userPreferences ?? [:],
                    "modelVersion": debugInfo.modelVersion ?? "unknown",
                    "lastTrainingDate": debugInfo.lastTrainingDate?.description ?? "unknown",
                    "recommendationCount": debugInfo.recommendationCount ?? 0,
                    "averageScore": debugInfo.averageScore ?? 0.0,
                    "processingTime": debugInfo.processingTime ?? 0.0
                ]
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - Cache Keys
private enum CacheKeys {
    static func recommendations(_ userId: Int, _ count: Int) -> String {
        "recommendations_\(userId)_\(count)"
    }
}

// MARK: - Constants
private enum RecommendationConstants {
    static let defaultCount = 10
    static let maxCount = 20
    static let cacheExpirationTime: TimeInterval = 300 // 5분
    static let statusCheckInterval: TimeInterval = 300 // 5분
}

// MARK: - Supporting Models
struct RecommendationPreferences: Codable {
    var similarityThreshold: Double = 0.7
    var enableBrandDiversity: Bool = true
    var enablePriceDiversity: Bool = true
    var prioritizeNewCars: Bool = false
    var enableNewRecommendationNotification: Bool = true
    var enablePriceChangeNotification: Bool = false
}

extension RecommendationQuality {
    static let empty = RecommendationQuality(
        averageScore: 0,
        diversity: 0,
        freshness: 0,
        personalization: 0,
        overall: 0
    )
}

// MARK: - Empty Response Model
struct EmptyResponse: Codable {
    // 빈 응답을 위한 구조체
}
