import SwiftUI
import Combine

// MARK: - 즐겨찾기 뷰
struct FavoriteView: View {
    @StateObject private var favoriteService = FavoriteService.shared
    @State private var selectedSortOption: FavoriteService.SortOption = .newest
    @State private var searchText = ""
    @State private var showingStatistics = false
    @State private var showingExportOptions = false
    @State private var selectedCars: Set<Int> = []
    @State private var isEditMode = false
    @State private var showingCarDetail = false
    @State private var selectedCar: Car?
    @State private var cancellables = Set<AnyCancellable>()
    
    var filteredCars: [Car] {
        let cars = favoriteService.sortedFavorites(by: selectedSortOption)
        
        if searchText.isEmpty {
            return cars
        } else {
            return favoriteService.searchFavorites(query: searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 검색 및 필터 헤더
                FavoriteHeaderView(
                    searchText: $searchText,
                    selectedSortOption: $selectedSortOption,
                    favoriteCount: favoriteService.favoriteCount,
                    onStatistics: { showingStatistics = true },
                    onExport: { showingExportOptions = true }
                )
                
                // 메인 컨텐츠
                if favoriteService.isEmpty {
                    EmptyFavoriteView()
                } else {
                    FavoriteListView(
                        cars: filteredCars,
                        selectedCars: $selectedCars,
                        isEditMode: $isEditMode,
                        onCarTap: { car in
                            selectedCar = car
                            showingCarDetail = true
                        },
                        onCarRemove: { car in
                            removeFavorite(car)
                        }
                    )
                }
            }
            .navigationTitle("즐겨찾기")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            isEditMode.toggle()
                        }) {
                            Label(isEditMode ? "완료" : "편집", systemImage: "pencil")
                        }
                        
                        Button(action: {
                            showingStatistics = true
                        }) {
                            Label("통계 보기", systemImage: "chart.bar")
                        }
                        
                        Button(action: {
                            showingExportOptions = true
                        }) {
                            Label("내보내기", systemImage: "square.and.arrow.up")
                        }
                        
                        if isEditMode && !selectedCars.isEmpty {
                            Button(action: {
                                removeSelectedFavorites()
                            }) {
                                Label("선택 삭제", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingStatistics) {
            FavoriteStatisticsView()
        }
        .sheet(isPresented: $showingExportOptions) {
            FavoriteExportView()
        }
        .sheet(isPresented: $showingCarDetail) {
            if let car = selectedCar {
                CarDetailView(car: car)
            }
        }
        .onAppear {
            loadFavorites()
        }
        .refreshable {
            await refreshFavorites()
        }
    }
    
    private func loadFavorites() {
        favoriteService.loadFavorites()
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    
    @MainActor
    private func refreshFavorites() async {
        _ = try? await favoriteService.refresh().singleOutput()
    }
    
    private func removeFavorite(_ car: Car) {
        favoriteService.removeFavorite(car: car)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    
    private func removeSelectedFavorites() {
        let carsToRemove = favoriteService.favoriteCars.filter { selectedCars.contains($0.id) }
        
        favoriteService.removeMultipleFavorites(cars: carsToRemove)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in
                    selectedCars.removeAll()
                    isEditMode = false
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - 즐겨찾기 헤더 뷰
struct FavoriteHeaderView: View {
    @Binding var searchText: String
    @Binding var selectedSortOption: FavoriteService.SortOption
    let favoriteCount: Int
    let onStatistics: () -> Void
    let onExport: () -> Void
    
    var body: some View {
        VStack(spacing: UIConstants.Spacing.sm) {
            // 검색 바
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color(UIConstants.Colors.secondaryGray))
                    
                    TextField("즐겨찾기 검색...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                    
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
            .padding(.horizontal)
            
            // 정렬 및 액션 버튼들
            HStack {
                // 차량 수 표시
                Text("\(favoriteCount)대")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color(UIConstants.Colors.textSecondary))
                
                Spacer()
                
                // 정렬 옵션
                Menu {
                    ForEach(FavoriteService.SortOption.allCases, id: \.self) { option in
                        Button(action: {
                            selectedSortOption = option
                        }) {
                            HStack {
                                Text(option.displayName)
                                if selectedSortOption == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: UIConstants.Spacing.xs) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text(selectedSortOption.displayName)
                    }
                    .font(.caption)
                    .foregroundColor(Color(UIConstants.Colors.primaryBlue))
                }
                
                // 통계 버튼
                Button(action: onStatistics) {
                    Image(systemName: "chart.bar")
                        .foregroundColor(Color(UIConstants.Colors.primaryBlue))
                }
                
                // 내보내기 버튼
                Button(action: onExport) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(Color(UIConstants.Colors.primaryBlue))
                }
            }
            .padding(.horizontal)
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

// MARK: - 즐겨찾기 목록 뷰
struct FavoriteListView: View {
    let cars: [Car]
    @Binding var selectedCars: Set<Int>
    @Binding var isEditMode: Bool
    let onCarTap: (Car) -> Void
    let onCarRemove: (Car) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: UIConstants.Spacing.sm) {
                ForEach(cars) { car in
                    FavoriteCarCardView(
                        car: car,
                        isSelected: selectedCars.contains(car.id),
                        isEditMode: isEditMode,
                        onTap: {
                            if isEditMode {
                                toggleSelection(car.id)
                            } else {
                                onCarTap(car)
                            }
                        },
                        onRemove: {
                            onCarRemove(car)
                        }
                    )
                }
            }
            .padding()
        }
    }
    
    private func toggleSelection(_ carId: Int) {
        if selectedCars.contains(carId) {
            selectedCars.remove(carId)
        } else {
            selectedCars.insert(carId)
        }
    }
}

// MARK: - 즐겨찾기 차량 카드 뷰
struct FavoriteCarCardView: View {
    let car: Car
    let isSelected: Bool
    let isEditMode: Bool
    let onTap: () -> Void
    let onRemove: () -> Void
    @State private var showingRemoveAlert = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: UIConstants.Spacing.sm) {
                // 선택 체크박스 (편집 모드)
                if isEditMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? Color(UIConstants.Colors.primaryBlue) : Color(UIConstants.Colors.secondaryGray))
                        .font(.title2)
                }
                
                // 차량 이미지
                RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium)
                    .fill(Color(UIConstants.Colors.backgroundColor))
                    .frame(width: 80, height: 60)
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
                    
                    Text(car.formattedPrice)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(Color(UIConstants.Colors.primaryBlue))
                    
                    HStack(spacing: UIConstants.Spacing.sm) {
                        HStack(spacing: 2) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                                .foregroundColor(Color(UIConstants.Colors.secondaryGray))
                            Text(car.displayYear)
                                .font(.caption)
                                .foregroundColor(Color(UIConstants.Colors.textSecondary))
                        }
                        
                        HStack(spacing: 2) {
                            Image(systemName: "speedometer")
                                .font(.caption2)
                                .foregroundColor(Color(UIConstants.Colors.secondaryGray))
                            Text(car.displayMileage)
                                .font(.caption)
                                .foregroundColor(Color(UIConstants.Colors.textSecondary))
                        }
                        
                        HStack(spacing: 2) {
                            Image(systemName: "location")
                                .font(.caption2)
                                .foregroundColor(Color(UIConstants.Colors.secondaryGray))
                            Text(car.region)
                                .font(.caption)
                                .foregroundColor(Color(UIConstants.Colors.textSecondary))
                        }
                    }
                }
                
                Spacer()
                
                // 액션 버튼들
                if !isEditMode {
                    VStack(spacing: UIConstants.Spacing.sm) {
                        Button(action: {
                            showingRemoveAlert = true
                        }) {
                            Image(systemName: "heart.fill")
                                .foregroundColor(Color(UIConstants.Colors.accentColor))
                                .font(.title3)
                        }
                        
                        Button(action: {
                            // 비교하기 기능
                        }) {
                            Image(systemName: "arrow.left.arrow.right")
                                .foregroundColor(Color(UIConstants.Colors.secondaryGray))
                                .font(.title3)
                        }
                    }
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
            .overlay(
                RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium)
                    .stroke(
                        isSelected ? Color(UIConstants.Colors.primaryBlue) : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .alert("즐겨찾기 해제", isPresented: $showingRemoveAlert) {
            Button("취소", role: .cancel) {}
            Button("해제", role: .destructive) {
                onRemove()
            }
        } message: {
            Text("이 차량을 즐겨찾기에서 제거하시겠습니까?")
        }
    }
}

// MARK: - 빈 즐겨찾기 뷰
struct EmptyFavoriteView: View {
    var body: some View {
        VStack(spacing: UIConstants.Spacing.xl) {
            Spacer()
            
            // 아이콘
            Image(systemName: "heart")
                .font(.system(size: 80))
                .foregroundColor(Color(UIConstants.Colors.secondaryGray))
            
            // 메시지
            VStack(spacing: UIConstants.Spacing.sm) {
                Text("즐겨찾기가 비어있습니다")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(UIConstants.Colors.textPrimary))
                
                Text("관심 있는 차량을 즐겨찾기에 추가하면\n언제든 쉽게 확인할 수 있습니다")
                    .font(.body)
                    .foregroundColor(Color(UIConstants.Colors.textSecondary))
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            
            // 액션 버튼
            NavigationLink(destination: HomeView()) {
                HStack {
                    Image(systemName: "plus")
                    Text("차량 둘러보기")
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding()
                .background(Color(UIConstants.Colors.primaryBlue))
                .cornerRadius(UIConstants.CornerRadius.medium)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - 즐겨찾기 통계 뷰
struct FavoriteStatisticsView: View {
    @StateObject private var favoriteService = FavoriteService.shared
    @Environment(\.presentationMode) var presentationMode
    
    private var statistics: FavoriteStatistics {
        return favoriteService.statistics
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: UIConstants.Spacing.lg) {
                    // 전체 통계
                    OverallStatsView(statistics: statistics)
                    
                    // 브랜드 분포
                    if !statistics.brandDistribution.isEmpty {
                        BrandDistributionView(distribution: statistics.brandDistribution)
                    }
                    
                    // 연료 타입 분포
                    if !statistics.fuelTypeDistribution.isEmpty {
                        FuelTypeDistributionView(distribution: statistics.fuelTypeDistribution)
                    }
                    
                    // 가격대 분포
                    if !statistics.priceRangeDistribution.isEmpty {
                        PriceRangeDistributionView(distribution: statistics.priceRangeDistribution)
                    }
                    
                    // 추천 인사이트
                    RecommendationInsightView(statistics: statistics)
                }
                .padding()
            }
            .navigationTitle("즐겨찾기 통계")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("닫기") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 전체 통계 뷰
struct OverallStatsView: View {
    let statistics: FavoriteStatistics
    
    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.md) {
            Text("전체 통계")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: UIConstants.Spacing.lg) {
                StatItemView(
                    title: "총 차량",
                    value: "\(statistics.totalCount)대",
                    icon: "car.fill",
                    color: Color(UIConstants.Colors.primaryBlue)
                )
                
                StatItemView(
                    title: "평균 가격",
                    value: statistics.formattedAveragePrice,
                    icon: "wonsign.circle.fill",
                    color: Color(UIConstants.Colors.successColor)
                )
            }
            
            if let topBrand = statistics.topBrand {
                HStack(spacing: UIConstants.Spacing.lg) {
                    StatItemView(
                        title: "선호 브랜드",
                        value: topBrand,
                        icon: "star.fill",
                        color: Color(UIConstants.Colors.warningColor)
                    )
                    
                    if let topFuel = statistics.topFuelType {
                        StatItemView(
                            title: "선호 연료",
                            value: topFuel,
                            icon: "fuelpump.fill",
                            color: Color(UIConstants.Colors.accentColor)
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(UIConstants.Colors.cardBackground))
        .cornerRadius(UIConstants.CornerRadius.medium)
    }
}

// MARK: - 통계 아이템 뷰
struct StatItemView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: UIConstants.Spacing.xs) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(Color(UIConstants.Colors.textPrimary))
            
            Text(title)
                .font(.caption)
                .foregroundColor(Color(UIConstants.Colors.textSecondary))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 브랜드 분포 뷰
struct BrandDistributionView: View {
    let distribution: [String: Int]
    
    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.md) {
            Text("브랜드별 분포")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: UIConstants.Spacing.sm) {
                ForEach(Array(distribution.sorted { $0.value > $1.value }), id: \.key) { brand, count in
                    DistributionBarView(
                        label: brand,
                        count: count,
                        total: distribution.values.reduce(0, +),
                        color: Color(UIConstants.Colors.primaryBlue)
                    )
                }
            }
        }
        .padding()
        .background(Color(UIConstants.Colors.cardBackground))
        .cornerRadius(UIConstants.CornerRadius.medium)
    }
}

// MARK: - 연료 타입 분포 뷰
struct FuelTypeDistributionView: View {
    let distribution: [String: Int]
    
    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.md) {
            Text("연료별 분포")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: UIConstants.Spacing.sm) {
                ForEach(Array(distribution.sorted { $0.value > $1.value }), id: \.key) { fuel, count in
                    DistributionBarView(
                        label: fuel,
                        count: count,
                        total: distribution.values.reduce(0, +),
                        color: Color(UIConstants.Colors.successColor)
                    )
                }
            }
        }
        .padding()
        .background(Color(UIConstants.Colors.cardBackground))
        .cornerRadius(UIConstants.CornerRadius.medium)
    }
}

// MARK: - 가격대 분포 뷰
struct PriceRangeDistributionView: View {
    let distribution: [String: Int]
    
    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.md) {
            Text("가격대별 분포")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: UIConstants.Spacing.sm) {
                ForEach(Array(distribution.sorted { $0.value > $1.value }), id: \.key) { priceRange, count in
                    DistributionBarView(
                        label: priceRange,
                        count: count,
                        total: distribution.values.reduce(0, +),
                        color: Color(UIConstants.Colors.warningColor)
                    )
                }
            }
        }
        .padding()
        .background(Color(UIConstants.Colors.cardBackground))
        .cornerRadius(UIConstants.CornerRadius.medium)
    }
}

// MARK: - 분포 바 뷰
struct DistributionBarView: View {
    let label: String
    let count: Int
    let total: Int
    let color: Color
    
    private var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.xs) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(Color(UIConstants.Colors.textPrimary))
                
                Spacer()
                
                Text("\(count)대 (\(Int(percentage * 100))%)")
                    .font(.caption)
                    .foregroundColor(Color(UIConstants.Colors.textSecondary))
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(UIConstants.Colors.backgroundColor))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * percentage, height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - 추천 인사이트 뷰
struct RecommendationInsightView: View {
    let statistics: FavoriteStatistics
    
    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.md) {
            Text("추천 인사이트")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: UIConstants.Spacing.sm) {
                if let topBrand = statistics.topBrand {
                    InsightItemView(
                        icon: "lightbulb.fill",
                        title: "브랜드 선호도",
                        description: "\(topBrand) 브랜드를 선호하시는군요! 해당 브랜드의 신차 출시 정보를 확인해보세요."
                    )
                }
                
                if statistics.totalCount >= 5 {
                    InsightItemView(
                        icon: "brain.head.profile",
                        title: "AI 추천 활용",
                        description: "충분한 즐겨찾기 데이터가 있어 AI 개인화 추천의 정확도가 높습니다."
                    )
                } else {
                    InsightItemView(
                        icon: "plus.circle.fill",
                        title: "데이터 수집",
                        description: "더 많은 차량을 즐겨찾기에 추가하면 더 정확한 AI 추천을 받을 수 있습니다."
                    )
                }
                
                if let averagePrice = statistics.averagePrice {
                    let budget = averagePrice > 3000 ? "고급형" : averagePrice > 1500 ? "중급형" : "실용형"
                    InsightItemView(
                        icon: "creditcard.fill",
                        title: "예산 분석",
                        description: "\(budget) 차량을 선호하시는 것 같습니다. 해당 가격대의 최신 모델들을 확인해보세요."
                    )
                }
            }
        }
        .padding()
        .background(Color(UIConstants.Colors.cardBackground))
        .cornerRadius(UIConstants.CornerRadius.medium)
    }
}

// MARK: - 인사이트 아이템 뷰
struct InsightItemView: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: UIConstants.Spacing.sm) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(Color(UIConstants.Colors.primaryBlue))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: UIConstants.Spacing.xs) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color(UIConstants.Colors.textPrimary))
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(Color(UIConstants.Colors.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - 즐겨찾기 내보내기 뷰
struct FavoriteExportView: View {
    @StateObject private var favoriteService = FavoriteService.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var showingShareSheet = false
    @State private var exportData: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: UIConstants.Spacing.lg) {
                // 내보내기 옵션들
                VStack(spacing: UIConstants.Spacing.md) {
                    ExportOptionView(
                        title: "텍스트로 내보내기",
                        description: "즐겨찾기 목록을 텍스트 형태로 내보냅니다",
                        icon: "doc.text.fill",
                        action: exportAsText
                    )
                    
                    ExportOptionView(
                        title: "JSON으로 내보내기",
                        description: "구조화된 데이터 형태로 내보냅니다",
                        icon: "doc.badge.gearshape.fill",
                        action: exportAsJSON
                    )
                    
                    ExportOptionView(
                        title: "공유하기",
                        description: "다른 앱으로 즐겨찾기 목록을 공유합니다",
                        icon: "square.and.arrow.up.fill",
                        action: shareList
                    )
                }
                
                Spacer()
                
                // 내보내기 정보
                VStack(alignment: .leading, spacing: UIConstants.Spacing.sm) {
                    Text("내보내기 정보")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("• 총 \(favoriteService.favoriteCount)대의 차량이 포함됩니다")
                        .font(.caption)
                        .foregroundColor(Color(UIConstants.Colors.textSecondary))
                    
                    Text("• 차량 모델, 가격, 연식, 주행거리 등의 정보가 포함됩니다")
                        .font(.caption)
                        .foregroundColor(Color(UIConstants.Colors.textSecondary))
                    
                    Text("• 개인정보는 포함되지 않습니다")
                        .font(.caption)
                        .foregroundColor(Color(UIConstants.Colors.textSecondary))
                }
                .padding()
                .background(Color(UIConstants.Colors.backgroundColor))
                .cornerRadius(UIConstants.CornerRadius.medium)
            }
            .padding()
            .navigationTitle("내보내기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("닫기") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [exportData])
        }
    }
    
    private func exportAsText() {
        exportData = favoriteService.exportFavoritesToText()
        showingShareSheet = true
    }
    
    private func exportAsJSON() {
        if let jsonData = favoriteService.exportFavoritesToJSON(),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            exportData = jsonString
            showingShareSheet = true
        }
    }
    
    private func shareList() {
        exportData = favoriteService.exportFavoritesToText()
        showingShareSheet = true
    }
}

// MARK: - 내보내기 옵션 뷰
struct ExportOptionView: View {
    let title: String
    let description: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: UIConstants.Spacing.md) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(Color(UIConstants.Colors.primaryBlue))
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: UIConstants.Spacing.xs) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color(UIConstants.Colors.textPrimary))
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(Color(UIConstants.Colors.textSecondary))
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color(UIConstants.Colors.secondaryGray))
            }
            .padding()
            .background(Color(UIConstants.Colors.cardBackground))
            .cornerRadius(UIConstants.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium)
                    .stroke(Color(UIConstants.Colors.secondaryGray).opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - ShareSheet (UIActivityViewController를 위한 UIViewControllerRepresentable)
//struct ShareSheet: UIViewControllerRepresentable {
//    let items: [Any]
//    
//    func makeUIViewController(context: Context) -> UIActivityViewController {
//        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
//        return controller
//    }
//    
//    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
//}

// MARK: - 프리뷰
struct FavoriteView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            FavoriteView()
                .preferredColorScheme(.light)
                .previewDisplayName("Favorite View - Light")
            
            FavoriteView()
                .preferredColorScheme(.dark)
                .previewDisplayName("Favorite View - Dark")
            
            EmptyFavoriteView()
                .previewDisplayName("Empty State")
            
            FavoriteStatisticsView()
                .previewDisplayName("Statistics View")
        }
    }
}
