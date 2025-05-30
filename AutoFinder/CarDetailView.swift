import SwiftUI
import Combine

// MARK: - 차량 상세 뷰
struct CarDetailView: View {
    let car: Car
    @StateObject private var favoriteService = FavoriteService.shared
    @StateObject private var carService = CarService.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var similarCars: [Car] = []
    @State private var priceAnalysis: [PriceAnalysis] = []
    @State private var isLoading = false
    @State private var showingShareSheet = false
    @State private var showingPriceAnalysis = false
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // 차량 이미지 영역
                    CarImageSectionView(car: car)
                    
                    // 기본 정보 영역
                    CarBasicInfoView(car: car)
                    
                    // 액션 버튼들
                    ActionButtonsView(
                        car: car,
                        onFavoriteToggle: toggleFavorite,
                        onShare: shareCar,
                        onContact: contactDealer,
                        onPriceAnalysis: showPriceAnalysis
                    )
                    
                    // 상세 스펙 정보
                    CarSpecificationView(car: car)
                    
                    // 가격 분석 섹션
                    if !priceAnalysis.isEmpty {
                        PriceAnalysisSectionView(
                            analysis: priceAnalysis,
                            currentPrice: car.price
                        )
                    }
                    
                    // 유사한 차량 섹션
                    if !similarCars.isEmpty {
                        SimilarCarsSectionView(cars: similarCars)
                    }
                    
                    // 하단 여백
                    Color.clear.frame(height: 100)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("닫기") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingShareSheet = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .onAppear {
            loadCarDetails()
            trackCarView()
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [shareText])
        }
        .sheet(isPresented: $showingPriceAnalysis) {
            PriceAnalysisDetailView(
                analysis: priceAnalysis,
                carModel: car.model,
                currentPrice: car.price
            )
        }
    }
    
    private func loadCarDetails() {
        isLoading = true
        
        // 유사한 차량 로드
        carService.getSimilarCars(carId: car.id, limit: 5)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("유사한 차량 로드 실패: \(error)")
                    }
                },
                receiveValue: { cars in
                    self.similarCars = cars
                }
            )
            .store(in: &cancellables)
        
        // 가격 분석 로드
        carService.getPriceAnalysis(model: extractModelName(car.model))
            .sink(
                receiveCompletion: { completion in
                    self.isLoading = false
                    if case .failure(let error) = completion {
                        print("가격 분석 로드 실패: \(error)")
                    }
                },
                receiveValue: { analysis in
                    self.priceAnalysis = analysis
                }
            )
            .store(in: &cancellables)
    }
    
    private func trackCarView() {
        UserBehaviorService.shared.trackAction(.detailView, carId: car.id)
    }
    
    private func toggleFavorite() {
        favoriteService.toggleFavorite(car: car)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    
    private func shareCar() {
        UserBehaviorService.shared.trackAction(.share, carId: car.id)
        showingShareSheet = true
    }
    
    private func contactDealer() {
        UserBehaviorService.shared.trackAction(.contact, carId: car.id)
        // 딜러 연락 로직 구현
    }
    
    private func showPriceAnalysis() {
        UserBehaviorService.shared.trackAction(.view, carId: car.id, value: "price_analysis")
        showingPriceAnalysis = true
    }
    
    private var shareText: String {
        return """
        \(car.model)
        가격: \(car.formattedPrice)
        연식: \(car.displayYear)
        주행거리: \(car.displayMileage)
        
        AutoFinder에서 확인하세요!
        """
    }
    
    private func extractModelName(_ fullModel: String) -> String {
        return fullModel.components(separatedBy: " ").first ?? fullModel
    }
}

// MARK: - 차량 이미지 섹션
struct CarImageSectionView: View {
    let car: Car
    @State private var currentImageIndex = 0
    
    // 임시 이미지 URLs (실제로는 car.imageUrl 사용)
    private let imageURLs = [
        "car_image_1", "car_image_2", "car_image_3"
    ]
    
    var body: some View {
        ZStack {
            // 메인 이미지
            TabView(selection: $currentImageIndex) {
                ForEach(0..<3, id: \.self) { index in
                    ZStack {
                        Color(UIConstants.Colors.backgroundColor)
                        
                        Image(systemName: "car.fill")
                            .font(.system(size: 80))
                            .foregroundColor(Color(UIConstants.Colors.secondaryGray))
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
            .frame(height: 250)
            
            // 새 차량 배지
            if car.isNewCar {
                VStack {
                    HStack {
                        Text("NEW")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, UIConstants.Spacing.sm)
                            .padding(.vertical, UIConstants.Spacing.xs)
                            .background(Color(UIConstants.Colors.accentColor))
                            .cornerRadius(UIConstants.CornerRadius.small)
                        
                        Spacer()
                    }
                    
                    Spacer()
                }
                .padding()
            }
        }
    }
}

// MARK: - 기본 정보 뷰
struct CarBasicInfoView: View {
    let car: Car
    
    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.md) {
            // 모델명 및 브랜드
            VStack(alignment: .leading, spacing: UIConstants.Spacing.xs) {
                Text(car.brandName)
                    .font(.subheadline)
                    .foregroundColor(Color(UIConstants.Colors.textSecondary))
                
                Text(car.modelName)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(Color(UIConstants.Colors.textPrimary))
            }
            
            // 가격
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("판매가격")
                        .font(.caption)
                        .foregroundColor(Color(UIConstants.Colors.textSecondary))
                    
                    Text(car.formattedPrice)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(Color(UIConstants.Colors.primaryBlue))
                }
                
                Spacer()
                
                // 가격 카테고리
                Text(car.priceCategory)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Color(UIConstants.Colors.primaryBlue))
                    .padding(.horizontal, UIConstants.Spacing.sm)
                    .padding(.vertical, UIConstants.Spacing.xs)
                    .background(Color(UIConstants.Colors.primaryBlue).opacity(0.1))
                    .cornerRadius(UIConstants.CornerRadius.small)
            }
            
            // 기본 스펙 정보
            HStack(spacing: UIConstants.Spacing.lg) {
                SpecItemView(
                    icon: "calendar",
                    title: "연식",
                    value: car.displayYear
                )
                
                SpecItemView(
                    icon: "speedometer",
                    title: "주행거리",
                    value: car.displayMileage
                )
                
                SpecItemView(
                    icon: "fuelpump.fill",
                    title: "연료",
                    value: car.fuel
                )
            }
        }
        .padding()
        .background(Color(UIConstants.Colors.cardBackground))
    }
}

// MARK: - 스펙 아이템 뷰
struct SpecItemView: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: UIConstants.Spacing.xs) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(Color(UIConstants.Colors.primaryBlue))
            
            Text(title)
                .font(.caption)
                .foregroundColor(Color(UIConstants.Colors.textSecondary))
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color(UIConstants.Colors.textPrimary))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 액션 버튼들
struct ActionButtonsView: View {
    let car: Car
    let onFavoriteToggle: () -> Void
    let onShare: () -> Void
    let onContact: () -> Void
    let onPriceAnalysis: () -> Void
    
    @StateObject private var favoriteService = FavoriteService.shared
    
    var body: some View {
        VStack(spacing: UIConstants.Spacing.md) {
            // 주요 액션 버튼들
            HStack(spacing: UIConstants.Spacing.sm) {
                // 즐겨찾기 버튼
                ActionButton(
                    title: favoriteService.isFavorite(car: car) ? "즐겨찾기 해제" : "즐겨찾기",
                    icon: favoriteService.isFavorite(car: car) ? "heart.fill" : "heart",
                    color: favoriteService.isFavorite(car: car) ?
                           Color(UIConstants.Colors.accentColor) : Color(UIConstants.Colors.primaryBlue),
                    action: onFavoriteToggle
                )
                
                // 공유 버튼
                ActionButton(
                    title: "공유",
                    icon: "square.and.arrow.up",
                    color: Color(UIConstants.Colors.secondaryGray),
                    action: onShare
                )
            }
            
            // 연락 및 분석 버튼
            HStack(spacing: UIConstants.Spacing.sm) {
                // 딜러 연락 버튼
                Button(action: onContact) {
                    HStack {
                        Image(systemName: "phone.fill")
                            .font(.title3)
                        
                        Text("딜러 연락하기")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(UIConstants.Colors.successColor))
                    .cornerRadius(UIConstants.CornerRadius.medium)
                }
                
                // 가격 분석 버튼
                Button(action: onPriceAnalysis) {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.title3)
                        
                        Text("가격 분석")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(Color(UIConstants.Colors.primaryBlue))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(UIConstants.Colors.primaryBlue).opacity(0.1))
                    .cornerRadius(UIConstants.CornerRadius.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium)
                            .stroke(Color(UIConstants.Colors.primaryBlue), lineWidth: 1)
                    )
                }
            }
        }
        .padding()
        .background(Color(UIConstants.Colors.cardBackground))
    }
}

// MARK: - 액션 버튼
struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: UIConstants.Spacing.xs) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, UIConstants.Spacing.sm)
            .background(color.opacity(0.1))
            .cornerRadius(UIConstants.CornerRadius.medium)
        }
    }
}

// MARK: - 상세 스펙 뷰
struct CarSpecificationView: View {
    let car: Car
    
    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.md) {
            // 섹션 헤더
            Text("상세 정보")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(Color(UIConstants.Colors.textPrimary))
            
            // 스펙 리스트
            VStack(spacing: UIConstants.Spacing.sm) {
                SpecificationRow(title: "차종", value: car.carType ?? "승용차")
                SpecificationRow(title: "연식", value: car.displayYear)
                SpecificationRow(title: "주행거리", value: car.displayMileage)
                SpecificationRow(title: "연료", value: car.fuel)
                SpecificationRow(title: "지역", value: car.region)
                SpecificationRow(title: "브랜드", value: car.brandName)
                
                if let url = car.url {
                    HStack {
                        Text("원본 링크")
                            .font(.subheadline)
                            .foregroundColor(Color(UIConstants.Colors.textSecondary))
                        
                        Spacer()
                        
                        Link("보기", destination: URL(string: url) ?? URL(string: "https://")!)
                            .font(.subheadline)
                            .foregroundColor(Color(UIConstants.Colors.primaryBlue))
                    }
                    .padding(.vertical, UIConstants.Spacing.xs)
                }
            }
        }
        .padding()
        .background(Color(UIConstants.Colors.cardBackground))
    }
}

// MARK: - 스펙 행
struct SpecificationRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(Color(UIConstants.Colors.textSecondary))
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Color(UIConstants.Colors.textPrimary))
        }
        .padding(.vertical, UIConstants.Spacing.xs)
    }
}

// MARK: - 가격 분석 섹션
struct PriceAnalysisSectionView: View {
    let analysis: [PriceAnalysis]
    let currentPrice: Int
    @State private var showingDetail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.md) {
            // 섹션 헤더
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("가격 분석")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(UIConstants.Colors.textPrimary))
                    
                    Text("연식별 시세 정보")
                        .font(.caption)
                        .foregroundColor(Color(UIConstants.Colors.textSecondary))
                }
                
                Spacer()
                
                Button("자세히 보기") {
                    showingDetail = true
                }
                .font(.caption)
                .foregroundColor(Color(UIConstants.Colors.primaryBlue))
            }
            
            // 간단한 차트 (최근 3개 연식)
            HStack(spacing: UIConstants.Spacing.sm) {
                ForEach(Array(analysis.prefix(3)), id: \.year) { item in
                    VStack(spacing: UIConstants.Spacing.xs) {
                        Text(item.year)
                            .font(.caption2)
                            .foregroundColor(Color(UIConstants.Colors.textSecondary))
                        
                        Text(item.formattedAvgPrice)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(
                                item.avgPrice == currentPrice ?
                                Color(UIConstants.Colors.primaryBlue) :
                                Color(UIConstants.Colors.textPrimary)
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, UIConstants.Spacing.xs)
                    .background(
                        item.avgPrice == currentPrice ?
                        Color(UIConstants.Colors.primaryBlue).opacity(0.1) :
                        Color(UIConstants.Colors.backgroundColor)
                    )
                    .cornerRadius(UIConstants.CornerRadius.small)
                }
            }
        }
        .padding()
        .background(Color(UIConstants.Colors.cardBackground))
        .sheet(isPresented: $showingDetail) {
            PriceAnalysisDetailView(
                analysis: analysis,
                carModel: "",
                currentPrice: currentPrice
            )
        }
    }
}

// MARK: - 유사한 차량 섹션
struct SimilarCarsSectionView: View {
    let cars: [Car]
    @State private var showingAllSimilar = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.md) {
            // 섹션 헤더
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("유사한 차량")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(UIConstants.Colors.textPrimary))
                    
                    Text("비슷한 조건의 다른 차량들")
                        .font(.caption)
                        .foregroundColor(Color(UIConstants.Colors.textSecondary))
                }
                
                Spacer()
                
                if cars.count > 3 {
                    Button("더보기") {
                        showingAllSimilar = true
                    }
                    .font(.caption)
                    .foregroundColor(Color(UIConstants.Colors.primaryBlue))
                }
            }
            
            // 유사한 차량 카드들
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: UIConstants.Spacing.sm) {
                    ForEach(cars.prefix(5)) { car in
                        SimilarCarCardView(car: car)
                            .frame(width: 200)
                    }
                }
                .padding(.horizontal, 1) // 그림자 클리핑 방지
            }
        }
        .padding()
        .background(Color(UIConstants.Colors.cardBackground))
        .sheet(isPresented: $showingAllSimilar) {
            SimilarCarsListView(cars: cars)
        }
    }
}

// MARK: - 유사한 차량 카드
struct SimilarCarCardView: View {
    let car: Car
    @State private var showingDetail = false
    
    var body: some View {
        Button(action: {
            showingDetail = true
        }) {
            VStack(alignment: .leading, spacing: UIConstants.Spacing.sm) {
                // 차량 이미지
                ZStack {
                    RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium)
                        .fill(Color(UIConstants.Colors.backgroundColor))
                        .frame(height: 100)
                    
                    Image(systemName: "car.fill")
                        .font(.system(size: 30))
                        .foregroundColor(Color(UIConstants.Colors.secondaryGray))
                }
                
                VStack(alignment: .leading, spacing: UIConstants.Spacing.xs) {
                    // 모델명
                    Text(car.model)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Color(UIConstants.Colors.textPrimary))
                        .lineLimit(2)
                    
                    // 가격
                    Text(car.displayPrice)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(Color(UIConstants.Colors.primaryBlue))
                    
                    // 간단한 정보
                    HStack {
                        Text(car.displayYear)
                            .font(.caption2)
                            .foregroundColor(Color(UIConstants.Colors.textSecondary))
                        
                        Spacer()
                        
                        Text(car.displayMileage)
                            .font(.caption2)
                            .foregroundColor(Color(UIConstants.Colors.textSecondary))
                    }
                }
                .padding(.horizontal, UIConstants.Spacing.xs)
                .padding(.bottom, UIConstants.Spacing.xs)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .background(Color(UIConstants.Colors.cardBackground))
        .cornerRadius(UIConstants.CornerRadius.medium)
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 4,
            x: 0,
            y: 2
        )
        .sheet(isPresented: $showingDetail) {
            CarDetailView(car: car)
        }
    }
}

// MARK: - 가격 분석 상세 뷰
struct PriceAnalysisDetailView: View {
    let analysis: [PriceAnalysis]
    let carModel: String
    let currentPrice: Int
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: UIConstants.Spacing.lg) {
                    // 현재 가격 vs 평균 비교
                    PriceComparisonView(
                        currentPrice: currentPrice,
                        analysis: analysis
                    )
                    
                    // 연식별 가격 차트
                    PriceChartView(analysis: analysis, currentPrice: currentPrice)
                    
                    // 상세 데이터 테이블
                    PriceDataTableView(analysis: analysis)
                    
                    // 분석 인사이트
                    PriceInsightView(
                        analysis: analysis,
                        currentPrice: currentPrice
                    )
                }
                .padding()
            }
            .navigationTitle("가격 분석")
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

// MARK: - 가격 비교 뷰
struct PriceComparisonView: View {
    let currentPrice: Int
    let analysis: [PriceAnalysis]
    
    private var averagePrice: Int {
        let prices = analysis.map { $0.avgPrice }
        return prices.isEmpty ? 0 : prices.reduce(0, +) / prices.count
    }
    
    private var priceDifference: Int {
        return currentPrice - averagePrice
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.md) {
            Text("가격 비교")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: UIConstants.Spacing.lg) {
                // 현재 가격
                VStack(alignment: .leading, spacing: UIConstants.Spacing.xs) {
                    Text("현재 가격")
                        .font(.caption)
                        .foregroundColor(Color(UIConstants.Colors.textSecondary))
                    
                    Text("\(currentPrice)만원")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color(UIConstants.Colors.primaryBlue))
                }
                
                // 평균 가격
                VStack(alignment: .leading, spacing: UIConstants.Spacing.xs) {
                    Text("시장 평균")
                        .font(.caption)
                        .foregroundColor(Color(UIConstants.Colors.textSecondary))
                    
                    Text("\(averagePrice)만원")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color(UIConstants.Colors.textPrimary))
                }
                
                Spacer()
                
                // 차이
                VStack(alignment: .trailing, spacing: UIConstants.Spacing.xs) {
                    Text("차이")
                        .font(.caption)
                        .foregroundColor(Color(UIConstants.Colors.textSecondary))
                    
                    Text("\(priceDifference > 0 ? "+" : "")\(priceDifference)만원")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(
                            priceDifference > 0 ?
                            Color(UIConstants.Colors.accentColor) :
                            Color(UIConstants.Colors.successColor)
                        )
                }
            }
            
            // 가격 상태 메시지
            Text(priceStatusMessage)
                .font(.caption)
                .foregroundColor(Color(UIConstants.Colors.textSecondary))
                .padding()
                .background(priceStatusColor.opacity(0.1))
                .cornerRadius(UIConstants.CornerRadius.small)
        }
        .padding()
        .background(Color(UIConstants.Colors.cardBackground))
        .cornerRadius(UIConstants.CornerRadius.medium)
    }
    
    private var priceStatusMessage: String {
        let percentage = abs(Double(priceDifference) / Double(averagePrice) * 100)
        
        if priceDifference > 0 {
            return "시장 평균보다 \(String(format: "%.1f", percentage))% 높은 가격입니다."
        } else if priceDifference < 0 {
            return "시장 평균보다 \(String(format: "%.1f", percentage))% 낮은 가격입니다."
        } else {
            return "시장 평균과 동일한 가격입니다."
        }
    }
    
    private var priceStatusColor: Color {
        if priceDifference > 0 {
            return Color(UIConstants.Colors.accentColor)
        } else if priceDifference < 0 {
            return Color(UIConstants.Colors.successColor)
        } else {
            return Color(UIConstants.Colors.primaryBlue)
        }
    }
}

// MARK: - 가격 차트 뷰
struct PriceChartView: View {
    let analysis: [PriceAnalysis]
    let currentPrice: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.md) {
            Text("연식별 시세 그래프")
                .font(.headline)
                .fontWeight(.semibold)
            
            // 간단한 막대 차트
            HStack(alignment: .bottom, spacing: UIConstants.Spacing.xs) {
                ForEach(analysis.reversed(), id: \.year) { item in
                    VStack(spacing: UIConstants.Spacing.xs) {
                        Text("\(item.avgPrice)")
                            .font(.caption2)
                            .foregroundColor(Color(UIConstants.Colors.textSecondary))
                        
                        Rectangle()
                            .fill(
                                item.avgPrice == currentPrice ?
                                Color(UIConstants.Colors.primaryBlue) :
                                Color(UIConstants.Colors.secondaryGray).opacity(0.6)
                            )
                            .frame(
                                width: 30,
                                height: CGFloat(item.avgPrice) / CGFloat(analysis.map { $0.avgPrice }.max() ?? 1) * 100
                            )
                            .cornerRadius(2)
                        
                        Text(item.year)
                            .font(.caption2)
                            .foregroundColor(Color(UIConstants.Colors.textSecondary))
                            .rotationEffect(.degrees(-45))
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(UIConstants.Colors.cardBackground))
        .cornerRadius(UIConstants.CornerRadius.medium)
    }
}

// MARK: - 가격 데이터 테이블
struct PriceDataTableView: View {
    let analysis: [PriceAnalysis]
    
    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.md) {
            Text("상세 데이터")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 0) {
                // 헤더
                HStack {
                    Text("연식")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("최저가")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Text("평균가")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Text("최고가")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding()
                .background(Color(UIConstants.Colors.backgroundColor))
                
                // 데이터 행들
                ForEach(analysis, id: \.year) { item in
                    HStack {
                        Text(item.year)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("\(item.minPrice)")
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        Text("\(item.avgPrice)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        Text("\(item.maxPrice)")
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding()
                    .background(Color(UIConstants.Colors.cardBackground))
                }
            }
            .cornerRadius(UIConstants.CornerRadius.small)
            .overlay(
                RoundedRectangle(cornerRadius: UIConstants.CornerRadius.small)
                    .stroke(Color(UIConstants.Colors.secondaryGray).opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - 가격 인사이트 뷰
struct PriceInsightView: View {
    let analysis: [PriceAnalysis]
    let currentPrice: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.md) {
            Text("시장 분석")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: UIConstants.Spacing.sm) {
                InsightItemView(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "가격 트렌드",
                    description: generatePriceTrendInsight()
                )
                
                InsightItemView(
                    icon: "target",
                    title: "추천 구매 시기",
                    description: "현재 시점이 구매하기 적절한 시기입니다."
                )
                
                InsightItemView(
                    icon: "exclamationmark.circle",
                    title: "주의사항",
                    description: "차량 상태와 정비 이력을 반드시 확인하세요."
                )
            }
        }
        .padding()
        .background(Color(UIConstants.Colors.cardBackground))
        .cornerRadius(UIConstants.CornerRadius.medium)
    }
    
    private func generatePriceTrendInsight() -> String {
        guard analysis.count >= 2 else {
            return "충분한 데이터가 없어 트렌드를 분석할 수 없습니다."
        }
        
        let recentPrices = analysis.suffix(2).map { $0.avgPrice }
        let oldPrice = recentPrices.first!
        let newPrice = recentPrices.last!
        
        if newPrice > oldPrice {
            return "최근 가격이 상승 추세입니다. 서둘러 구매를 고려해보세요."
        } else if newPrice < oldPrice {
            return "최근 가격이 하락 추세입니다. 좀 더 기다려보는 것도 좋습니다."
        } else {
            return "가격이 안정적으로 유지되고 있습니다."
        }
    }
}

//// MARK: - 인사이트 아이템
//struct InsightItemView: View {
//    let icon: String
//    let title: String
//    let description: String
//    
//    var body: some View {
//        HStack(alignment: .top, spacing: UIConstants.Spacing.sm) {
//            Image(systemName: icon)
//                .font(.title3)
//                .foregroundColor(Color(UIConstants.Colors.primaryBlue))
//                .frame(width: 24)
//            
//            VStack(alignment: .leading, spacing: UIConstants.Spacing.xs) {
//                Text(title)
//                    .font(.subheadline)
//                    .fontWeight(.medium)
//                    .foregroundColor(Color(UIConstants.Colors.textPrimary))
//                
//                Text(description)
//                    .font(.caption)
//                    .foregroundColor(Color(UIConstants.Colors.textSecondary))
//                    .fixedSize(horizontal: false, vertical: true)
//            }
//        }
//    }
//}

// MARK: - 공유 시트 (UIKit 래퍼)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - 유사한 차량 리스트 뷰
struct SimilarCarsListView: View {
    let cars: [Car]
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List(cars) { car in
                NavigationLink(destination: CarDetailView(car: car)) {
                    HStack {
                        // 차량 썸네일
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(UIConstants.Colors.backgroundColor))
                            .frame(width: 60, height: 45)
                            .overlay(
                                Image(systemName: "car.fill")
                                    .foregroundColor(Color(UIConstants.Colors.secondaryGray))
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(car.model)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            
                            Text(car.displayPrice)
                                .font(.caption)
                                .foregroundColor(Color(UIConstants.Colors.primaryBlue))
                                .fontWeight(.semibold)
                            
                            Text("\(car.displayYear) • \(car.displayMileage)")
                                .font(.caption2)
                                .foregroundColor(Color(UIConstants.Colors.textSecondary))
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("유사한 차량")
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

// MARK: - 프리뷰
struct CarDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleCar = Car(
            id: 1,
            carType: "승용차",
            model: "현대 아반떼 1.6 가솔린",
            year: "2023년식",
            mileage: 15000,
            price: 2500,
            fuel: "가솔린",
            region: "서울",
            url: "https://example.com",
            imageUrl: nil,
            createdAt: "2024-01-01T00:00:00Z"
        )
        
        Group {
            CarDetailView(car: sampleCar)
                .preferredColorScheme(.light)
                .previewDisplayName("Car Detail - Light")
            
            CarDetailView(car: sampleCar)
                .preferredColorScheme(.dark)
                .previewDisplayName("Car Detail - Dark")
        }
    }
}
