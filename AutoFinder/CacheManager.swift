import Foundation
import Combine
import UIKit

// MARK: - 캐시 매니저 (싱글톤)
class CacheManager: ObservableObject {
    static let shared = CacheManager()
    
    // MARK: - Published Properties
    @Published var cacheSize: Int = 0
    @Published var cacheHitRate: Double = 0.0
    
    // MARK: - Private Properties
    private var cache: [String: CacheItem] = [:]
    private let cacheQueue = DispatchQueue(label: "com.autofinder.cache", attributes: .concurrent)
    private var cacheStats = CacheStatistics()
    
    // 캐시 설정
    private let maxCacheSize: Int = 1000 // 최대 아이템 수
    private let maxMemorySize: Int = 50 * 1024 * 1024 // 50MB
    private let defaultExpiration: TimeInterval = 300 // 5분
    
    // 정리 타이머
    private var cleanupTimer: Timer?
    private let cleanupInterval: TimeInterval = 60 // 1분마다 정리
    
    private init() {
        setupCleanupTimer()
        loadCacheSettings()
        
        // 메모리 경고 감지
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // 앱 백그라운드 진입 시 정리
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    deinit {
        cleanupTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Core Cache Operations
    
    /// 캐시에 데이터 저장
    func set<T: Codable>(key: String, value: T, expiration: TimeInterval? = nil) {
        cacheQueue.async(flags: .barrier) {
            do {
                let data = try JSONEncoder().encode(value)
                let expirationTime = Date().addingTimeInterval(expiration ?? self.defaultExpiration)
                
                let item = CacheItem(
                    key: key,
                    data: data,
                    expiration: expirationTime,
                    size: data.count,
                    hitCount: 0,
                    lastAccessed: Date()
                )
                
                self.cache[key] = item
                self.updateCacheStats()
                self.enforceMemoryLimits()
                
                DispatchQueue.main.async {
                    self.cacheSize = self.cache.count
                }
                
            } catch {
                print("❌ 캐시 저장 실패: \(error.localizedDescription)")
            }
        }
    }
    
    /// 캐시에서 데이터 조회
    func get<T: Codable>(key: String, type: T.Type = T.self) -> T? {
        return cacheQueue.sync {
            guard let item = cache[key] else {
                cacheStats.miss()
                updateCacheHitRate()
                return nil
            }
            
            // 만료 확인
            if item.isExpired {
                cache.removeValue(forKey: key)
                cacheStats.miss()
                updateCacheHitRate()
                return nil
            }
            
            // 접근 정보 업데이트
            var updatedItem = item
            updatedItem.hitCount += 1
            updatedItem.lastAccessed = Date()
            cache[key] = updatedItem
            
            cacheStats.hit()
            updateCacheHitRate()
            
            do {
                let value = try JSONDecoder().decode(T.self, from: item.data)
                return value
            } catch {
                print("❌ 캐시 디코딩 실패: \(error.localizedDescription)")
                cache.removeValue(forKey: key)
                return nil
            }
        }
    }
    
    /// 편의 메서드 - 타입 추론 활용
    func get<T: Codable>(key: String) -> T? {
        return get(key: key, type: T.self)
    }
    
    /// 특정 키 삭제
    func remove(key: String) {
        cacheQueue.async(flags: .barrier) {
            self.cache.removeValue(forKey: key)
            self.updateCacheStats()
            
            DispatchQueue.main.async {
                self.cacheSize = self.cache.count
            }
        }
    }
    
    /// 패턴에 맞는 키들 삭제
    func removeAll(pattern: String) {
        cacheQueue.async(flags: .barrier) {
            let keysToRemove = self.cache.keys.filter { $0.contains(pattern) }
            for key in keysToRemove {
                self.cache.removeValue(forKey: key)
            }
            self.updateCacheStats()
            
            DispatchQueue.main.async {
                self.cacheSize = self.cache.count
            }
        }
    }
    
    /// 모든 캐시 삭제
    func clearAll() {
        cacheQueue.async(flags: .barrier) {
            self.cache.removeAll()
            self.cacheStats = CacheStatistics()
            
            DispatchQueue.main.async {
                self.cacheSize = 0
                self.cacheHitRate = 0.0
            }
        }
    }
    
    /// 캐시 존재 여부 확인
    func contains(key: String) -> Bool {
        return cacheQueue.sync {
            guard let item = cache[key] else { return false }
            return !item.isExpired
        }
    }
    
    // MARK: - Cache Management
    
    private func setupCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: cleanupInterval, repeats: true) { [weak self] _ in
            self?.performCleanup()
        }
    }
    
    private func performCleanup() {
        cacheQueue.async(flags: .barrier) {
            let now = Date()
            var removedCount = 0
            
            // 만료된 아이템 제거
            for (key, item) in self.cache {
                if item.expiration < now {
                    self.cache.removeValue(forKey: key)
                    removedCount += 1
                }
            }
            
            if removedCount > 0 {
                print("🧹 캐시 정리 완료: \(removedCount)개 항목 제거")
                self.updateCacheStats()
                
                DispatchQueue.main.async {
                    self.cacheSize = self.cache.count
                }
            }
        }
    }
    
    private func enforceMemoryLimits() {
        // 아이템 수 제한
        if cache.count > maxCacheSize {
            evictLeastRecentlyUsed(count: cache.count - maxCacheSize)
        }
        
        // 메모리 크기 제한
        let totalSize = cache.values.reduce(0) { $0 + $1.size }
        if totalSize > maxMemorySize {
            evictLargestItems(targetSize: maxMemorySize)
        }
    }
    
    private func evictLeastRecentlyUsed(count: Int) {
        let sortedItems = cache.sorted { $0.value.lastAccessed < $1.value.lastAccessed }
        let itemsToRemove = sortedItems.prefix(count)
        
        for (key, _) in itemsToRemove {
            cache.removeValue(forKey: key)
        }
        
        print("🗑️ LRU 정책으로 \(count)개 항목 제거")
    }
    
    private func evictLargestItems(targetSize: Int) {
        let sortedBySize = cache.sorted { $0.value.size > $1.value.size }
        var currentSize = cache.values.reduce(0) { $0 + $1.size }
        var removedCount = 0
        
        for (key, item) in sortedBySize {
            if currentSize <= targetSize { break }
            
            cache.removeValue(forKey: key)
            currentSize -= item.size
            removedCount += 1
        }
        
        print("📦 크기 제한으로 \(removedCount)개 항목 제거")
    }
    
    // MARK: - Statistics & Monitoring
    
    private func updateCacheStats() {
        // 백그라운드에서 통계 업데이트
    }
    
    private func updateCacheHitRate() {
        DispatchQueue.main.async {
            self.cacheHitRate = self.cacheStats.hitRate
        }
    }
    
    /// 캐시 통계 조회
    var statistics: CacheStatistics {
        return cacheQueue.sync {
            var stats = cacheStats
            stats.totalItems = cache.count
            stats.totalSize = cache.values.reduce(0) { $0 + $1.size }
            stats.averageItemSize = stats.totalItems > 0 ? stats.totalSize / stats.totalItems : 0
            return stats
        }
    }
    
    /// 상위 접근 빈도 아이템 조회
    func getTopAccessedItems(limit: Int = 10) -> [CacheItemInfo] {
        return cacheQueue.sync {
            return cache.values
                .sorted { $0.hitCount > $1.hitCount }
                .prefix(limit)
                .map { CacheItemInfo(from: $0) }
        }
    }
    
    /// 캐시 키 목록 조회
    func getAllKeys(pattern: String? = nil) -> [String] {
        return cacheQueue.sync {
            let keys = Array(cache.keys)
            
            if let pattern = pattern {
                return keys.filter { $0.contains(pattern) }
            }
            
            return keys.sorted()
        }
    }
    
    // MARK: - Memory Management
    
    @objc private func handleMemoryWarning() {
        print("⚠️ 메모리 경고 - 캐시 정리 시작")
        
        cacheQueue.async(flags: .barrier) {
            // 메모리 경고 시 캐시 크기를 50%로 줄임
            let targetCount = self.cache.count / 2
            self.evictLeastRecentlyUsed(count: self.cache.count - targetCount)
            
            DispatchQueue.main.async {
                self.cacheSize = self.cache.count
            }
        }
    }
    
    @objc private func handleAppBackground() {
        // 백그라운드 진입 시 만료된 아이템 정리
        performCleanup()
    }
    
    // MARK: - Configuration
    
    private func loadCacheSettings() {
        // UserDefaults에서 캐시 설정 로드
        if let cachePolicy = UserDefaults.standard.string(forKey: UserDefaultsKeys.cachePolicy) {
            applyCachePolicy(cachePolicy)
        }
    }
    
    private func applyCachePolicy(_ policy: String) {
        // 캐시 정책 적용 (aggressive, normal, conservative)
        switch policy {
        case "aggressive":
            // 더 오래, 더 많이 캐시
            break
        case "conservative":
            // 짧게, 적게 캐시
            break
        default:
            // normal 정책 (기본값)
            break
        }
    }
    
    /// 캐시 설정 업데이트
    func updateCachePolicy(_ policy: String) {
        UserDefaults.standard.set(policy, forKey: UserDefaultsKeys.cachePolicy)
        applyCachePolicy(policy)
    }
    
    // MARK: - Debug & Maintenance
    
    /// 캐시 상태 출력 (디버그용)
    func printCacheStatus() {
        #if DEBUG
        let stats = statistics
        print("""
        📊 캐시 상태:
        - 총 아이템 수: \(stats.totalItems)
        - 총 크기: \(formatBytes(stats.totalSize))
        - 히트율: \(String(format: "%.1f", stats.hitRate * 100))%
        - 평균 아이템 크기: \(formatBytes(stats.averageItemSize))
        - 총 요청 수: \(stats.totalRequests)
        - 히트 수: \(stats.hits)
        - 미스 수: \(stats.misses)
        """)
        #endif
    }
    
    /// 캐시 무결성 검사
    func validateCache() -> CacheValidationResult {
        return cacheQueue.sync {
            var result = CacheValidationResult()
            
            for (key, item) in cache {
                result.totalItems += 1
                
                // 만료된 아이템 확인
                if item.isExpired {
                    result.expiredItems += 1
                }
                
                // 데이터 무결성 확인
                do {
                    let _ = try JSONSerialization.jsonObject(with: item.data)
                } catch {
                    result.corruptedItems += 1
                    result.corruptedKeys.append(key)
                }
                
                // 크기 검증
                if item.size != item.data.count {
                    result.sizeMismatchItems += 1
                }
            }
            
            result.isValid = result.corruptedItems == 0 && result.sizeMismatchItems == 0
            return result
        }
    }
    
    /// 손상된 캐시 아이템 복구
    func repairCache() -> Int {
        return cacheQueue.sync(flags: .barrier) {
            var repairedCount = 0
            var keysToRemove: [String] = []
            
            for (key, item) in cache {
                // 만료된 아이템 제거
                if item.isExpired {
                    keysToRemove.append(key)
                    continue
                }
                
                // 손상된 데이터 제거
                do {
                    let _ = try JSONSerialization.jsonObject(with: item.data)
                } catch {
                    keysToRemove.append(key)
                    repairedCount += 1
                }
                
                // 크기 불일치 수정
                if item.size != item.data.count {
                    var repairedItem = item
                    repairedItem.size = item.data.count
                    cache[key] = repairedItem
                    repairedCount += 1
                }
            }
            
            // 문제가 있는 아이템들 제거
            for key in keysToRemove {
                cache.removeValue(forKey: key)
            }
            
            updateCacheStats()
            return repairedCount
        }
    }
    
    // MARK: - Utilities
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    /// 캐시 효율성 분석
    func analyzeCacheEfficiency() -> CacheEfficiencyReport {
        return cacheQueue.sync {
            let stats = statistics
            
            // 접근 빈도 분석
            let accessFrequency = cache.values.map { $0.hitCount }
            let avgAccess = accessFrequency.isEmpty ? 0 : accessFrequency.reduce(0, +) / accessFrequency.count
            
            // 크기 분포 분석
            let sizes = cache.values.map { $0.size }
            let avgSize = sizes.isEmpty ? 0 : sizes.reduce(0, +) / sizes.count
            
            // 만료 분석
            let now = Date()
            let expiredCount = cache.values.filter { $0.expiration < now }.count
            
            return CacheEfficiencyReport(
                hitRate: stats.hitRate,
                averageAccessCount: avgAccess,
                averageItemSize: avgSize,
                expiredItemsRatio: Double(expiredCount) / Double(cache.count),
                memoryEfficiency: Double(stats.totalSize) / Double(maxMemorySize),
                recommendation: generateEfficiencyRecommendation(stats: stats)
            )
        }
    }
    
    private func generateEfficiencyRecommendation(stats: CacheStatistics) -> String {
        if stats.hitRate < 0.3 {
            return "캐시 히트율이 낮습니다. 캐시 정책을 검토하세요."
        } else if stats.hitRate > 0.8 {
            return "캐시 성능이 우수합니다."
        } else if Double(stats.totalSize) / Double(maxMemorySize) > 0.9 {
            return "캐시 메모리 사용량이 높습니다. 정리가 필요합니다."
        } else {
            return "캐시 성능이 양호합니다."
        }
    }
}

// MARK: - Supporting Models

struct CacheItem {
    let key: String
    let data: Data
    let expiration: Date
    var size: Int
    var hitCount: Int
    var lastAccessed: Date
    
    var isExpired: Bool {
        return Date() > expiration
    }
    
    var age: TimeInterval {
        return Date().timeIntervalSince(lastAccessed)
    }
}

struct CacheStatistics {
    var totalItems: Int = 0
    var totalSize: Int = 0
    var averageItemSize: Int = 0
    var hits: Int = 0
    var misses: Int = 0
    var totalRequests: Int = 0
    
    var hitRate: Double {
        guard totalRequests > 0 else { return 0.0 }
        return Double(hits) / Double(totalRequests)
    }
    
    mutating func hit() {
        hits += 1
        totalRequests += 1
    }
    
    mutating func miss() {
        misses += 1
        totalRequests += 1
    }
}

struct CacheItemInfo {
    let key: String
    let size: Int
    let hitCount: Int
    let lastAccessed: Date
    let isExpired: Bool
    
    init(from item: CacheItem) {
        self.key = item.key
        self.size = item.size
        self.hitCount = item.hitCount
        self.lastAccessed = item.lastAccessed
        self.isExpired = item.isExpired
    }
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
    
    var formattedLastAccessed: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastAccessed, relativeTo: Date())
    }
}

struct CacheValidationResult {
    var totalItems: Int = 0
    var expiredItems: Int = 0
    var corruptedItems: Int = 0
    var sizeMismatchItems: Int = 0
    var corruptedKeys: [String] = []
    var isValid: Bool = false
    
    var healthScore: Double {
        guard totalItems > 0 else { return 1.0 }
        let problemItems = expiredItems + corruptedItems + sizeMismatchItems
        return 1.0 - (Double(problemItems) / Double(totalItems))
    }
    
    var summary: String {
        if isValid {
            return "캐시 상태가 정상입니다."
        } else {
            var issues: [String] = []
            if expiredItems > 0 {
                issues.append("만료된 아이템 \(expiredItems)개")
            }
            if corruptedItems > 0 {
                issues.append("손상된 아이템 \(corruptedItems)개")
            }
            if sizeMismatchItems > 0 {
                issues.append("크기 불일치 \(sizeMismatchItems)개")
            }
            return "문제 발견: \(issues.joined(separator: ", "))"
        }
    }
}

struct CacheEfficiencyReport {
    let hitRate: Double
    let averageAccessCount: Int
    let averageItemSize: Int
    let expiredItemsRatio: Double
    let memoryEfficiency: Double
    let recommendation: String
    
    var efficiencyGrade: String {
        let score = (hitRate * 0.4) +
                   ((1.0 - expiredItemsRatio) * 0.3) +
                   ((1.0 - memoryEfficiency) * 0.3)
        
        switch score {
        case 0.8...: return "A"
        case 0.6..<0.8: return "B"
        case 0.4..<0.6: return "C"
        case 0.2..<0.4: return "D"
        default: return "F"
        }
    }
}

// MARK: - CacheManager Extensions

extension CacheManager {
    
    // MARK: - Convenience Methods
    
    /// 문자열 캐시
    func setString(_ value: String, forKey key: String, expiration: TimeInterval? = nil) {
        set(key: key, value: value, expiration: expiration)
    }
    
    func getString(forKey key: String) -> String? {
        return get(key: key)
    }
    
    /// 이미지 데이터 캐시 (향후 확장용)
    func setImageData(_ data: Data, forKey key: String, expiration: TimeInterval? = nil) {
        set(key: key, value: data, expiration: expiration)
    }
    
    func getImageData(forKey key: String) -> Data? {
        return get(key: key)
    }
    
    // MARK: - Batch Operations
    
    /// 여러 키 일괄 삭제
    func removeKeys(_ keys: [String]) {
        cacheQueue.async(flags: .barrier) {
            for key in keys {
                self.cache.removeValue(forKey: key)
            }
            self.updateCacheStats()
            
            DispatchQueue.main.async {
                self.cacheSize = self.cache.count
            }
        }
    }
    
    /// 만료 시간이 임박한 아이템들 갱신
    func refreshExpiringItems(within timeInterval: TimeInterval) {
        cacheQueue.async {
            let threshold = Date().addingTimeInterval(timeInterval)
            let expiringKeys = self.cache.compactMap { (key, item) -> String? in
                return item.expiration < threshold ? key : nil
            }
            
            if !expiringKeys.isEmpty {
                print("⏰ 만료 임박 아이템 \(expiringKeys.count)개 발견")
                // 실제로는 각 키에 대해 데이터 재요청 로직 필요
            }
        }
    }
    
    // MARK: - Performance Monitoring
    
    /// 성능 메트릭 리셋
    func resetStatistics() {
        cacheQueue.async(flags: .barrier) {
            self.cacheStats = CacheStatistics()
            
            DispatchQueue.main.async {
                self.cacheHitRate = 0.0
            }
        }
    }
    
    /// 캐시 사용 패턴 분석
    func getCacheUsagePattern() -> CacheUsagePattern {
        return cacheQueue.sync {
            let now = Date()
            var recentlyAccessed = 0
            var frequentlyAccessed = 0
            var largeItems = 0
            
            for item in cache.values {
                // 최근 1시간 내 접근
                if now.timeIntervalSince(item.lastAccessed) < 3600 {
                    recentlyAccessed += 1
                }
                
                // 접근 횟수 5회 이상
                if item.hitCount >= 5 {
                    frequentlyAccessed += 1
                }
                
                // 1MB 이상 아이템
                if item.size > 1024 * 1024 {
                    largeItems += 1
                }
            }
            
            return CacheUsagePattern(
                totalItems: cache.count,
                recentlyAccessedItems: recentlyAccessed,
                frequentlyAccessedItems: frequentlyAccessed,
                largeItems: largeItems,
                avgHitCount: cache.values.map { $0.hitCount }.reduce(0, +) / max(cache.count, 1)
            )
        }
    }
}

struct CacheUsagePattern {
    let totalItems: Int
    let recentlyAccessedItems: Int
    let frequentlyAccessedItems: Int
    let largeItems: Int
    let avgHitCount: Int
    
    var recentAccessRatio: Double {
        guard totalItems > 0 else { return 0.0 }
        return Double(recentlyAccessedItems) / Double(totalItems)
    }
    
    var frequentAccessRatio: Double {
        guard totalItems > 0 else { return 0.0 }
        return Double(frequentlyAccessedItems) / Double(totalItems)
    }
}
