import Foundation
import Combine

// MARK: - 즐겨찾기 서비스
class FavoriteService: ObservableObject {
    static let shared = FavoriteService()
    
    // MARK: - Published Properties
    @Published var favoriteCars: [Car] = []
    @Published var favoriteCarIds: Set<Int> = []
    @Published var isLoading: Bool = false
    @Published var error: NetworkError?
    
    // MARK: - Private Properties
    private let networkManager = NetworkManager.shared
    private let authManager = AuthManager.shared
    private let cacheManager = CacheManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // 로그인 상태 변경 감지
        authManager.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                guard let self = self else { return }
                
                if isAuthenticated {
                    self.loadFavorites()
                        .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
                        .store(in: &self.cancellables)
                } else {
                    self.clearFavorites()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Favorite Management
    
    /// 즐겨찾기 목록 로드
    func loadFavorites() -> AnyPublisher<Void, NetworkError> {
        guard authManager.isAuthenticated,
              let userId = authManager.userId else {
            return Fail(error: NetworkError.unauthorized)
                .eraseToAnyPublisher()
        }
        
        // 캐시 확인
        let cacheKey = "favorites_\(userId)"
        if let cachedFavorites: [Car] = cacheManager.get(key: cacheKey) {
            DispatchQueue.main.async {
                self.updateFavoriteList(cachedFavorites)
            }
            return Just(()).setFailureType(to: NetworkError.self).eraseToAnyPublisher()
        }
        
        isLoading = true
        error = nil
        
        return networkManager.getUserFavorites(userId: userId)
            .receive(on: DispatchQueue.main)
            .handleEvents(
                receiveOutput: { [weak self] favorites in
                    self?.updateFavoriteList(favorites)
                    self?.cacheManager.set(key: cacheKey, value: favorites,
                                          expiration: AppConstants.defaultCacheTime)
                    self?.isLoading = false
                },
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                }
            )
            .map { _ in () }
            .eraseToAnyPublisher()
    }
    
    /// 즐겨찾기 추가
    func addFavorite(car: Car) -> AnyPublisher<Void, NetworkError> {
        guard authManager.isAuthenticated,
              let userId = authManager.userId else {
            return Fail(error: NetworkError.unauthorized)
                .eraseToAnyPublisher()
        }
        
        // 이미 즐겨찾기된 차량인지 확인
        guard !favoriteCarIds.contains(car.id) else {
            return Just(()).setFailureType(to: NetworkError.self).eraseToAnyPublisher()
        }
        
        // 낙관적 업데이트 (UI 즉시 반영)
        addToFavoriteList(car)
        
        return networkManager.addFavorite(carId: car.id, userId: userId)
            .receive(on: DispatchQueue.main)
            .handleEvents(
                receiveOutput: { [weak self] _ in
                    // 캐시 무효화
                    self?.invalidateFavoriteCache()
                    
                    // 알림 발송
                    NotificationCenter.default.post(
                        name: Notification.Name(NotificationNames.favoriteDidUpdate),
                        object: car,
                        userInfo: ["action": "add"]
                    )
                    
                    // 행동 추적
                    UserBehaviorService.shared.trackAction(.favorite, carId: car.id, value: "added")
                },
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        // 실패 시 롤백
                        self?.removeFromFavoriteList(car)
                        self?.error = error
                    }
                }
            )
            .map { _ in () }
            .eraseToAnyPublisher()
    }
    
    /// 즐겨찾기 제거
    func removeFavorite(car: Car) -> AnyPublisher<Void, NetworkError> {
        guard authManager.isAuthenticated,
              let userId = authManager.userId else {
            return Fail(error: NetworkError.unauthorized)
                .eraseToAnyPublisher()
        }
        
        // 즐겨찾기된 차량인지 확인
        guard favoriteCarIds.contains(car.id) else {
            return Just(()).setFailureType(to: NetworkError.self).eraseToAnyPublisher()
        }
        
        // 낙관적 업데이트 (UI 즉시 반영)
        removeFromFavoriteList(car)
        
        return networkManager.removeFavorite(carId: car.id, userId: userId)
            .receive(on: DispatchQueue.main)
            .handleEvents(
                receiveOutput: { [weak self] _ in
                    // 캐시 무효화
                    self?.invalidateFavoriteCache()
                    
                    // 알림 발송
                    NotificationCenter.default.post(
                        name: Notification.Name(NotificationNames.favoriteDidUpdate),
                        object: car,
                        userInfo: ["action": "remove"]
                    )
                    
                    // 행동 추적
                    UserBehaviorService.shared.trackAction(.favorite, carId: car.id, value: "removed")
                },
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        // 실패 시 롤백
                        self?.addToFavoriteList(car)
                        self?.error = error
                    }
                }
            )
            .map { _ in () }
            .eraseToAnyPublisher()
    }
    
    /// 즐겨찾기 토글
    func toggleFavorite(car: Car) -> AnyPublisher<Void, NetworkError> {
        if isFavorite(car: car) {
            return removeFavorite(car: car)
        } else {
            return addFavorite(car: car)
        }
    }
    
    // MARK: - Query Methods
    
    /// 특정 차량이 즐겨찾기되어 있는지 확인
    func isFavorite(car: Car) -> Bool {
        return favoriteCarIds.contains(car.id)
    }
    
    /// 특정 차량 ID가 즐겨찾기되어 있는지 확인
    func isFavorite(carId: Int) -> Bool {
        return favoriteCarIds.contains(carId)
    }
    
    /// 즐겨찾기 개수
    var favoriteCount: Int {
        return favoriteCars.count
    }
    
    /// 즐겨찾기가 비어있는지 확인
    var isEmpty: Bool {
        return favoriteCars.isEmpty
    }
    
    // MARK: - Filter & Sort Methods
    
    /// 브랜드별 즐겨찾기 필터링
    func favoritesByBrand(_ brand: String) -> [Car] {
        return favoriteCars.filter { $0.brandName == brand }
    }
    
    /// 가격대별 즐겨찾기 필터링
    func favoritesByPriceRange(min: Int, max: Int) -> [Car] {
        return favoriteCars.filter { car in
            car.price >= min && car.price <= max && car.price != 9999
        }
    }
    
    /// 연료 타입별 즐겨찾기 필터링
    func favoritesByFuelType(_ fuel: String) -> [Car] {
        return favoriteCars.filter { $0.fuel == fuel }
    }
    
    /// 즐겨찾기 정렬
    enum SortOption: String, CaseIterable {
        case priceAscending = "price_asc"
        case priceDescending = "price_desc"
        case newest = "newest"
        case oldest = "oldest"
        case modelName = "model"
        
        var displayName: String {
            switch self {
            case .priceAscending: return "가격 낮은순"
            case .priceDescending: return "가격 높은순"
            case .newest: return "최신순"
            case .oldest: return "오래된순"
            case .modelName: return "모델명순"
            }
        }
    }
    
    func sortedFavorites(by option: SortOption) -> [Car] {
        switch option {
        case .priceAscending:
            return favoriteCars.sorted { car1, car2 in
                if car1.price == 9999 { return false }
                if car2.price == 9999 { return true }
                return car1.price < car2.price
            }
        case .priceDescending:
            return favoriteCars.sorted { car1, car2 in
                if car1.price == 9999 { return false }
                if car2.price == 9999 { return true }
                return car1.price > car2.price
            }
        case .newest:
            return favoriteCars.sorted { car1, car2 in
                guard let date1 = car1.createdAt,
                      let date2 = car2.createdAt else { return false }
                return date1 > date2
            }
        case .oldest:
            return favoriteCars.sorted { car1, car2 in
                guard let date1 = car1.createdAt,
                      let date2 = car2.createdAt else { return false }
                return date1 < date2
            }
        case .modelName:
            return favoriteCars.sorted { $0.model < $1.model }
        }
    }
    
    // MARK: - Statistics & Analytics
    
    /// 즐겨찾기 통계
    var statistics: FavoriteStatistics {
        return FavoriteStatistics(
            totalCount: favoriteCount,
            averagePrice: calculateAveragePrice(),
            brandDistribution: getBrandDistribution(),
            fuelTypeDistribution: getFuelTypeDistribution(),
            priceRangeDistribution: getPriceRangeDistribution(),
            oldestFavorite: getOldestFavorite(),
            newestFavorite: getNewestFavorite()
        )
    }
    
    private func calculateAveragePrice() -> Int? {
        let validPrices = favoriteCars.compactMap { $0.price != 9999 ? $0.price : nil }
        guard !validPrices.isEmpty else { return nil }
        return validPrices.reduce(0, +) / validPrices.count
    }
    
    private func getBrandDistribution() -> [String: Int] {
        return Dictionary(grouping: favoriteCars, by: { $0.brandName })
            .mapValues { $0.count }
    }
    
    private func getFuelTypeDistribution() -> [String: Int] {
        return Dictionary(grouping: favoriteCars, by: { $0.fuel })
            .mapValues { $0.count }
    }
    
    private func getPriceRangeDistribution() -> [String: Int] {
        return Dictionary(grouping: favoriteCars, by: { $0.priceCategory })
            .mapValues { $0.count }
    }
    
    private func getOldestFavorite() -> Car? {
        return favoriteCars.min { car1, car2 in
            guard let date1 = car1.createdAt,
                  let date2 = car2.createdAt else { return false }
            return date1 < date2
        }
    }
    
    private func getNewestFavorite() -> Car? {
        return favoriteCars.max { car1, car2 in
            guard let date1 = car1.createdAt,
                  let date2 = car2.createdAt else { return false }
            return date1 < date2
        }
    }
    
    // MARK: - Batch Operations
    
    /// 여러 차량을 즐겨찾기에 추가
    func addMultipleFavorites(cars: [Car]) -> AnyPublisher<Void, NetworkError> {
        let publishers: [AnyPublisher<Void, NetworkError>] = cars.map { addFavorite(car: $0) }
        
        return Publishers.MergeMany(publishers)
            .collect()
            .map { _ in () }
            .eraseToAnyPublisher()
    }
    
    /// 여러 차량을 즐겨찾기에서 제거
    func removeMultipleFavorites(cars: [Car]) -> AnyPublisher<Void, NetworkError> {
        let publishers: [AnyPublisher<Void, NetworkError>] = cars.map { removeFavorite(car: $0) }
        
        return Publishers.MergeMany(publishers)
            .collect()
            .map { _ in () }
            .eraseToAnyPublisher()
    }
    
    /// 모든 즐겨찾기 제거
    func removeAllFavorites() -> AnyPublisher<Void, NetworkError> {
        return removeMultipleFavorites(cars: favoriteCars)
    }
    
    // MARK: - Export & Share
    
    /// 즐겨찾기 목록을 텍스트로 내보내기
    func exportFavoritesToText() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ko_KR")
        
        var text = "내 즐겨찾기 차량 목록\n"
        text += "생성일: \(formatter.string(from: Date()))\n\n"
        
        for (index, car) in favoriteCars.enumerated() {
            text += "\(index + 1). \(car.model)\n"
            text += "   - 가격: \(car.displayPrice)\n"
            text += "   - 연식: \(car.displayYear)\n"
            text += "   - 주행거리: \(car.displayMileage)\n"
            text += "   - 연료: \(car.fuel)\n"
            text += "   - 지역: \(car.region)\n\n"
        }
        
        return text
    }
    
    /// 즐겨찾기 목록을 JSON으로 내보내기
    func exportFavoritesToJSON() -> Data? {
        let exportData = FavoriteExportData(
            exportDate: Date(),
            totalCount: favoriteCount,
            cars: favoriteCars
        )
        
        return try? JSONEncoder().encode(exportData)
    }
    
    // MARK: - Private Helper Methods
    
    private func updateFavoriteList(_ favorites: [Car]) {
        favoriteCars = favorites
        favoriteCarIds = Set(favorites.map { $0.id })
    }
    
    private func addToFavoriteList(_ car: Car) {
        if !favoriteCarIds.contains(car.id) {
            favoriteCars.append(car)
            favoriteCarIds.insert(car.id)
        }
    }
    
    private func removeFromFavoriteList(_ car: Car) {
        favoriteCars.removeAll { $0.id == car.id }
        favoriteCarIds.remove(car.id)
    }
    
    private func clearFavorites() {
        favoriteCars.removeAll()
        favoriteCarIds.removeAll()
        invalidateFavoriteCache()
    }
    
    private func invalidateFavoriteCache() {
        guard let userId = authManager.userId else { return }
        let cacheKey = "favorites_\(userId)"
        cacheManager.remove(key: cacheKey)
    }
    
    // MARK: - Public Helper Methods
    
    /// 에러 초기화
    func clearError() {
        error = nil
    }
    
    /// 새로고침
    func refresh() -> AnyPublisher<Void, NetworkError> {
        invalidateFavoriteCache()
        return loadFavorites()
    }
    
    /// 즐겨찾기 캐시 무효화 (외부에서 호출용)
    func invalidateCache() {
        invalidateFavoriteCache()
    }
}

// MARK: - FavoriteStatistics Model
struct FavoriteStatistics {
    let totalCount: Int
    let averagePrice: Int?
    let brandDistribution: [String: Int]
    let fuelTypeDistribution: [String: Int]
    let priceRangeDistribution: [String: Int]
    let oldestFavorite: Car?
    let newestFavorite: Car?
    
    var formattedAveragePrice: String {
        guard let avgPrice = averagePrice else { return "정보 없음" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return "\(formatter.string(from: NSNumber(value: avgPrice)) ?? "\(avgPrice)")만원"
    }
    
    var topBrand: String? {
        return brandDistribution.max(by: { $0.value < $1.value })?.key
    }
    
    var topFuelType: String? {
        return fuelTypeDistribution.max(by: { $0.value < $1.value })?.key
    }
    
    var mostCommonPriceRange: String? {
        return priceRangeDistribution.max(by: { $0.value < $1.value })?.key
    }
}

// MARK: - FavoriteExportData Model
struct FavoriteExportData: Codable {
    let exportDate: Date
    let totalCount: Int
    let cars: [Car]
    
    var formattedExportDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: exportDate)
    }
}

// MARK: - FavoriteService Extensions
extension FavoriteService {
    
    // MARK: - Search within Favorites
    
    /// 즐겨찾기 내에서 검색
    func searchFavorites(query: String) -> [Car] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return favoriteCars
        }
        
        let lowercaseQuery = query.lowercased()
        
        return favoriteCars.filter { car in
            car.model.lowercased().contains(lowercaseQuery) ||
            car.brandName.lowercased().contains(lowercaseQuery) ||
            car.fuel.lowercased().contains(lowercaseQuery) ||
            car.region.lowercased().contains(lowercaseQuery)
        }
    }
    
    // MARK: - Recommendation Based on Favorites
    
    /// 즐겨찾기 기반 추천 조건 생성
    var recommendationFilters: CarFilterParams {
        guard !favoriteCars.isEmpty else { return CarFilterParams() }
        
        var filters = CarFilterParams()
        
        // 가장 많이 즐겨찾기한 브랜드
        if let topBrand = statistics.topBrand {
            filters.model = topBrand
        }
        
        // 평균 가격 기준 범위 설정 (±30%)
        if let avgPrice = statistics.averagePrice {
            let margin = Double(avgPrice) * 0.3
            filters.minPrice = max(0, Int(Double(avgPrice) - margin))
            filters.maxPrice = Int(Double(avgPrice) + margin)
        }
        
        // 가장 많이 선택한 연료 타입
        if let topFuel = statistics.topFuelType {
            filters.fuel = topFuel
        }
        
        return filters
    }
    
    // MARK: - Comparison Helpers
    
    /// 즐겨찾기 차량들과 다른 차량 비교
    func compareCar(_ car: Car) -> CarComparison {
        let favoritesPrices = favoriteCars.compactMap { $0.price != 9999 ? $0.price : nil }
        
        var comparison = CarComparison(
            car: car,
            isMoreExpensive: false,
            isCheaper: false,
            priceDifferenceFromAverage: 0,
            similarCarsInFavorites: []
        )
        
        if let avgPrice = statistics.averagePrice, car.price != 9999 {
            comparison.priceDifferenceFromAverage = car.price - avgPrice
            comparison.isMoreExpensive = car.price > avgPrice
            comparison.isCheaper = car.price < avgPrice
        }
        
        // 유사한 차량 찾기 (같은 브랜드, 비슷한 가격대)
        comparison.similarCarsInFavorites = favoriteCars.filter { favCar in
            favCar.brandName == car.brandName ||
            (abs(favCar.price - car.price) < 500 && favCar.price != 9999 && car.price != 9999)
        }
        
        return comparison
    }
}

// MARK: - CarComparison Model
struct CarComparison {
    let car: Car
    var isMoreExpensive: Bool
    var isCheaper: Bool
    var priceDifferenceFromAverage: Int
    var similarCarsInFavorites: [Car]
    
    var priceDifferenceDescription: String {
        if priceDifferenceFromAverage == 0 {
            return "평균과 동일"
        } else if priceDifferenceFromAverage > 0 {
            return "평균보다 \(abs(priceDifferenceFromAverage))만원 비쌈"
        } else {
            return "평균보다 \(abs(priceDifferenceFromAverage))만원 저렴"
        }
    }
    
    var hasSimilarCars: Bool {
        return !similarCarsInFavorites.isEmpty
    }
}
