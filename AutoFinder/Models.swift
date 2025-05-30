import Foundation

// MARK: - 기본 응답 타입
struct APIResponse<T: Codable>: Codable {
    let data: T?
    let message: String?
    let success: Bool?
}

struct PaginatedResponse<T: Codable>: Codable {
    let content: [T]
    let totalElements: Int
    let totalPages: Int
    let last: Bool
    let first: Bool
    let size: Int
    let number: Int
}

// MARK: - 사용자 모델
struct User: Codable, Identifiable {
    let id: Int
    let username: String
    let role: String
    
    var displayName: String { username }
    var isAdmin: Bool { role.lowercased() == "admin" }
}

struct LoginRequest: Codable {
    let username: String
    let password: String
    let rememberMe: Bool
}

struct LoginResponse: Codable {
    let token: String
    let userId: Int
    let message: String?
}

struct RegisterRequest: Codable {
    let username: String
    let password: String
    let role: String = "USER"
}

// MARK: - 차량 모델
struct Car: Codable, Identifiable, Hashable {
    let id: Int
    let carType: String?
    let model: String
    let year: String
    let mileage: Int?
    let price: Int
    let fuel: String
    let region: String
    let url: String?
    let imageUrl: String?
    let createdAt: String?
    
    var displayPrice: String {
        price == 9999 ? "가격 문의" : "\(price)만원"
    }
    
    var formattedPrice: String {
        if price == 9999 { return "가격 문의" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return "\(formatter.string(from: NSNumber(value: price)) ?? "\(price)")만원"
    }
    
    var displayMileage: String {
        guard let mileage = mileage, mileage > 0 else { return "정보 없음" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return "\(formatter.string(from: NSNumber(value: mileage)) ?? "\(mileage)")km"
    }
    
    var displayYear: String {
        let cleanYear = year.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        if cleanYear.count >= 2 {
            let firstTwo = String(cleanYear.prefix(2))
            if let yearInt = Int(firstTwo) {
                let fullYear = yearInt > 50 ? 1900 + yearInt : 2000 + yearInt
                return "\(fullYear)년식"
            }
        }
        return year
    }
    
    var brandName: String {
        let brands = ["현대", "기아", "제네시스", "르노", "쉐보레", "쌍용", "BMW", "벤츠", "아우디", "볼보"]
        for brand in brands {
            if model.contains(brand) { return brand }
        }
        return model.components(separatedBy: " ").first ?? "기타"
    }
    
    var modelName: String {
        let components = model.components(separatedBy: " ")
        return components.count > 1 ? components.dropFirst().joined(separator: " ") : model
    }
    
    var isNewCar: Bool {
        guard let createdAt = createdAt,
              let date = ISO8601DateFormatter().date(from: createdAt) else { return false }
        return Date().timeIntervalSince(date) < 7 * 24 * 60 * 60
    }
    
    var priceCategory: String {
        switch price {
        case 0..<1000: return "1천만원 이하"
        case 1000..<2000: return "1천~2천만원"
        case 2000..<3000: return "2천~3천만원"
        case 3000..<5000: return "3천~5천만원"
        case 5000...: return "5천만원 이상"
        default: return "가격 문의"
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Car, rhs: Car) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 차량 필터 파라미터
struct CarFilterParams: Codable, Hashable {
    var model: String?
    var minPrice: Int?
    var maxPrice: Int?
    var minMileage: Int?
    var maxMileage: Int?
    var fuel: String?
    var region: String?
    var year: String?
    var page: Int = 0
    var size: Int = 20
    
    var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []
        
        if let model = model, !model.isEmpty {
            items.append(URLQueryItem(name: "model", value: model))
        }
        if let minPrice = minPrice {
            items.append(URLQueryItem(name: "minPrice", value: "\(minPrice)"))
        }
        if let maxPrice = maxPrice {
            items.append(URLQueryItem(name: "maxPrice", value: "\(maxPrice)"))
        }
        if let minMileage = minMileage {
            items.append(URLQueryItem(name: "minMileage", value: "\(minMileage)"))
        }
        if let maxMileage = maxMileage {
            items.append(URLQueryItem(name: "maxMileage", value: "\(maxMileage)"))
        }
        if let fuel = fuel, !fuel.isEmpty {
            items.append(URLQueryItem(name: "fuel", value: fuel))
        }
        if let region = region, !region.isEmpty {
            items.append(URLQueryItem(name: "region", value: region))
        }
        if let year = year, !year.isEmpty {
            items.append(URLQueryItem(name: "year", value: year))
        }
        
        items.append(URLQueryItem(name: "page", value: "\(page)"))
        items.append(URLQueryItem(name: "size", value: "\(size)"))
        
        return items
    }
    
    var hasActiveFilters: Bool {
        return model != nil || minPrice != nil || maxPrice != nil ||
               minMileage != nil || maxMileage != nil || fuel != nil ||
               region != nil || year != nil
    }
    
    mutating func reset() {
        model = nil
        minPrice = nil
        maxPrice = nil
        minMileage = nil
        maxMileage = nil
        fuel = nil
        region = nil
        year = nil
        page = 0
    }
}

// MARK: - AI 추천 모델
struct RecommendedCar: Codable, Identifiable {
    let car: Car
    let similarityScore: Double
    let recommendationReason: String
    
    var id: Int { car.id }
}

struct AIRecommendationResponse: Codable {
    let recommendations: [RecommendedCar]
    let total: Int
    let strategy: String?
    let message: String?
}

// MARK: - 가격 분석 모델
struct PriceAnalysis: Codable {
    let year: String
    let minPrice: Int
    let avgPrice: Int
    let maxPrice: Int
    let count: Int
    
    var formattedAvgPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return "\(formatter.string(from: NSNumber(value: avgPrice)) ?? "\(avgPrice)")만원"
    }
}

// MARK: - 사용자 행동 모델
struct UserBehavior: Codable {
    let userId: Int
    let carId: Int
    let actionType: String
    let value: String?
    let timestamp: String?
    
    enum ActionType: String, CaseIterable {
        case view = "VIEW"
        case click = "CLICK"
        case detailView = "DETAIL_VIEW"
        case search = "SEARCH"
        case filter = "FILTER"
        case favorite = "FAVORITE"
        case share = "SHARE"
        case contact = "CONTACT"
        case compare = "COMPARE"
        case feedback = "FEEDBACK"
        
        var displayName: String {
            switch self {
            case .view: return "조회"
            case .click: return "클릭"
            case .detailView: return "상세보기"
            case .search: return "검색"
            case .filter: return "필터"
            case .favorite: return "즐겨찾기"
            case .share: return "공유"
            case .contact: return "연락"
            case .compare: return "비교"
            case .feedback: return "피드백"
            }
        }
        
        var weight: Double {
            switch self {
            case .view: return 1.0
            case .click: return 1.5
            case .detailView: return 2.0
            case .search: return 1.2
            case .filter: return 1.3
            case .favorite: return 5.0
            case .share: return 2.5
            case .contact: return 6.0
            case .compare: return 2.5
            case .feedback: return 3.0
            }
        }
    }
}

struct TrackingRequest: Codable {
    let userId: Int?
    let carId: Int
    let actionType: String
    let value: String?
    let sessionId: String?
    
    init(carId: Int, actionType: UserBehavior.ActionType, value: String? = nil) {
        self.userId = nil
        self.carId = carId
        self.actionType = actionType.rawValue
        self.value = value
        self.sessionId = UUID().uuidString
    }
}

// MARK: - 검색 기록
struct SearchHistory: Codable, Identifiable {
    let id = UUID()
    let query: String
    let timestamp: Date
    let resultCount: Int
}

// MARK: - 사용자 설정
struct UserPreferences: Codable {
    var enablePushNotifications: Bool = true
    var enableBehaviorTracking: Bool = true
    var preferredRegions: [String] = []
    var favoriteFilters: CarFilterParams = CarFilterParams()
    var themeMode: ThemeMode = .system
    
    enum ThemeMode: String, Codable, CaseIterable {
        case light = "light"
        case dark = "dark"
        case system = "system"
        
        var displayName: String {
            switch self {
            case .light: return "라이트 모드"
            case .dark: return "다크 모드"
            case .system: return "시스템 설정"
            }
        }
    }
}

// MARK: - 에러 모델
struct ErrorResponse: Codable {
    let error: String?
    let message: String?
    let details: String?
    let code: String?
}

enum AIServiceStatus: String, Codable, CaseIterable {
    case unknown = "UNKNOWN"
    case available = "AVAILABLE"
    case unavailable = "UNAVAILABLE"
    case maintenance = "MAINTENANCE"
}

// AI 서비스 상태 응답
struct AIServiceStatusResponse: Codable {
    let aiServiceAvailable: Bool
    let status: String?
    let message: String?
    let lastUpdated: String?
}

// 추천 디버그 정보
struct RecommendationDebugInfo: Codable {
    let userPreferences: [String: Any]?
    let modelVersion: String?
    let lastTrainingDate: Date?
    let recommendationCount: Int?
    let averageScore: Double?
    let processingTime: Double?
    
    // CodingKeys for custom encoding/decoding
    private enum CodingKeys: String, CodingKey {
        case userPreferences, modelVersion, lastTrainingDate
        case recommendationCount, averageScore, processingTime
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // userPreferences는 Dictionary로 직접 디코딩하기 어려우므로 nil로 설정
        self.userPreferences = nil
        self.modelVersion = try container.decodeIfPresent(String.self, forKey: .modelVersion)
        self.lastTrainingDate = try container.decodeIfPresent(Date.self, forKey: .lastTrainingDate)
        self.recommendationCount = try container.decodeIfPresent(Int.self, forKey: .recommendationCount)
        self.averageScore = try container.decodeIfPresent(Double.self, forKey: .averageScore)
        self.processingTime = try container.decodeIfPresent(Double.self, forKey: .processingTime)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(modelVersion, forKey: .modelVersion)
        try container.encodeIfPresent(lastTrainingDate, forKey: .lastTrainingDate)
        try container.encodeIfPresent(recommendationCount, forKey: .recommendationCount)
        try container.encodeIfPresent(averageScore, forKey: .averageScore)
        try container.encodeIfPresent(processingTime, forKey: .processingTime)
        // userPreferences는 인코딩하지 않음 (복잡한 타입)
    }
}

// 추천 품질
struct RecommendationQuality: Codable {
    let averageScore: Double
    let diversity: Double
    let freshness: Double
    let personalization: Double
    let overall: Double
}

// 에러 응답 (기존 ErrorResponse 확장)
extension ErrorResponse {
    var timestamp: String? { nil } // 또는 실제 로직 구현
}

// API 에러
struct APIError: Error {
    let error: String?
    let message: String?
    let details: String?
    let code: String?
    let timestamp: String?
    
    func toNetworkError() -> NetworkError {
        switch code {
        case "UNAUTHORIZED": return .unauthorized
        case "FORBIDDEN": return .forbidden
        case "NOT_FOUND": return .notFound
        case "SERVER_ERROR": return .serverError
        default: return .unknown
        }
    }
}
