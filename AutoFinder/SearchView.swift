import SwiftUI
import Combine

// MARK: - 검색 뷰
struct SearchView: View {
    @StateObject private var carService = CarService.shared
    @StateObject private var favoriteService = FavoriteService.shared
    @State private var searchText = ""
    @State private var filters = CarFilterParams()
    @State private var showingFilters = false
    @State private var showingCarDetail = false
    @State private var selectedCar: Car?
    @State private var isSearching = false
    @State private var searchHistory: [String] = []
    @State private var recentSearches: [String] = []
    @State private var cancellables = Set<AnyCancellable>()
    
    // 필터 상태
    @State private var selectedBrands: Set<String> = []
    @State private var selectedFuelTypes: Set<String> = []
    @State private var selectedRegions: Set<String> = []
    @State private var priceRange: ClosedRange<Double> = 0...10000
    @State private var yearRange: ClosedRange<Double> = 1990...2024
    @State private var mileageRange: ClosedRange<Double> = 0...300000
    
    var body: some View {
        VStack(spacing: 0) {
            // 검색 헤더
            SearchHeaderSection(
                searchText: $searchText,
                showingFilters: $showingFilters,
                onSearch: performSearch,
                onClear: clearSearch
            )
            
            // 메인 컨텐츠
            if searchText.isEmpty && carService.cars.isEmpty {
                SearchEmptyStateView(
                    recentSearches: recentSearches,
                    onRecentSearchTap: { query in
                        searchText = query
                        performSearch()
                    },
                    onPopularBrandTap: { brand in
                        searchText = brand
                        performSearch()
                    }
                )
            } else if isSearching {
                SearchLoadingView()
            } else if carService.cars.isEmpty && !searchText.isEmpty {
                SearchNoResultsView(
                    query: searchText,
                    onClearFilters: clearAllFilters,
                    onNewSearch: {
                        searchText = ""
                        clearSearch()
                    }
                )
            } else {
                SearchResultsView(
                    cars: carService.cars,
                    totalResults: carService.totalElements,
                    onCarTap: { car in
                        selectedCar = car
                        showingCarDetail = true
                    },
                    onLoadMore: loadMoreResults
                )
            }
        }
        .navigationTitle("검색")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingFilters) {
            FilterView(filters: $filters) { newFilters in
                applyFilters(newFilters)
            }
        }
        .sheet(isPresented: $showingCarDetail) {
            if let car = selectedCar {
                CarDetailView(car: car)
            }
        }
        .onAppear {
            loadRecentSearches()
        }
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        isSearching = true
        saveRecentSearch(searchText)
        
        var searchFilters = filters
        searchFilters.model = searchText
        
        carService.searchCars(query: searchText)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    self.isSearching = false
                    if case .failure(let error) = completion {
                        print("검색 실패: \(error)")
                    }
                },
                receiveValue: { _ in
                    self.isSearching = false
                }
            )
            .store(in: &cancellables)
        
        // 행동 추적
        UserBehaviorService.shared.trackSearch(query: searchText, resultCount: carService.cars.count)
    }
    
    private func clearSearch() {
        searchText = ""
        carService.cars.removeAll()
        filters = CarFilterParams()
    }
    
    private func applyFilters(_ newFilters: CarFilterParams) {
        filters = newFilters
        
        carService.applyFilters(filters)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    
    private func clearAllFilters() {
        filters = CarFilterParams()
        
        carService.resetFilters()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    
    private func loadMoreResults() {
        carService.loadMoreCars()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    
    private func loadRecentSearches() {
        recentSearches = UserDefaults.standard.stringArray(forKey: "recent_searches") ?? []
    }
    
    private func saveRecentSearch(_ query: String) {
        var searches = recentSearches
        searches.removeAll { $0 == query }
        searches.insert(query, at: 0)
        searches = Array(searches.prefix(10)) // 최대 10개까지
        
        recentSearches = searches
        UserDefaults.standard.set(searches, forKey: "recent_searches")
    }
}

// MARK: - 검색 헤더 섹션
struct SearchHeaderSection: View {
    @Binding var searchText: String
    @Binding var showingFilters: Bool
    let onSearch: () -> Void
    let onClear: () -> Void
    
    var body: some View {
        VStack(spacing: UIConstants.Spacing.sm) {
            HStack(spacing: UIConstants.Spacing.sm) {
                // 검색 바
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color(UIConstants.Colors.secondaryGray))
                    
                    TextField("브랜드, 모델명으로 검색", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onSubmit {
                            onSearch()
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            onClear()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Color(UIConstants.Colors.secondaryGray))
                        }
                    }
                }
                .padding(UIConstants.Spacing.sm)
                .background(Color(UIConstants.Colors.backgroundColor))
                .cornerRadius(UIConstants.CornerRadius.medium)
                
                // 필터 버튼
                Button(action: {
                    showingFilters = true
                }) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(Color(UIConstants.Colors.primaryBlue))
                        .padding(UIConstants.Spacing.sm)
                        .background(Color(UIConstants.Colors.backgroundColor))
                        .cornerRadius(UIConstants.CornerRadius.medium)
                }
            }
            .padding(.horizontal)
            
            // 검색 버튼
            if !searchText.isEmpty {
                Button("검색") {
                    onSearch()
                }
                .buttonStyle(AppPrimaryButtonStyle())
                .padding(.horizontal)
            }
        }
        .padding(.vertical, UIConstants.Spacing.sm)
        .background(Color(UIConstants.Colors.cardBackground))
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 2,
            x: 0,
            y: 1
        )
    }
}

// MARK: - 검색 빈 상태 뷰
struct SearchEmptyStateView: View {
    let recentSearches: [String]
    let onRecentSearchTap: (String) -> Void
    let onPopularBrandTap: (String) -> Void
    
    private let popularBrands = ["현대", "기아", "제네시스", "BMW", "벤츠", "아우디"]
    private let searchSuggestions = [
        "아반떼", "쏘나타", "그랜저", "K3", "K5", "K7", "모닝", "스파크"
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: UIConstants.Spacing.lg) {
                // 최근 검색어
                if !recentSearches.isEmpty {
                    RecentSearchesSection(
                        searches: recentSearches,
                        onSearchTap: onRecentSearchTap
                    )
                }
                
                // 인기 브랜드
                PopularBrandsSection(
                    brands: popularBrands,
                    onBrandTap: onPopularBrandTap
                )
                
                // 검색 제안
                SearchSuggestionsSection(
                    suggestions: searchSuggestions,
                    onSuggestionTap: onRecentSearchTap
                )
                
                // 검색 팁
                SearchTipsSection()
            }
            .padding()
        }
    }
}

// MARK: - 최근 검색어 섹션
struct RecentSearchesSection: View {
    let searches: [String]
    let onSearchTap: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.md) {
            HStack {
                Text("최근 검색어")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("전체 삭제") {
                    UserDefaults.standard.removeObject(forKey: "recent_searches")
                }
                .font(.caption)
                .foregroundColor(Color(UIConstants.Colors.accentColor))
            }
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 100))
            ], spacing: UIConstants.Spacing.sm) {
                ForEach(searches, id: \.self) { search in
                    Button(action: {
                        onSearchTap(search)
                    }) {
                        HStack {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundColor(Color(UIConstants.Colors.secondaryGray))
                            
                            Text(search)
                                .font(.caption)
                                .foregroundColor(Color(UIConstants.Colors.textPrimary))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, UIConstants.Spacing.sm)
                        .padding(.vertical, UIConstants.Spacing.xs)
                        .background(Color(UIConstants.Colors.backgroundColor))
                        .cornerRadius(UIConstants.CornerRadius.small)
                    }
                }
            }
        }
    }
}

// MARK: - 인기 브랜드 섹션
struct PopularBrandsSection: View {
    let brands: [String]
    let onBrandTap: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.md) {
            Text("인기 브랜드")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: UIConstants.Spacing.sm) {
                ForEach(brands, id: \.self) { brand in
                    Button(action: {
                        onBrandTap(brand)
                    }) {
                        VStack(spacing: UIConstants.Spacing.xs) {
                            Image(systemName: "car.fill")
                                .font(.title2)
                                .foregroundColor(Color(UIConstants.Colors.primaryBlue))
                            
                            Text(brand)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(Color(UIConstants.Colors.textPrimary))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(UIConstants.Colors.cardBackground))
                        .cornerRadius(UIConstants.CornerRadius.medium)
                        .shadow(
                            color: Color.black.opacity(0.05),
                            radius: 4,
                            x: 0,
                            y: 2
                        )
                    }
                }
            }
        }
    }
}

// MARK: - 검색 제안 섹션
struct SearchSuggestionsSection: View {
    let suggestions: [String]
    let onSuggestionTap: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.md) {
            Text("추천 검색어")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 80))
            ], spacing: UIConstants.Spacing.sm) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(action: {
                        onSuggestionTap(suggestion)
                    }) {
                        Text(suggestion)
                            .font(.caption)
                            .foregroundColor(Color(UIConstants.Colors.primaryBlue))
                            .padding(.horizontal, UIConstants.Spacing.sm)
                            .padding(.vertical, UIConstants.Spacing.xs)
                            .background(Color(UIConstants.Colors.primaryBlue).opacity(0.1))
                            .cornerRadius(UIConstants.CornerRadius.small)
                    }
                }
            }
        }
    }
}

// MARK: - 검색 팁 섹션
struct SearchTipsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.md) {
            Text("검색 팁")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: UIConstants.Spacing.sm) {
                SearchTipItem(
                    icon: "lightbulb.fill",
                    title: "브랜드명으로 검색",
                    description: "현대, 기아, BMW 등 브랜드명을 입력하세요"
                )
                
                SearchTipItem(
                    icon: "car.fill",
                    title: "모델명으로 검색",
                    description: "아반떼, 쏘나타, K5 등 모델명을 입력하세요"
                )
                
                SearchTipItem(
                    icon: "slider.horizontal.3",
                    title: "필터 활용",
                    description: "가격, 연식, 지역 등 세부 조건을 설정하세요"
                )
            }
        }
        .padding()
        .background(Color(UIConstants.Colors.backgroundColor))
        .cornerRadius(UIConstants.CornerRadius.medium)
    }
}

// MARK: - 검색 팁 아이템
struct SearchTipItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: UIConstants.Spacing.sm) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(Color(UIConstants.Colors.primaryBlue))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color(UIConstants.Colors.textPrimary))
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(Color(UIConstants.Colors.textSecondary))
            }
        }
    }
}

// MARK: - 검색 로딩 뷰
struct SearchLoadingView: View {
    var body: some View {
        VStack(spacing: UIConstants.Spacing.lg) {
            Spacer()
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color(UIConstants.Colors.primaryBlue)))
                .scaleEffect(1.5)
            
            Text("검색 중...")
                .font(.subheadline)
                .foregroundColor(Color(UIConstants.Colors.textSecondary))
            
            Spacer()
        }
    }
}

// MARK: - 검색 결과 없음 뷰
struct SearchNoResultsView: View {
    let query: String
    let onClearFilters: () -> Void
    let onNewSearch: () -> Void
    
    var body: some View {
        VStack(spacing: UIConstants.Spacing.lg) {
            Spacer()
            
            // 아이콘
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(Color(UIConstants.Colors.secondaryGray))
            
            // 메시지
            VStack(spacing: UIConstants.Spacing.sm) {
                Text("검색 결과가 없습니다")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(UIConstants.Colors.textPrimary))
                
                Text("'\(query)'에 대한 검색 결과를 찾을 수 없습니다")
                    .font(.body)
                    .foregroundColor(Color(UIConstants.Colors.textSecondary))
                    .multilineTextAlignment(.center)
            }
            
            // 제안 액션들
            VStack(spacing: UIConstants.Spacing.md) {
                Button("필터 초기화") {
                    onClearFilters()
                }
                .buttonStyle(AppSecondaryButtonStyle())
                
                Button("새로운 검색") {
                    onNewSearch()
                }
                .buttonStyle(AppSecondaryButtonStyle())
            }
            .padding(.horizontal, UIConstants.Spacing.xl)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - 검색 결과 뷰
struct SearchResultsView: View {
    let cars: [Car]
    let totalResults: Int
    let onCarTap: (Car) -> Void
    let onLoadMore: () -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: UIConstants.Spacing.md) {
                // 결과 헤더
                HStack {
                    Text("검색 결과 \(totalResults)대")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(UIConstants.Colors.textPrimary))
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // 차량 목록
                ForEach(cars) { car in
                    SearchResultCardView(car: car) {
                        onCarTap(car)
                    }
                    .onAppear {
                        // 무한 스크롤
                        if car == cars.last {
                            onLoadMore()
                        }
                    }
                }
                .padding(.horizontal)
                
                // 로딩 더보기
                if cars.count < totalResults {
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(UIConstants.Colors.primaryBlue)))
                        Spacer()
                    }
                    .padding()
                }
            }
        }
    }
}

// MARK: - 검색 결과 카드
struct SearchResultCardView: View {
    let car: Car
    let onTap: () -> Void
    @StateObject private var favoriteService = FavoriteService.shared
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        Button(action: {
            onTap()
            UserBehaviorService.shared.trackAction(.click, carId: car.id, value: "search_result")
        }) {
            HStack(spacing: UIConstants.Spacing.sm) {
                // 차량 이미지
                RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium)
                    .fill(Color(UIConstants.Colors.backgroundColor))
                    .frame(width: 100, height: 75)
                    .overlay(
                        Image(systemName: "car.fill")
                            .foregroundColor(Color(UIConstants.Colors.secondaryGray))
                            .font(.title2)
                    )
                
                // 차량 정보
                VStack(alignment: .leading, spacing: UIConstants.Spacing.xs) {
                    Text(car.model)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color(UIConstants.Colors.textPrimary))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(car.formattedPrice)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(Color(UIConstants.Colors.primaryBlue))
                    
                    HStack(spacing: UIConstants.Spacing.sm) {
                        Text(car.displayYear)
                            .font(.caption)
                            .foregroundColor(Color(UIConstants.Colors.textSecondary))
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(Color(UIConstants.Colors.textSecondary))
                        
                        Text(car.displayMileage)
                            .font(.caption)
                            .foregroundColor(Color(UIConstants.Colors.textSecondary))
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(Color(UIConstants.Colors.textSecondary))
                        
                        Text(car.fuel)
                            .font(.caption)
                            .foregroundColor(Color(UIConstants.Colors.textSecondary))
                    }
                    
                    Text(car.region)
                        .font(.caption)
                        .foregroundColor(Color(UIConstants.Colors.textSecondary))
                }
                
                Spacer()
                
                // 즐겨찾기 버튼
                Button(action: {
                    toggleFavorite()
                }) {
                    Image(systemName: favoriteService.isFavorite(car: car) ? "heart.fill" : "heart")
                        .foregroundColor(favoriteService.isFavorite(car: car) ?
                                       Color(UIConstants.Colors.accentColor) : Color(UIConstants.Colors.secondaryGray))
                        .font(.title3)
                }
            }
            .padding()
            .background(Color(UIConstants.Colors.cardBackground))
            .cornerRadius(UIConstants.CornerRadius.medium)
            .shadow(
                color: Color.black.opacity(UIConstants.Shadow.opacity),
                radius: UIConstants.Shadow.radius,
                x: UIConstants.Shadow.offset.width,
                y: UIConstants.Shadow.offset.height
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func toggleFavorite() {
        favoriteService.toggleFavorite(car: car)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in }
            )
            .store(in: &cancellables) // 이제 정상 작동
    }
}

// MARK: - 프리뷰
struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                SearchView()
            }
            .preferredColorScheme(.light)
            .previewDisplayName("Search View - Light")
            
            NavigationView {
                SearchView()
            }
            .preferredColorScheme(.dark)
            .previewDisplayName("Search View - Dark")
            
            SearchEmptyStateView(
                recentSearches: ["현대", "아반떼", "쏘나타"],
                onRecentSearchTap: { _ in },
                onPopularBrandTap: { _ in }
            )
            .previewDisplayName("Empty State")
            
            SearchLoadingView()
                .previewDisplayName("Loading State")
        }
    }
}
