import Foundation
import Combine
import Alamofire
import UIKit

// MARK: - 사용자 행동 추적 서비스
class UserBehaviorService: ObservableObject {
    static let shared = UserBehaviorService()
    
    // MARK: - Published Properties
    @Published var isTrackingEnabled: Bool = true
    @Published var behaviorData: UserBehaviorAnalysis?
    @Published var isLoading: Bool = false
    
    // MARK: - Private Properties
    private let networkManager = NetworkManager.shared
    private let authManager = AuthManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // 로컬 행동 큐 (오프라인 지원)
    private var behaviorQueue: [TrackingRequest] = []
    private let maxQueueSize = 100
    private let batchSize = 10
    
    // 현재 세션 정보
    private let sessionId = UUID().uuidString
    private var sessionStartTime: Date = Date()
    
    // 타이머 (배치 전송용)
    private var batchTimer: Timer?
    private let batchInterval: TimeInterval = 30.0 // 30초마다 배치 전송
    
    private init() {
        loadTrackingSettings()
        setupBatchTimer()
        
        // 앱 상태 변화 감지
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.flushBehaviorQueue()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in
                self?.flushBehaviorQueue()
            }
            .store(in: &cancellables)
    }
    
    deinit {
        batchTimer?.invalidate()
        flushBehaviorQueue()
    }
    
    // MARK: - Tracking Methods
    
    /// 사용자 행동 추적
    func trackAction(_ actionType: UserBehavior.ActionType, carId: Int?, value: String? = nil) {
        guard isTrackingEnabled && authManager.isAuthenticated else { return }
        guard let carId = carId else {
            // carId가 없는 행동도 추적 (검색, 필터 등)
            trackGeneralAction(actionType, value: value)
            return
        }
        
        let trackingRequest = TrackingRequest(
            carId: carId,
            actionType: actionType,
            value: value
        )
        
        // 로컬 큐에 추가
        addToQueue(trackingRequest)
        
        // 고가치 행동은 즉시 전송
        if actionType.weight >= 4.0 {
            sendImmediately(trackingRequest)
        }
    }
    
    /// 일반적인 행동 추적 (차량 ID가 없는 경우)
    private func trackGeneralAction(_ actionType: UserBehavior.ActionType, value: String?) {
        // 임시 carId 사용 (0 또는 -1)
        let trackingRequest = TrackingRequest(
            carId: -1,
            actionType: actionType,
            value: value
        )
        
        addToQueue(trackingRequest)
    }
    
    /// 페이지 방문 추적
    func trackPageView(_ pageName: String, carId: Int? = nil) {
        trackAction(.view, carId: carId, value: pageName)
    }
    
    /// 검색 행동 추적
    func trackSearch(query: String, resultCount: Int) {
        trackAction(.search, carId: nil, value: "query:\(query)|results:\(resultCount)")
    }
    
    /// 필터 사용 추적
    func trackFilter(filterType: String, filterValue: String) {
        trackAction(.filter, carId: nil, value: "\(filterType):\(filterValue)")
    }
    
    /// 세션 시작 추적
    func trackSessionStart() {
        sessionStartTime = Date()
        trackAction(.view, carId: nil, value: "session_start")
    }
    
    /// 세션 종료 추적
    func trackSessionEnd() {
        let sessionDuration = Date().timeIntervalSince(sessionStartTime)
        trackAction(.view, carId: nil, value: "session_end|duration:\(Int(sessionDuration))")
        flushBehaviorQueue()
    }
    
    // MARK: - Queue Management
    
    private func addToQueue(_ request: TrackingRequest) {
        behaviorQueue.append(request)
        
        // 큐 크기 제한
        if behaviorQueue.count > maxQueueSize {
            behaviorQueue.removeFirst(behaviorQueue.count - maxQueueSize)
        }
        
        // 배치 크기에 도달하면 즉시 전송
        if behaviorQueue.count >= batchSize {
            sendBatch()
        }
    }
    
    private func setupBatchTimer() {
        batchTimer = Timer.scheduledTimer(withTimeInterval: batchInterval, repeats: true) { [weak self] _ in
            self?.sendBatch()
        }
    }
    
    private func sendBatch() {
        guard !behaviorQueue.isEmpty && authManager.isAuthenticated else { return }
        
        let batch = Array(behaviorQueue.prefix(batchSize))
        behaviorQueue.removeFirst(min(batchSize, behaviorQueue.count))
        
        sendBatchToServer(batch)
    }
    
    private func flushBehaviorQueue() {
        guard !behaviorQueue.isEmpty else { return }
        
        let allBehaviors = behaviorQueue
        behaviorQueue.removeAll()
        
        sendBatchToServer(allBehaviors)
    }
    
    // MARK: - Network Operations
    
    private func sendImmediately(_ request: TrackingRequest) {
        guard FeatureFlags.behaviorTrackingEnabled else { return }
        
        networkManager.request(
            endpoint: APIConstants.Endpoints.behaviorTrack,
            method: .post,
            parameters: try? request.asDictionary(),
            encoding: JSONEncoding.default,
            requiresAuth: true
        )
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("즉시 행동 추적 실패: \(error.localizedDescription)")
                }
            },
            receiveValue: { (response: String) in
                print("즉시 행동 추적 성공")
            }
        )
        .store(in: &cancellables)
    }
    
    private func sendBatchToServer(_ batch: [TrackingRequest]) {
        guard !batch.isEmpty else { return }
        
        let batchRequest = ["actions": batch.compactMap { try? $0.asDictionary() }]
        
        networkManager.request(
            endpoint: APIConstants.Endpoints.behaviorBatch,
            method: .post,
            parameters: batchRequest,
            encoding: JSONEncoding.default,
            requiresAuth: true
        )
        .sink(
            receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    print("배치 행동 추적 실패: \(error.localizedDescription)")
                    self?.behaviorQueue.append(contentsOf: batch)
                }
            },
            receiveValue: { (response: String) in
                print("배치 행동 추적 성공: \(batch.count)개 액션")
            }
        )
        .store(in: &cancellables)
    }
    
    // MARK: - Analytics & Insights
    
    /// 사용자 행동 분석 데이터 조회
    func loadBehaviorAnalysis() -> AnyPublisher<UserBehaviorAnalysis, NetworkError> {
        isLoading = true
        
        return networkManager.request(
            endpoint: APIConstants.Endpoints.behaviorMe,
            requiresAuth: true
        )
    }
    
    /// 행동 패턴 분석
    func analyzeBehaviorPatterns() -> BehaviorPatternAnalysis? {
        guard let data = behaviorData else { return nil }
        
        return BehaviorPatternAnalysis(
            mostActiveHour: findMostActiveHour(from: data),
            preferredActions: getPreferredActions(from: data),
            engagementLevel: calculateEngagementLevel(from: data),
            consistencyScore: calculateConsistencyScore(from: data),
            recommendations: generateBehaviorRecommendations(from: data)
        )
    }
    
    private func findMostActiveHour(from data: UserBehaviorAnalysis) -> Int {
        guard let hourlyActivity = data.hourlyActivity else { return 12 }
        
        return hourlyActivity.max(by: { $0.value < $1.value })?.key ?? 12
    }
    
    private func getPreferredActions(from data: UserBehaviorAnalysis) -> [String: Int] {
        return data.actionCounts?.mapValues { Int($0) } ?? [:]
    }
    
    private func calculateEngagementLevel(from data: UserBehaviorAnalysis) -> EngagementLevel {
        let score = data.engagementScore ?? 0.0
        
        switch score {
        case 8.0...: return .high
        case 5.0..<8.0: return .medium
        case 2.0..<5.0: return .low
        default: return .minimal
        }
    }
    
    private func calculateConsistencyScore(from data: UserBehaviorAnalysis) -> Double {
        guard let activeDays = data.activeDays, activeDays > 0 else { return 0.0 }
        
        let totalActions = data.totalActions ?? 0
        let avgActionsPerDay = Double(totalActions) / Double(activeDays)
        
        // 일관성 점수 계산 (하루 평균 액션 수 기반)
        return min(avgActionsPerDay / 10.0, 1.0)
    }
    
    private func generateBehaviorRecommendations(from data: UserBehaviorAnalysis) -> [String] {
        var recommendations: [String] = []
        
        let engagementLevel = calculateEngagementLevel(from: data)
        let diversityScore = data.diversityScore ?? 0.0
        
        switch engagementLevel {
        case .minimal:
            recommendations.append("더 많은 차량을 둘러보세요")
            recommendations.append("즐겨찾기 기능을 활용해보세요")
        case .low:
            recommendations.append("관심 있는 차량의 상세 정보를 확인해보세요")
        case .medium:
            recommendations.append("AI 추천 기능을 활용해보세요")
        case .high:
            recommendations.append("다른 사용자들과 경험을 공유해보세요")
        }
        
        if diversityScore < 0.3 {
            recommendations.append("다양한 브랜드의 차량도 살펴보세요")
        }
        
        return recommendations
    }
    
    // MARK: - Settings Management
    
    private func loadTrackingSettings() {
        if let preferences = UserDefaults.standard.data(forKey: UserDefaultsKeys.userPreferences),
           let userPrefs = try? JSONDecoder().decode(UserPreferences.self, from: preferences) {
            isTrackingEnabled = userPrefs.enableBehaviorTracking
        }
    }
    
    func updateTrackingSettings(enabled: Bool) {
        isTrackingEnabled = enabled
        
        // UserPreferences 업데이트
        var preferences = UserPreferences()
        if let data = UserDefaults.standard.data(forKey: UserDefaultsKeys.userPreferences),
           let existing = try? JSONDecoder().decode(UserPreferences.self, from: data) {
            preferences = existing
        }
        
        preferences.enableBehaviorTracking = enabled
        
        if let encoded = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(encoded, forKey: UserDefaultsKeys.userPreferences)
        }
        
        if !enabled {
            // 추적 비활성화 시 큐 비우기
            behaviorQueue.removeAll()
        }
    }
    
    // MARK: - Helper Methods
    
    /// 특정 차량에 대한 관심도 점수 계산
    func getInterestScore(for carId: Int) -> Double {
        guard let data = behaviorData,
              let carScores = data.carInterestScores else { return 0.0 }
        
        return carScores[String(carId)] ?? 0.0
    }
    
    /// 사용자의 선호 브랜드 분석
    func getPreferredBrands() -> [String] {
        guard let data = behaviorData,
              let carScores = data.carInterestScores else { return [] }
        
        // 관심도가 높은 차량들의 브랜드 추출
        return carScores.compactMap { (carIdString, score) -> String? in
            guard score > 3.0,
                  let carId = Int(carIdString),
                  let car = CarService.shared.findCar(by: carId) else { return nil }
            return car.brandName
        }
    }
    
    /// 행동 통계 요약
    var behaviorSummary: BehaviorSummary? {
        guard let data = behaviorData else { return nil }
        
        return BehaviorSummary(
            totalActions: data.totalActions ?? 0,
            activeDays: data.activeDays ?? 0,
            averageSessionDuration: data.avgSessionDuration ?? 0.0,
            engagementScore: data.engagementScore ?? 0.0,
            diversityScore: data.diversityScore ?? 0.0,
            topActions: getTopActions(from: data),
            mostViewedCars: getMostViewedCars(from: data)
        )
    }
    
    private func getTopActions(from data: UserBehaviorAnalysis) -> [String] {
        guard let actionCounts = data.actionCounts else { return [] }
        
        return actionCounts.sorted { $0.value > $1.value }
            .prefix(3)
            .map { UserBehavior.ActionType(rawValue: $0.key)?.displayName ?? $0.key }
    }
    
    private func getMostViewedCars(from data: UserBehaviorAnalysis) -> [Int] {
        guard let carScores = data.carInterestScores else { return [] }
        
        return carScores.sorted { $0.value > $1.value }
            .prefix(5)
            .compactMap { Int($0.key) }
    }
}

// MARK: - Supporting Models

struct UserBehaviorAnalysis: Codable {
    let userId: Int?
    let behaviorData: BehaviorData?
    let message: String?
    
    // Computed properties for easier access
    var actionCounts: [String: Int]? {
        return behaviorData?.action_counts
    }
    
    var carInterestScores: [String: Double]? {
        return behaviorData?.car_interest_scores
    }
    
    var hourlyActivity: [Int: Int]? {
        return behaviorData?.hourly_activity
    }
    
    var recentActivity: [String: Int]? {
        return behaviorData?.recent_activity
    }
    
    var engagementScore: Double? {
        return behaviorData?.engagement_score
    }
    
    var diversityScore: Double? {
        return behaviorData?.diversity_score
    }
    
    var totalActions: Int? {
        return behaviorData?.total_actions
    }
    
    var activeDays: Int? {
        return behaviorData?.active_days
    }
    
    var avgSessionDuration: Double? {
        return behaviorData?.avg_session_duration
    }
}

struct BehaviorData: Codable {
    let action_counts: [String: Int]?
    let car_interest_scores: [String: Double]?
    let hourly_activity: [Int: Int]?
    let recent_activity: [String: Int]?
    let engagement_score: Double?
    let diversity_score: Double?
    let total_actions: Int?
    let active_days: Int?
    let avg_session_duration: Double?
}

struct BatchTrackingRequest: Codable {
    let behaviors: [TrackingRequest]
}

struct BehaviorPatternAnalysis {
    let mostActiveHour: Int
    let preferredActions: [String: Int]
    let engagementLevel: EngagementLevel
    let consistencyScore: Double
    let recommendations: [String]
    
    var mostActiveTimeDescription: String {
        if mostActiveHour < 6 {
            return "새벽 시간대 (\(mostActiveHour)시)"
        } else if mostActiveHour < 12 {
            return "오전 시간대 (\(mostActiveHour)시)"
        } else if mostActiveHour < 18 {
            return "오후 시간대 (\(mostActiveHour)시)"
        } else {
            return "저녁 시간대 (\(mostActiveHour)시)"
        }
    }
}

enum EngagementLevel: String, CaseIterable {
    case minimal = "minimal"
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .minimal: return "최소"
        case .low: return "낮음"
        case .medium: return "보통"
        case .high: return "높음"
        }
    }
    
    var color: String {
        switch self {
        case .minimal: return "red"
        case .low: return "orange"
        case .medium: return "yellow"
        case .high: return "green"
        }
    }
}

struct BehaviorSummary {
    let totalActions: Int
    let activeDays: Int
    let averageSessionDuration: Double
    let engagementScore: Double
    let diversityScore: Double
    let topActions: [String]
    let mostViewedCars: [Int]
    
    var formattedSessionDuration: String {
        let minutes = Int(averageSessionDuration)
        if minutes < 60 {
            return "\(minutes)분"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)시간 \(remainingMinutes)분"
        }
    }
    
    var actionsPerDay: Double {
        guard activeDays > 0 else { return 0 }
        return Double(totalActions) / Double(activeDays)
    }
}
