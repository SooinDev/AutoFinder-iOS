import Foundation
import Combine
import Alamofire


// MARK: - CarService
final class CarService: ObservableObject {
    static let shared = CarService()
    
    // MARK: - Published Properties
    @Published var cars: [Car] = []
    @Published var isLoading = false
    @Published var currentPage = 0
    @Published var hasMorePages = true
    @Published var totalElements = 0
    @Published var error: NetworkError?
    @Published var currentFilters = CarFilterParams()
    @Published var searchHistory: [SearchHistory] = []
    
    // MARK: - Private Properties
    private let networkManager = NetworkManager.shared
    private let cacheManager = CacheManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadSearchHistory()
    }
    
    // MARK: - Public Methods
    func loadCars(filters: CarFilterParams = CarFilterParams()) -> AnyPublisher<Void, NetworkError> {
        resetPaginationIfNeeded(for: filters)
        return performCarSearch(filters: currentFilters, append: false)
    }
    
    func loadMoreCars() -> AnyPublisher<Void, NetworkError> {
        guard hasMorePages && !isLoading else {
            return Just(()).setFailureType(to: NetworkError.self).eraseToAnyPublisher()
        }
        
        currentPage += 1
        currentFilters.page = currentPage
        return performCarSearch(filters: currentFilters, append: true)
    }
    
    func searchCars(query: String) -> AnyPublisher<Void, NetworkError> {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return Just(()).setFailureType(to: NetworkError.self).eraseToAnyPublisher()
        }
        
        var filters = CarFilterParams()
        filters.model = trimmedQuery
        addSearchHistory(query: trimmedQuery)
        
        return loadCars(filters: filters)
    }
    
    func getCarDetail(carId: Int) -> AnyPublisher<Car, NetworkError> {
        let cacheKey = CacheKeys.carDetail(carId)
        
        if let cachedCar: Car = cacheManager.get(key: cacheKey) {
            return Just(cachedCar)
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        }
        
        return networkManager.getCarDetail(carId: carId)
            .handleEvents(
                receiveOutput: { [weak self] car in
                    self?.cacheManager.set(key: cacheKey, value: car, expiration: AppConstants.longCacheTime)
                    UserBehaviorService.shared.trackAction(.detailView, carId: carId)
                }
            )
            .eraseToAnyPublisher()
    }
    
    func getSimilarCars(carId: Int, limit: Int = 5) -> AnyPublisher<[Car], NetworkError> {
        let cacheKey = CacheKeys.similarCars(carId, limit)
        
        if let cachedCars: [Car] = cacheManager.get(key: cacheKey) {
            return Just(cachedCars)
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        }
        
        return networkManager.request(
            endpoint: String(format: APIConstants.Endpoints.similarCars, carId),
            parameters: ["limit": limit],
            encoding: URLEncoding.default,
            requiresAuth: false
        )
        .map { (response: PaginatedResponse<Car>) in
            response.content
        }
        .handleEvents(
            receiveOutput: { [weak self] cars in
                self?.cacheManager.set(key: cacheKey, value: cars, expiration: AppConstants.defaultCacheTime)
            }
        )
        .eraseToAnyPublisher()
    }
    
    func loadPopularCars(limit: Int = 20) -> AnyPublisher<[Car], NetworkError> {
        let cacheKey = CacheKeys.popularCars(limit)
        
        if let cachedCars: [Car] = cacheManager.get(key: cacheKey) {
            return Just(cachedCars)
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        }
        
        var filters = CarFilterParams()
        filters.size = limit
        
        return networkManager.getCars(filters: filters)
            .map(\.content)
            .handleEvents(
                receiveOutput: { [weak self] cars in
                    self?.cacheManager.set(key: cacheKey, value: cars, expiration: AppConstants.shortCacheTime)
                }
            )
            .eraseToAnyPublisher()
    }
    
    func getPriceAnalysis(model: String) -> AnyPublisher<[PriceAnalysis], NetworkError> {
        let cacheKey = CacheKeys.priceAnalysis(model)
        
        if let cachedAnalysis: [PriceAnalysis] = cacheManager.get(key: cacheKey) {
            return Just(cachedAnalysis)
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        }
        
        let encodedModel = model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? model
        let endpoint = String(format: APIConstants.Endpoints.priceAnalysis, encodedModel)
        
        return networkManager.request(
            endpoint: endpoint,
            requiresAuth: false
        )
        .handleEvents(
            receiveOutput: { [weak self] analysis in
                self?.cacheManager.set(key: cacheKey, value: analysis, expiration: AppConstants.longCacheTime)
            }
        )
        .eraseToAnyPublisher()
    }
    
    // MARK: - Filter Methods
    func applyFilters(_ filters: CarFilterParams) -> AnyPublisher<Void, NetworkError> {
        loadCars(filters: filters)
    }
    
    func resetFilters() -> AnyPublisher<Void, NetworkError> {
        loadCars(filters: CarFilterParams())
    }
    
    // MARK: - Utility Methods
    func findCar(by id: Int) -> Car? {
        cars.first { $0.id == id }
    }
    
    func removeCar(by id: Int) {
        cars.removeAll { $0.id == id }
    }
    
    func updateCar(_ updatedCar: Car) {
        if let index = cars.firstIndex(where: { $0.id == updatedCar.id }) {
            cars[index] = updatedCar
        }
    }
    
    func clearError() {
        error = nil
    }
    
    func refresh() -> AnyPublisher<Void, NetworkError> {
        invalidateCache()
        currentPage = 0
        return loadCars(filters: currentFilters)
    }
    
    var statistics: CarStatistics {
        CarStatistics(
            totalCars: totalElements,
            loadedCars: cars.count,
            averagePrice: cars.compactMap { $0.price != 9999 ? $0.price : nil }.average,
            brandDistribution: cars.groupedBy(\.brandName),
            fuelTypeDistribution: cars.groupedBy(\.fuel),
            regionDistribution: cars.groupedBy(\.region)
        )
    }
}

// MARK: - Private Methods
private extension CarService {
    func resetPaginationIfNeeded(for filters: CarFilterParams) {
        if filters != currentFilters {
            currentFilters = filters
            currentPage = 0
            cars.removeAll()
        }
        currentFilters.page = currentPage
    }
    
    func performCarSearch(filters: CarFilterParams, append: Bool) -> AnyPublisher<Void, NetworkError> {
        let cacheKey = CacheKeys.cars(filters.hashValue)
        
        if let cachedResponse: PaginatedResponse<Car> = cacheManager.get(key: cacheKey), !append {
            updateCarList(with: cachedResponse, append: false)
            return Just(()).setFailureType(to: NetworkError.self).eraseToAnyPublisher()
        }
        
        setLoadingState(true)
        
        return networkManager.getCars(filters: filters)
            .receive(on: DispatchQueue.main)
            .handleEvents(
                receiveOutput: { [weak self] response in
                    self?.updateCarList(with: response, append: append)
                    if !append {
                        self?.cacheManager.set(key: cacheKey, value: response, expiration: AppConstants.defaultCacheTime)
                    }
                },
                receiveCompletion: { [weak self] completion in
                    self?.setLoadingState(false)
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                }
            )
            .map { _ in () }
            .eraseToAnyPublisher()
    }
    
    func updateCarList(with response: PaginatedResponse<Car>, append: Bool) {
        if append {
            cars.append(contentsOf: response.content)
        } else {
            cars = response.content
        }
        
        hasMorePages = !response.last
        totalElements = response.totalElements
        
        UserBehaviorService.shared.trackAction(.search, carId: nil, value: "\(response.content.count) results")
    }
    
    func setLoadingState(_ loading: Bool) {
        isLoading = loading
        if loading {
            error = nil
        }
    }
    
    func invalidateCache() {
        let patterns = ["cars_", "car_detail_", "similar_cars_", "popular_cars_", "price_analysis_"]
        patterns.forEach { cacheManager.removeAll(pattern: $0) }
    }
}

// MARK: - Search History Management
private extension CarService {
    func loadSearchHistory() {
        guard let data = UserDefaults.standard.data(forKey: UserDefaultsKeys.searchHistory),
              let history = try? JSONDecoder().decode([SearchHistory].self, from: data) else {
            return
        }
        searchHistory = history
    }
    
    func saveSearchHistory() {
        guard let data = try? JSONEncoder().encode(searchHistory) else { return }
        UserDefaults.standard.set(data, forKey: UserDefaultsKeys.searchHistory)
    }
    
    func addSearchHistory(query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }
        
        searchHistory.removeAll { $0.query == query }
        
        let newHistory = SearchHistory(
            query: query,
            timestamp: Date(),
            resultCount: cars.count
        )
        
        searchHistory.insert(newHistory, at: 0)
        
        if searchHistory.count > SearchHistoryConstants.maxCount {
            searchHistory.removeLast(searchHistory.count - SearchHistoryConstants.maxCount)
        }
        
        saveSearchHistory()
    }
}

// MARK: - Cache Keys
private enum CacheKeys {
    static func cars(_ hash: Int) -> String { "cars_\(hash)" }
    static func carDetail(_ id: Int) -> String { "car_detail_\(id)" }
    static func similarCars(_ id: Int, _ limit: Int) -> String { "similar_cars_\(id)_\(limit)" }
    static func popularCars(_ limit: Int) -> String { "popular_cars_\(limit)" }
    static func priceAnalysis(_ model: String) -> String { "price_analysis_\(model)" }
}

// MARK: - Constants
private enum SearchHistoryConstants {
    static let maxCount = 20
}

// MARK: - Extensions
extension CarService {
    func clearSearchHistory() {
        searchHistory.removeAll()
        saveSearchHistory()
    }
    
    func removeSearchHistory(at indices: IndexSet) {
        searchHistory.remove(atOffsets: indices)
        saveSearchHistory()
    }
    
    func filterByBrand(_ brand: String) -> AnyPublisher<Void, NetworkError> {
        var filters = currentFilters
        filters.model = brand
        return applyFilters(filters)
    }
    
    func filterByPriceRange(min: Int?, max: Int?) -> AnyPublisher<Void, NetworkError> {
        var filters = currentFilters
        filters.minPrice = min
        filters.maxPrice = max
        return applyFilters(filters)
    }
    
    func filterByFuelType(_ fuel: String) -> AnyPublisher<Void, NetworkError> {
        var filters = currentFilters
        filters.fuel = fuel
        return applyFilters(filters)
    }
    
    func filterByRegion(_ region: String) -> AnyPublisher<Void, NetworkError> {
        var filters = currentFilters
        filters.region = region
        return applyFilters(filters)
    }
}

// MARK: - CarStatistics
struct CarStatistics {
    let totalCars: Int
    let loadedCars: Int
    let averagePrice: Int?
    let brandDistribution: [String: Int]
    let fuelTypeDistribution: [String: Int]
    let regionDistribution: [String: Int]
    
    var formattedAveragePrice: String {
        guard let avgPrice = averagePrice else { return "정보 없음" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return "\(formatter.string(from: NSNumber(value: avgPrice)) ?? "\(avgPrice)")만원"
    }
}

// MARK: - Array Extensions
extension Array where Element == Int {
    var average: Int? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / count
    }
}

extension Array {
    func groupedBy<Key: Hashable>(_ keyPath: KeyPath<Element, Key>) -> [Key: Int] {
        Dictionary(grouping: self, by: { $0[keyPath: keyPath] }).mapValues(\.count)
    }
}
