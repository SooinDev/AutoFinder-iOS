import Foundation

// MARK: - API 상수
struct APIConstants {
    // 또는 개발/배포 환경을 구분하여 설정
    #if DEBUG
    static let baseURL = "http://192.168.219.100:8080"  // 개발용 (실제 IP)
    #else
    static let baseURL = "https://your-production-server.com"  // 배포용
    #endif
    
    struct Endpoints {
        // 인증
        static let login = "/api/auth/login"
        static let register = "/api/auth/register"
        static let logout = "/api/auth/logout"
        static let me = "/api/auth/me"
        static let checkUsername = "/api/auth/check-username"
        
        // 차량
        static let cars = "/api/cars"
        static let carDetail = "/api/cars/%d"
        static let similarCars = "/api/cars/%d/similar"
        
        // 즐겨찾기
        static let favorites = "/api/favorites"
        static let addFavorite = "/api/favorites/%d"
        static let removeFavorite = "/api/favorites/%d"
        
        // AI 추천
        static let aiRecommend = "/api/ai/recommend"
        static let aiStatus = "/api/ai/status"
        
        // 분석
        static let priceAnalysis = "/api/analytics/price-by-year/%@"
        
        // 사용자 행동 추적
        static let behaviorTrack = "/api/behavior/track"
        static let behaviorBatch = "/api/behavior/track/batch"
        static let behaviorMe = "/api/behavior/me"
    }
}

// MARK: - 앱 상수
struct AppConstants {
    static let appName = "AutoFinder"
    static let version = "1.0.0"
    static let defaultPageSize = 20
    static let defaultCacheTime: TimeInterval = 300
    static let shortCacheTime: TimeInterval = 60
    static let longCacheTime: TimeInterval = 1800
}

// MARK: - UI 상수
struct UIConstants {
    struct Colors {
        static let primaryBlue = "PrimaryBlue"
        static let secondaryGray = "SecondaryGray"
        static let backgroundColor = "BackgroundColor"
        static let cardBackground = "CardBackground"
        static let textPrimary = "TextPrimary"
        static let textSecondary = "TextSecondary"
        static let accentColor = "AccentColor"
        static let successColor = "SuccessColor"
        static let warningColor = "WarningColor"
    }
    
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }
    
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
    }
    
    struct Shadow {
        static let radius: CGFloat = 8
        static let opacity: Double = 0.1
        static let offset = CGSize(width: 0, height: 2)
    }
}

// MARK: - 키체인 상수
struct KeychainConstants {
    static let service = "com.autofinder.app"
    static let accessTokenKey = "access_token"
    static let userIdKey = "user_id"
    static let usernameKey = "username"
}

// MARK: - UserDefaults 키
struct UserDefaultsKeys {
    static let userPreferences = "user_preferences"
    static let searchHistory = "search_history"
    static let appTheme = "app_theme"
    static let cachePolicy = "cache_policy"
}

// MARK: - 알림 상수
struct NotificationNames {
    static let userDidLogin = "UserDidLogin"
    static let userDidLogout = "UserDidLogout"
    static let favoriteDidUpdate = "FavoriteDidUpdate"
    static let themeDidChange = "ThemeDidChange"
}

// MARK: - 차량 상수
struct CarConstants {
    static let fuelTypes = ["가솔린", "디젤", "LPG", "하이브리드", "전기"]
    static let regions = ["서울", "부산", "대구", "인천", "광주", "대전", "울산", "세종", "경기", "강원", "충북", "충남", "전북", "전남", "경북", "경남", "제주"]
    
    static let priceRanges = [
        "전체": (min: 0, max: Int.max),
        "1천만원 이하": (min: 0, max: 1000),
        "1천~2천만원": (min: 1000, max: 2000),
        "2천~3천만원": (min: 2000, max: 3000),
        "3천~5천만원": (min: 3000, max: 5000),
        "5천만원 이상": (min: 5000, max: Int.max)
    ]
    
    static let mileageRanges = [
        "전체": (min: 0, max: Int.max),
        "1만km 이하": (min: 0, max: 10000),
        "1만~5만km": (min: 10000, max: 50000),
        "5만~10만km": (min: 50000, max: 100000),
        "10만~15만km": (min: 100000, max: 150000),
        "15만km 이상": (min: 150000, max: Int.max)
    ]
}

// MARK: - 기능 플래그
struct FeatureFlags {
    static let aiRecommendationEnabled = true
    static let behaviorTrackingEnabled = true
    static let priceAnalyticsEnabled = true
    static let darkModeEnabled = true
}

struct DebugConstants {
    static let isDebugMode = true
    static let enableNetworkLogging = true
    static let showDebugInfo = true
}

// APIConstants.Endpoints에 추가:
extension APIConstants.Endpoints {
    static let aiDebug = "/api/ai/debug"
    static let aiRetrain = "/api/ai/retrain"
}
