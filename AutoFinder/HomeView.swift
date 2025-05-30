import SwiftUI
import Combine

// MARK: - HomeView
struct HomeView: View {
    @StateObject private var carService = CarService.shared
    @StateObject private var favoriteService = FavoriteService.shared
    @StateObject private var recommendationService = RecommendationService.shared
    @State private var viewModel = HomeViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                SearchHeaderView(viewModel: $viewModel)
                
                ScrollView {
                    LazyVStack(spacing: UIConstants.Spacing.md) {
                        if !recommendationService.recommendations.isEmpty {
                            RecommendationSectionView()
                        }
                        
                        CarListSectionView(
                            cars: carService.cars,
                            isLoading: carService.isLoading,
                            hasMorePages: carService.hasMorePages,
                            onCarTap: viewModel.selectCar,
                            onLoadMore: loadMoreCars
                        )
                    }
                    .padding(.horizontal)
                }
                .refreshable {
                    await refreshData()
                }
            }
            .navigationTitle("AutoFinder")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.showingFilters = true }) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(Color(UIConstants.Colors.primaryBlue))
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingFilters) {
                FilterView(filters: $viewModel.filterParams) { newFilters in
                    carService.applyFilters(newFilters)
                }
            }
            .sheet(isPresented: $viewModel.showingCarDetail) {
                if let car = viewModel.selectedCar {
                    CarDetailView(car: car)
                }
            }
            .onAppear {
                loadInitialData()
            }
        }
    }
    
    private func loadInitialData() {
        Publishers.Zip(
            carService.loadCars(),
            recommendationService.loadRecommendations()
        )
        .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
        .store(in: &viewModel.cancellables)
    }
    
    private func loadMoreCars() {
        carService.loadMoreCars()
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &viewModel.cancellables)
    }
    
    @MainActor
    private func refreshData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                _ = try? await carService.refresh().singleOutput()
            }
            group.addTask {
                _ = try? await recommendationService.refresh().singleOutput()
            }
        }
    }
}

// MARK: - HomeViewModel
@MainActor
class HomeViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var showingFilters = false
    @Published var showingCarDetail = false
    @Published var selectedCar: Car?
    @Published var filterParams = CarService.shared.currentFilters
    
    var cancellables = Set<AnyCancellable>()
    
    func selectCar(_ car: Car) {
        selectedCar = car
        showingCarDetail = true
    }
    
    func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        CarService.shared.searchCars(query: searchText)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
    }
}

// MARK: - SearchHeaderView
struct SearchHeaderView: View {
    @Binding var viewModel: HomeViewModel
    
    var body: some View {
        VStack(spacing: UIConstants.Spacing.sm) {
            HStack(spacing: UIConstants.Spacing.sm) {
                SearchBarView(
                    searchText: $viewModel.searchText,
                    onSearchCommit: viewModel.performSearch
                )
                
                FilterButton {
                    viewModel.showingFilters = true
                }
            }
            .padding(.horizontal)
            
            FilterStatusView()
        }
        .background(Color(UIConstants.Colors.cardBackground))
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - SearchBarView
private struct SearchBarView: View {
    @Binding var searchText: String
    let onSearchCommit: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color(UIConstants.Colors.secondaryGray))
            
            TextField("차량 모델, 브랜드 검색...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .onSubmit(onSearchCommit)
            
            if !searchText.isEmpty {
                Button("취소") {
                    searchText = ""
                }
                .foregroundColor(Color(UIConstants.Colors.primaryBlue))
                .font(.caption)
            }
        }
        .padding(UIConstants.Spacing.sm)
        .background(Color(UIConstants.Colors.backgroundColor))
        .cornerRadius(UIConstants.CornerRadius.medium)
    }
}

// MARK: - FilterButton
private struct FilterButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "slider.horizontal.3")
                .foregroundColor(Color(UIConstants.Colors.primaryBlue))
                .padding(UIConstants.Spacing.sm)
                .background(Color(UIConstants.Colors.backgroundColor))
                .cornerRadius(UIConstants.CornerRadius.medium)
        }
    }
}

// MARK: - FilterStatusView
struct FilterStatusView: View {
    @StateObject private var carService = CarService.shared
    
    var body: some View {
        if carService.currentFilters.hasActiveFilters {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: UIConstants.Spacing.xs) {
                    ForEach(activeFilterChips, id: \.title) { chip in
                        FilterChipView(title: chip.title, onRemove: chip.action)
                    }
                    
                    ClearAllFiltersButton()
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var activeFilterChips: [FilterChip] {
        let filters = carService.currentFilters
        var chips: [FilterChip] = []
        
        if let model = filters.model, !model.isEmpty {
            chips.append(FilterChip(title: "모델: \(model)") {
                updateFilter { $0.model = nil }
            })
        }
        
        if let fuel = filters.fuel, !fuel.isEmpty {
            chips.append(FilterChip(title: "연료: \(fuel)") {
                updateFilter { $0.fuel = nil }
            })
        }
        
        if let region = filters.region, !region.isEmpty {
            chips.append(FilterChip(title: "지역: \(region)") {
                updateFilter { $0.region = nil }
            })
        }
        
        if filters.minPrice != nil || filters.maxPrice != nil {
            let priceText = formatPriceRange(min: filters.minPrice, max: filters.maxPrice)
            chips.append(FilterChip(title: "가격: \(priceText)") {
                updateFilter {
                    $0.minPrice = nil
                    $0.maxPrice = nil
                }
            })
        }
        
        return chips
    }
    
    private func updateFilter(_ update: (inout CarFilterParams) -> Void) {
        var newFilters = carService.currentFilters
        update(&newFilters)
        carService.applyFilters(newFilters)
    }
    
    private func formatPriceRange(min: Int?, max: Int?) -> String {
        switch (min, max) {
        case let (min?, max?): return "\(min)-\(max)만원"
        case let (min?, nil): return "\(min)만원 이상"
        case let (nil, max?): return "\(max)만원 이하"
        case (nil, nil): return ""
        }
    }
}

// MARK: - FilterChip Model
private struct FilterChip {
    let title: String
    let action: () -> Void
}

// MARK: - FilterChipView
struct FilterChipView: View {
    let title: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: UIConstants.Spacing.xs) {
            Text(title)
                .font(.caption)
                .foregroundColor(Color(UIConstants.Colors.primaryBlue))
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundColor(Color(UIConstants.Colors.primaryBlue))
            }
        }
        .padding(.horizontal, UIConstants.Spacing.sm)
        .padding(.vertical, UIConstants.Spacing.xs)
        .background(Color(UIConstants.Colors.primaryBlue).opacity(0.1))
        .cornerRadius(UIConstants.CornerRadius.small)
    }
}

// MARK: - ClearAllFiltersButton
private struct ClearAllFiltersButton: View {
    var body: some View {
        Button("모두 지우기") {
            CarService.shared.resetFilters()
        }
        .font(.caption)
        .foregroundColor(Color(UIConstants.Colors.accentColor))
        .padding(.horizontal, UIConstants.Spacing.sm)
        .padding(.vertical, UIConstants.Spacing.xs)
    }
}

// MARK: - RecommendationSectionView
struct RecommendationSectionView: View {
    @StateObject private var recommendationService = RecommendationService.shared
    @State private var showingAllRecommendations = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.sm) {
            SectionHeader(
                title: "AI 추천",
                subtitle: "당신의 취향에 맞는 차량",
                actionTitle: "더보기"
            ) {
                showingAllRecommendations = true
            }
            
            RecommendationCardsScrollView(
                recommendations: Array(recommendationService.recommendations.prefix(5))
            ) {
                showingAllRecommendations = true
            }
            
            if recommendationService.aiStatus != .available {
                AIStatusBannerView(status: recommendationService.aiStatus)
            }
        }
        .sheet(isPresented: $showingAllRecommendations) {
            RecommendationView()
        }
    }
}

// MARK: - SectionHeader
private struct SectionHeader: View {
    let title: String
    let subtitle: String
    let actionTitle: String
    let action: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(UIConstants.Colors.textPrimary))
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(Color(UIConstants.Colors.textSecondary))
            }
            
            Spacer()
            
            Button(actionTitle) {
                action()
            }
            .font(.caption)
            .foregroundColor(Color(UIConstants.Colors.primaryBlue))
        }
    }
}

// MARK: - RecommendationCardsScrollView
private struct RecommendationCardsScrollView: View {
    let recommendations: [RecommendedCar]
    let onTap: () -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: UIConstants.Spacing.sm) {
                ForEach(Array(recommendations.enumerated()), id: \.element.id) { index, recommendation in
                    RecommendationCardView(
                        recommendation: recommendation,
                        rank: index + 1,
                        onTap: onTap
                    )
                    .frame(width: 280)
                }
            }
            .padding(.horizontal, 1) // 그림자 클리핑 방지
        }
    }
}

// MARK: - AIStatusBannerView
struct AIStatusBannerView: View {
    let status: AIServiceStatus
    
    var body: some View {
        HStack {
            Image(systemName: status.isAvailable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(status.isAvailable ?
                    Color(UIConstants.Colors.successColor) :
                    Color(UIConstants.Colors.warningColor))
            
            Text(status.displayText)
                .font(.caption)
                .foregroundColor(Color(UIConstants.Colors.textSecondary))
            
            Spacer()
        }
        .padding(UIConstants.Spacing.sm)
        .background(
            (status.isAvailable ?
                Color(UIConstants.Colors.successColor) :
                Color(UIConstants.Colors.warningColor)
            ).opacity(0.1)
        )
        .cornerRadius(UIConstants.CornerRadius.small)
    }
}

// MARK: - CarListSectionView
struct CarListSectionView: View {
    let cars: [Car]
    let isLoading: Bool
    let hasMorePages: Bool
    let onCarTap: (Car) -> Void
    let onLoadMore: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.sm) {
            CarListHeader(carCount: cars.count)
            
            if cars.isEmpty && !isLoading {
                EmptyCarListView()
            } else {
                CarListContent(
                    cars: cars,
                    isLoading: isLoading,
                    hasMorePages: hasMorePages,
                    onCarTap: onCarTap,
                    onLoadMore: onLoadMore
                )
            }
        }
    }
}

// MARK: - CarListHeader
private struct CarListHeader: View {
    let carCount: Int
    
    var body: some View {
        HStack {
            Text("차량 목록")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(Color(UIConstants.Colors.textPrimary))
            
            Spacer()
            
            if carCount > 0 {
                Text("\(carCount)대")
                    .font(.caption)
                    .foregroundColor(Color(UIConstants.Colors.textSecondary))
            }
        }
    }
}

// MARK: - EmptyCarListView
private struct EmptyCarListView: View {
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        EmptyStateView(
            title: "검색 결과가 없습니다",
            message: "다른 검색 조건을 시도해보세요",
            systemImage: "magnifyingglass",
            actionTitle: "필터 초기화"
        ) {
            CarService.shared.resetFilters()
                .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
                .store(in: &cancellables)
        }
        .padding(.vertical, UIConstants.Spacing.xl)
    }
}

// MARK: - CarListContent
private struct CarListContent: View {
    let cars: [Car]
    let isLoading: Bool
    let hasMorePages: Bool
    let onCarTap: (Car) -> Void
    let onLoadMore: () -> Void
    
    var body: some View {
        LazyVStack(spacing: UIConstants.Spacing.sm) {
            ForEach(cars) { car in
                CarCardView(car: car) {
                    onCarTap(car)
                }
                .onAppear {
                    if car == cars.last && hasMorePages {
                        onLoadMore()
                    }
                }
            }
            
            LoadingFooterView(isLoading: isLoading, hasMorePages: hasMorePages, isEmpty: cars.isEmpty)
        }
    }
}

// MARK: - LoadingFooterView
private struct LoadingFooterView: View {
    let isLoading: Bool
    let hasMorePages: Bool
    let isEmpty: Bool
    
    var body: some View {
        Group {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(UIConstants.Colors.primaryBlue)))
                    Spacer()
                }
                .padding()
            } else if !hasMorePages && !isEmpty {
                Text("모든 차량을 확인했습니다")
                    .font(.caption)
                    .foregroundColor(Color(UIConstants.Colors.textSecondary))
                    .padding()
            }
        }
    }
}

// MARK: - CarCardView
struct CarCardView: View {
    let car: Car
    let onTap: () -> Void
    @StateObject private var favoriteService = FavoriteService.shared
    @State private var showingActionSheet = false
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        Button(action: {
            onTap()
            UserBehaviorService.shared.trackAction(.view, carId: car.id)
        }) {
            VStack(spacing: 0) {
                CarImageView(car: car, isFavorite: favoriteService.isFavorite(car: car)) {
                    toggleFavorite()
                }
                
                CarInfoView(car: car) {
                    showingActionSheet = true
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .background(Color(UIConstants.Colors.cardBackground))
        .cornerRadius(UIConstants.CornerRadius.medium)
        .shadow(
            color: Color.black.opacity(UIConstants.Shadow.opacity),
            radius: UIConstants.Shadow.radius,
            x: UIConstants.Shadow.offset.width,
            y: UIConstants.Shadow.offset.height
        )
        .actionSheet(isPresented: $showingActionSheet) {
            CarActionSheet(car: car, isFavorite: favoriteService.isFavorite(car: car)) {
                toggleFavorite()
            }()
        }
    }
    
    private func toggleFavorite() {
        favoriteService.toggleFavorite(car: car)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
    }
}

// MARK: - CarImageView
private struct CarImageView: View {
    let car: Car
    let isFavorite: Bool
    let onFavoriteToggle: () -> Void
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium)
                .fill(Color(UIConstants.Colors.backgroundColor))
                .frame(height: 200)
            
            Image(systemName: "car.fill")
                .font(.system(size: 60))
                .foregroundColor(Color(UIConstants.Colors.secondaryGray))
            
            if car.isNewCar {
                NewCarBadge()
            }
            
            FavoriteButton(isFavorite: isFavorite, action: onFavoriteToggle)
        }
    }
}

// MARK: - NewCarBadge
private struct NewCarBadge: View {
    var body: some View {
        VStack {
            HStack {
                Text("NEW")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, UIConstants.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(Color(UIConstants.Colors.accentColor))
                    .cornerRadius(4)
                
                Spacer()
            }
            Spacer()
        }
        .padding(UIConstants.Spacing.sm)
    }
}

// MARK: - FavoriteButton
private struct FavoriteButton: View {
    let isFavorite: Bool
    let action: () -> Void
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                Button(action: action) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(isFavorite ? Color(UIConstants.Colors.accentColor) : .white)
                        .font(.title2)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                }
            }
            Spacer()
        }
        .padding(UIConstants.Spacing.sm)
    }
}

// MARK: - CarInfoView
private struct CarInfoView: View {
    let car: Car
    let onMoreAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.xs) {
            Text(car.model)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(Color(UIConstants.Colors.textPrimary))
                .lineLimit(1)
            
            Text(car.formattedPrice)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color(UIConstants.Colors.primaryBlue))
            
            CarSpecsView(car: car)
            CarLocationView(car: car, onMoreAction: onMoreAction)
        }
        .padding()
    }
}

// MARK: - CarSpecsView
private struct CarSpecsView: View {
    let car: Car
    
    var body: some View {
        HStack(spacing: UIConstants.Spacing.sm) {
            InfoChipView(icon: "calendar", text: car.displayYear)
            InfoChipView(icon: "speedometer", text: car.displayMileage)
            InfoChipView(icon: "fuelpump.fill", text: car.fuel)
        }
    }
}

// MARK: - CarLocationView
private struct CarLocationView: View {
    let car: Car
    let onMoreAction: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "location.fill")
                .font(.caption)
                .foregroundColor(Color(UIConstants.Colors.secondaryGray))
            
            Text(car.region)
                .font(.caption)
                .foregroundColor(Color(UIConstants.Colors.textSecondary))
            
            Spacer()
            
            Button(action: onMoreAction) {
                Image(systemName: "ellipsis")
                    .foregroundColor(Color(UIConstants.Colors.secondaryGray))
            }
        }
    }
}

// MARK: - InfoChipView
struct InfoChipView: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(Color(UIConstants.Colors.secondaryGray))
            
            Text(text)
                .font(.caption2)
                .foregroundColor(Color(UIConstants.Colors.textSecondary))
        }
        .padding(.horizontal, UIConstants.Spacing.xs)
        .padding(.vertical, 2)
        .background(Color(UIConstants.Colors.backgroundColor))
        .cornerRadius(UIConstants.CornerRadius.small)
    }
}

// MARK: - CarActionSheet
private struct CarActionSheet {
    let car: Car
    let isFavorite: Bool
    let onFavoriteToggle: () -> Void
    
    func callAsFunction() -> ActionSheet {
        ActionSheet(
            title: Text(car.model),
            message: Text("원하는 작업을 선택하세요"),
            buttons: [
                .default(Text(isFavorite ? "즐겨찾기 해제" : "즐겨찾기 추가")) {
                    onFavoriteToggle()
                },
                .default(Text("유사한 차량 보기")) {
                    UserBehaviorService.shared.trackAction(.compare, carId: car.id)
                },
                .default(Text("공유하기")) {
                    UserBehaviorService.shared.trackAction(.share, carId: car.id)
                },
                .cancel(Text("취소"))
            ]
        )
    }
}

// MARK: - Previews
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            HomeView()
                .preferredColorScheme(.light)
                .previewDisplayName("Home View - Light")
            
            HomeView()
                .preferredColorScheme(.dark)
                .previewDisplayName("Home View - Dark")
        }
    }
}
