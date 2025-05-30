import SwiftUI
import Combine

// MARK: - RecommendationView
struct RecommendationView: View {
    @StateObject private var recommendationService = RecommendationService.shared
    @StateObject private var favoriteService = FavoriteService.shared
    @StateObject private var viewModel = RecommendationViewModel()
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                RecommendationHeaderView(
                    aiStatus: recommendationService.aiStatus,
                    recommendationCount: recommendationService.recommendations.count,
                    onRefresh: refreshRecommendations,
                    onPreferences: { viewModel.showingPreferences = true },
                    onDebug: { viewModel.showingDebugInfo = true }
                )
                
                CategorySelectionView(selectedCategory: $viewModel.selectedCategory)
                
                RecommendationContentView(
                    viewModel: viewModel,
                    filteredRecommendations: filteredRecommendations,
                    isLoading: recommendationService.isLoading,
                    onCarTap: { car in
                        viewModel.selectedCar = car
                        viewModel.showingCarDetail = true
                    }
                )
            }
            .navigationTitle("AI 추천")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    RecommendationMenuButton(viewModel: viewModel) {
                        refreshRecommendations()
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingCarDetail) {
                if let car = viewModel.selectedCar {
                    CarDetailView(car: car)
                }
            }
            .sheet(isPresented: $viewModel.showingPreferences) {
                RecommendationPreferencesView()
            }
            .sheet(isPresented: $viewModel.showingDebugInfo) {
                RecommendationDebugView()
            }
            .onAppear {
                loadRecommendations()
            }
            .refreshable {
                await refreshRecommendationsAsync()
            }
            .onReceive(favoriteUpdatePublisher) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    refreshRecommendations()
                }
            }
        }
    }
    
    private var filteredRecommendations: [RecommendedCar] {
        guard viewModel.selectedCategory != .all else {
            return recommendationService.recommendations
        }
        return recommendationService.recommendations.filter { $0.category == viewModel.selectedCategory }
    }
    
    private var favoriteUpdatePublisher: AnyPublisher<Notification, Never> {
        NotificationCenter.default.publisher(for: Notification.Name(NotificationNames.favoriteDidUpdate))
            .eraseToAnyPublisher()
    }
    
    private func loadRecommendations() {
        recommendationService.loadRecommendations()
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &viewModel.cancellables)
    }
    
    private func refreshRecommendations() {
        recommendationService.refresh()
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &viewModel.cancellables)
    }
    
    @MainActor
    private func refreshRecommendationsAsync() async {
        _ = try? await recommendationService.refresh().singleOutput()
    }
}

// MARK: - RecommendationViewModel
@MainActor
class RecommendationViewModel: ObservableObject {
    @Published var selectedCategory: RecommendationCategory = .all
    @Published var showingCarDetail = false
    @Published var selectedCar: Car?
    @Published var showingPreferences = false
    @Published var showingDebugInfo = false
    
    var cancellables = Set<AnyCancellable>()
    
    func loadUserFavorites() {
        FavoriteService.shared.loadFavorites()
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        RecommendationService.shared.refresh()
                            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
                            .store(in: &self.cancellables)
                    }
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - RecommendationMenuButton
private struct RecommendationMenuButton: View {
    let viewModel: RecommendationViewModel
    let onRefresh: () -> Void
    
    var body: some View {
        Menu {
            Button(action: onRefresh) {
                Label("새로고침", systemImage: "arrow.clockwise")
            }
            
            Button(action: { viewModel.showingPreferences = true }) {
                Label("추천 설정", systemImage: "slider.horizontal.3")
            }
            
            if DebugConstants.isDebugMode {
                Button(action: { viewModel.showingDebugInfo = true }) {
                    Label("디버그 정보", systemImage: "ladybug")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
}

// MARK: - RecommendationContentView
private struct RecommendationContentView: View {
    let viewModel: RecommendationViewModel
    let filteredRecommendations: [RecommendedCar]
    let isLoading: Bool
    let onCarTap: (Car) -> Void
    
    var body: some View {
        Group {
            if isLoading {
                LoadingRecommendationsView()
            } else if filteredRecommendations.isEmpty {
                EmptyRecommendationsView(
                    category: viewModel.selectedCategory,
                    onLoadFavorites: viewModel.loadUserFavorites
                )
            } else {
                RecommendationListView(
                    recommendations: filteredRecommendations,
                    onCarTap: onCarTap
                )
            }
        }
    }
}

// MARK: - RecommendationHeaderView
struct RecommendationHeaderView: View {
    let aiStatus: AIServiceStatus
    let recommendationCount: Int
    let onRefresh: () -> Void
    let onPreferences: () -> Void
    let onDebug: () -> Void
    
    var body: some View {
        VStack(spacing: UIConstants.Spacing.sm) {
            AIStatusIndicatorView(status: aiStatus)
            
            HStack {
                RecommendationInfoView(count: recommendationCount)
                Spacer()
                RecommendationActionsView(
                    onRefresh: onRefresh,
                    onPreferences: onPreferences,
                    onDebug: onDebug
                )
            }
        }
        .padding()
        .background(Color(UIConstants.Colors.cardBackground))
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - RecommendationInfoView
private struct RecommendationInfoView: View {
    let count: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("개인화 추천")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Color(UIConstants.Colors.textPrimary))
            
            Text("\(count)개의 추천")
                .font(.caption)
                .foregroundColor(Color(UIConstants.Colors.textSecondary))
        }
    }
}

// MARK: - RecommendationActionsView
private struct RecommendationActionsView: View {
    let onRefresh: () -> Void
    let onPreferences: () -> Void
    let onDebug: () -> Void
    
    var body: some View {
        HStack(spacing: UIConstants.Spacing.sm) {
            RecommendationActionButton(systemImage: "arrow.clockwise", action: onRefresh)
            RecommendationActionButton(systemImage: "slider.horizontal.3", action: onPreferences)
            
            if DebugConstants.isDebugMode {
                RecommendationActionButton(systemImage: "ladybug", action: onDebug, color: UIConstants.Colors.accentColor)
            }
        }
    }
}

// MARK: - ActionButton
private struct RecommendationActionButton: View {
    let systemImage: String
    let action: () -> Void
    let color: String
    
    init(systemImage: String, action: @escaping () -> Void, color: String = UIConstants.Colors.primaryBlue) {
        self.systemImage = systemImage
        self.action = action
        self.color = color
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .foregroundColor(Color(color))
        }
    }
}

// MARK: - AIStatusIndicatorView
struct AIStatusIndicatorView: View {
    let status: AIServiceStatus
    
    var body: some View {
        HStack {
            Image(systemName: status.iconName)
                .foregroundColor(status.color)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(status.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color(UIConstants.Colors.textPrimary))
                
                Text(status.description)
                    .font(.caption)
                    .foregroundColor(Color(UIConstants.Colors.textSecondary))
            }
            
            Spacer()
            
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
        }
        .padding(UIConstants.Spacing.sm)
        .background(status.color.opacity(0.1))
        .cornerRadius(UIConstants.CornerRadius.small)
    }
}

// MARK: - CategorySelectionView
struct CategorySelectionView: View {
    @Binding var selectedCategory: RecommendationCategory
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: UIConstants.Spacing.sm) {
                ForEach(RecommendationCategory.allCases, id: \.self) { category in
                    CategoryChipView(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                        UserBehaviorService.shared.trackAction(.filter, carId: nil, value: category.rawValue)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, UIConstants.Spacing.sm)
        .background(Color(UIConstants.Colors.cardBackground))
    }
}

// MARK: - CategoryChipView
struct CategoryChipView: View {
    let category: RecommendationCategory
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: UIConstants.Spacing.xs) {
                Image(systemName: category.iconName)
                    .font(.caption)
                
                Text(category.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : Color(UIConstants.Colors.primaryBlue))
            .padding(.horizontal, UIConstants.Spacing.md)
            .padding(.vertical, UIConstants.Spacing.sm)
            .background(isSelected ? Color(UIConstants.Colors.primaryBlue) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium)
                    .stroke(Color(UIConstants.Colors.primaryBlue), lineWidth: 1)
            )
            .cornerRadius(UIConstants.CornerRadius.medium)
        }
    }
}

// MARK: - RecommendationListView
struct RecommendationListView: View {
    let recommendations: [RecommendedCar]
    let onCarTap: (Car) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: UIConstants.Spacing.md) {
                ForEach(Array(recommendations.enumerated()), id: \.element.car.id) { index, recommendation in
                    RecommendationCardView(
                        recommendation: recommendation,
                        rank: index + 1
                    ) {
                        onCarTap(recommendation.car)
                        UserBehaviorService.shared.trackAction(.click, carId: recommendation.car.id)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - RecommendationCardView
struct RecommendationCardView: View {
    let recommendation: RecommendedCar
    let rank: Int
    let onTap: () -> Void
    @StateObject private var favoriteService = FavoriteService.shared
    @State private var showingActionSheet = false
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                RecommendationCardHeader(
                    rank: rank,
                    recommendation: recommendation,
                    isFavorite: favoriteService.isFavorite(car: recommendation.car),
                    onFavoriteToggle: toggleFavorite,
                    onMoreAction: { showingActionSheet = true }
                )
                
                RecommendationCarImage(category: recommendation.category)
                
                RecommendationCarInfo(recommendation: recommendation)
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
            RecommendationActionSheet(
                recommendation: recommendation,
                isFavorite: favoriteService.isFavorite(car: recommendation.car),
                onFavoriteToggle: toggleFavorite
            )()
        }
    }
    
    private func toggleFavorite() {
        favoriteService.toggleFavorite(car: recommendation.car)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
    }
}

// MARK: - RecommendationCardHeader
private struct RecommendationCardHeader: View {
    let rank: Int
    let recommendation: RecommendedCar
    let isFavorite: Bool
    let onFavoriteToggle: () -> Void
    let onMoreAction: () -> Void
    
    var body: some View {
        HStack {
            RankBadge(rank: rank)
            MatchingScore(percentage: recommendation.scorePercentage)
            Spacer()
            FavoriteToggleButton(isFavorite: isFavorite, action: onFavoriteToggle)
            MoreButton(action: onMoreAction)
        }
        .padding()
    }
}

// MARK: - RankBadge
private struct RankBadge: View {
    let rank: Int
    
    var body: some View {
        Text("#\(rank)")
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, UIConstants.Spacing.xs)
            .padding(.vertical, 2)
            .background(rankColor)
            .cornerRadius(UIConstants.CornerRadius.small)
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return Color(UIConstants.Colors.warningColor)
        case 2: return Color(UIConstants.Colors.secondaryGray)
        case 3: return Color.brown
        default: return Color(UIConstants.Colors.primaryBlue)
        }
    }
}

// MARK: - MatchingScore
private struct MatchingScore: View {
    let percentage: Int
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "brain.head.profile")
                .font(.caption2)
                .foregroundColor(Color(UIConstants.Colors.primaryBlue))
            
            Text("\(percentage)% 매칭")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color(UIConstants.Colors.primaryBlue))
        }
    }
}

// MARK: - FavoriteToggleButton
private struct FavoriteToggleButton: View {
    let isFavorite: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .foregroundColor(isFavorite ?
                    Color(UIConstants.Colors.accentColor) :
                    Color(UIConstants.Colors.secondaryGray))
                .font(.title3)
        }
    }
}

// MARK: - MoreButton
private struct MoreButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "ellipsis")
                .foregroundColor(Color(UIConstants.Colors.secondaryGray))
        }
    }
}

// MARK: - RecommendationCarImage
private struct RecommendationCarImage: View {
    let category: RecommendationCategory
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium)
                .fill(Color(UIConstants.Colors.backgroundColor))
                .frame(height: 180)
            
            Image(systemName: "car.fill")
                .font(.system(size: 50))
                .foregroundColor(Color(UIConstants.Colors.secondaryGray))
            
            CategoryBadge(category: category)
        }
    }
}

// MARK: - CategoryBadge
private struct CategoryBadge: View {
    let category: RecommendationCategory
    
    var body: some View {
        VStack {
            HStack {
                Text(category.displayName)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, UIConstants.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(category.color)
                    .cornerRadius(UIConstants.CornerRadius.small)
                
                Spacer()
            }
            Spacer()
        }
        .padding(UIConstants.Spacing.sm)
    }
}

// MARK: - RecommendationCarInfo
private struct RecommendationCarInfo: View {
    let recommendation: RecommendedCar
    
    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.sm) {
            Text(recommendation.car.model)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(Color(UIConstants.Colors.textPrimary))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            Text(recommendation.car.formattedPrice)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color(UIConstants.Colors.primaryBlue))
            
            HStack(spacing: UIConstants.Spacing.sm) {
                InfoTag(icon: "calendar", text: recommendation.car.displayYear)
                InfoTag(icon: "speedometer", text: recommendation.car.displayMileage)
                InfoTag(icon: "location.fill", text: recommendation.car.region)
            }
            
            RecommendationReason(reason: recommendation.displayReason)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - InfoTag
struct InfoTag: View {
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

// MARK: - RecommendationReason
private struct RecommendationReason: View {
    let reason: String
    
    var body: some View {
        HStack(alignment: .top, spacing: UIConstants.Spacing.xs) {
            Image(systemName: "lightbulb.fill")
                .font(.caption)
                .foregroundColor(Color(UIConstants.Colors.warningColor))
            
            Text(reason)
                .font(.caption)
                .foregroundColor(Color(UIConstants.Colors.textSecondary))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(UIConstants.Spacing.sm)
        .background(Color(UIConstants.Colors.backgroundColor))
        .cornerRadius(UIConstants.CornerRadius.small)
    }
}

// MARK: - LoadingRecommendationsView
struct LoadingRecommendationsView: View {
    @State private var animationTrigger = UUID()
    
    var body: some View {
        VStack(spacing: UIConstants.Spacing.lg) {
            Spacer()
            
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundColor(Color(UIConstants.Colors.primaryBlue))
                .scaleEffect(1.0)
                .animation(
                    Animation.easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: true),
                    value: animationTrigger
                )
            
            VStack(spacing: UIConstants.Spacing.sm) {
                Text("AI가 추천을 생성하고 있습니다")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(UIConstants.Colors.textPrimary))
                
                Text("당신의 선호도를 분석하여\n최적의 차량을 찾고 있어요")
                    .font(.body)
                    .foregroundColor(Color(UIConstants.Colors.textSecondary))
                    .multilineTextAlignment(.center)
            }
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color(UIConstants.Colors.primaryBlue)))
                .scaleEffect(1.2)
            
            Spacer()
        }
        .padding()
        .onAppear {
            animationTrigger = UUID()
        }
    }
}

// MARK: - EmptyRecommendationsView
struct EmptyRecommendationsView: View {
    let category: RecommendationCategory
    let onLoadFavorites: () -> Void
    
    var body: some View {
        VStack(spacing: UIConstants.Spacing.xl) {
            Spacer()
            
            Image(systemName: category.emptyStateIcon)
                .font(.system(size: 80))
                .foregroundColor(Color(UIConstants.Colors.secondaryGray))
            
            VStack(spacing: UIConstants.Spacing.sm) {
                Text(category.emptyStateTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(UIConstants.Colors.textPrimary))
                
                Text(category.emptyStateMessage)
                    .font(.body)
                    .foregroundColor(Color(UIConstants.Colors.textSecondary))
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            
            VStack(spacing: UIConstants.Spacing.sm) {
                Button("즐겨찾기 추가하러 가기") {
                    onLoadFavorites()
                }
                .buttonStyle(AppPrimaryButtonStyle())
                
                NavigationLink(destination: HomeView()) {
                    Text("차량 둘러보기")
                        .fontWeight(.medium)
                }
                .buttonStyle(AppPrimaryButtonStyle())
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - RecommendationActionSheet
private struct RecommendationActionSheet {
    let recommendation: RecommendedCar
    let isFavorite: Bool
    let onFavoriteToggle: () -> Void
    
    func callAsFunction() -> ActionSheet {
        ActionSheet(
            title: Text(recommendation.car.model),
            message: Text("원하는 작업을 선택하세요"),
            buttons: [
                .default(Text("유사한 차량 보기")) {
                    UserBehaviorService.shared.trackAction(.compare, carId: recommendation.car.id)
                },
                .default(Text("공유하기")) {
                    UserBehaviorService.shared.trackAction(.share, carId: recommendation.car.id)
                },
                .default(Text("관심 없음")) {
                    UserBehaviorService.shared.trackAction(.view, carId: recommendation.car.id, value: "hidden")
                },
                .cancel(Text("취소"))
            ]
        )
    }
}

// MARK: - RecommendationPreferencesView
struct RecommendationPreferencesView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var recommendationService = RecommendationService.shared
    @State private var preferences = RecommendationPreferences()
    
    var body: some View {
        NavigationView {
            Form {
                RecommendationIntensitySection(preferences: $preferences)
                DiversitySection(preferences: $preferences)
                NotificationSection(preferences: $preferences)
                DataManagementSection()
            }
            .navigationTitle("추천 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("저장") {
                        savePreferences()
                    }
                }
            }
        }
        .onAppear {
            preferences = recommendationService.getPreferences()
        }
    }
    
    private func savePreferences() {
        recommendationService.updatePreferences(preferences)
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Preference Sections
private struct RecommendationIntensitySection: View {
    @Binding var preferences: RecommendationPreferences
    
    var body: some View {
        Section(header: Text("추천 강도")) {
            VStack(alignment: .leading, spacing: UIConstants.Spacing.sm) {
                Text("매칭 정확도")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Slider(value: $preferences.similarityThreshold, in: 0.1...1.0, step: 0.1)
                
                Text("현재: \(Int(preferences.similarityThreshold * 100))%")
                    .font(.caption)
                    .foregroundColor(Color(UIConstants.Colors.textSecondary))
            }
        }
    }
}

private struct DiversitySection: View {
    @Binding var preferences: RecommendationPreferences
    
    var body: some View {
        Section(header: Text("추천 다양성")) {
            Toggle("브랜드 다양성", isOn: $preferences.enableBrandDiversity)
            Toggle("가격대 다양성", isOn: $preferences.enablePriceDiversity)
            Toggle("신차 우선 표시", isOn: $preferences.prioritizeNewCars)
        }
    }
}

private struct NotificationSection: View {
    @Binding var preferences: RecommendationPreferences
    
    var body: some View {
        Section(header: Text("알림 설정")) {
            Toggle("새로운 추천 알림", isOn: $preferences.enableNewRecommendationNotification)
            Toggle("가격 변동 알림", isOn: $preferences.enablePriceChangeNotification)
        }
    }
}

private struct DataManagementSection: View {
    var body: some View {
        Section(header: Text("개인정보")) {
            Button("추천 데이터 초기화") {
                RecommendationService.shared.resetUserData()
            }
            .foregroundColor(Color(UIConstants.Colors.accentColor))
            
            Button("선호도 재학습") {
                RecommendationService.shared.retrainModel()
            }
            .foregroundColor(Color(UIConstants.Colors.primaryBlue))
        }
    }
}

// MARK: - RecommendationDebugView
struct RecommendationDebugView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var recommendationService = RecommendationService.shared
    @State private var debugInfo: [String: Any] = [:]
    @State private var isLoading = true
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("디버그 정보 로드 중...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    DebugInfoScrollView(debugInfo: debugInfo)
                }
            }
            .navigationTitle("디버그 정보")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("닫기") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("새로고침") {
                        loadDebugInfo()
                    }
                }
            }
        }
        .onAppear {
            loadDebugInfo()
        }
    }
    
    private func loadDebugInfo() {
        isLoading = true
        
        recommendationService.getDebugInfo()
            .sink(
                receiveCompletion: { _ in
                    isLoading = false
                },
                receiveValue: { info in
                    debugInfo = info
                    isLoading = false
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - DebugInfoScrollView
private struct DebugInfoScrollView: View {
    let debugInfo: [String: Any]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: UIConstants.Spacing.md) {
                ForEach(Array(debugInfo.keys.sorted()), id: \.self) { key in
                    DebugInfoSection(key: key, value: debugInfo[key])
                }
            }
            .padding()
        }
    }
}

// MARK: - DebugInfoSection
struct DebugInfoSection: View {
    let key: String
    let value: Any?
    
    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.xs) {
            Text(key)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(Color(UIConstants.Colors.textPrimary))
            
            Text(String(describing: value ?? "nil"))
                .font(.caption)
                .foregroundColor(Color(UIConstants.Colors.textSecondary))
                .padding()
                .background(Color(UIConstants.Colors.backgroundColor))
                .cornerRadius(UIConstants.CornerRadius.small)
        }
    }
}

// MARK: - RecommendationCategory
enum RecommendationCategory: String, CaseIterable {
    case all, similar, priceMatch, brandMatch, newArrivals
    
    var displayName: String {
        switch self {
        case .all: return "전체"
        case .similar: return "유사한 차량"
        case .priceMatch: return "가격 매칭"
        case .brandMatch: return "브랜드 매칭"
        case .newArrivals: return "신규 등록"
        }
    }
    
    var iconName: String {
        switch self {
        case .all: return "rectangle.grid.1x2.fill"
        case .similar: return "arrow.triangle.2.circlepath"
        case .priceMatch: return "wonsign.circle.fill"
        case .brandMatch: return "star.circle.fill"
        case .newArrivals: return "sparkles"
        }
    }
    
    var emptyStateIcon: String {
        switch self {
        case .all: return "brain.head.profile"
        case .similar: return "arrow.triangle.2.circlepath"
        case .priceMatch: return "wonsign.circle"
        case .brandMatch: return "star.circle"
        case .newArrivals: return "sparkles"
        }
    }
    
    var emptyStateTitle: String {
        switch self {
        case .all: return "추천할 차량이 없습니다"
        case .similar: return "유사한 차량을 찾을 수 없습니다"
        case .priceMatch: return "가격 매칭 차량이 없습니다"
        case .brandMatch: return "브랜드 매칭 차량이 없습니다"
        case .newArrivals: return "새로 등록된 차량이 없습니다"
        }
    }
    
    var emptyStateMessage: String {
        switch self {
        case .all:
            return "더 정확한 추천을 위해\n관심 있는 차량을 즐겨찾기에 추가해보세요"
        case .similar:
            return "즐겨찾기한 차량과 유사한\n다른 차량들을 찾을 수 없습니다"
        case .priceMatch:
            return "선호하는 가격대와 비슷한\n차량들을 찾을 수 없습니다"
        case .brandMatch:
            return "선호하는 브랜드의\n다른 차량들을 찾을 수 없습니다"
        case .newArrivals:
            return "최근에 새로 등록된\n차량이 없습니다"
        }
    }
    
    var color: Color {
        switch self {
        case .all: return Color(UIConstants.Colors.primaryBlue)
        case .similar: return Color(UIConstants.Colors.successColor)
        case .priceMatch: return Color(UIConstants.Colors.warningColor)
        case .brandMatch: return Color(UIConstants.Colors.accentColor)
        case .newArrivals: return Color.purple
        }
    }
}

// MARK: - AIServiceStatus Extensions
extension AIServiceStatus {
    var iconName: String {
        switch self {
        case .available: return "checkmark.circle.fill"
        case .unavailable: return "exclamationmark.triangle.fill"
        case .unknown: return "questionmark.circle.fill"
        case .maintenance: return "wrench.and.screwdriver.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .available: return Color(UIConstants.Colors.successColor)
        case .unavailable: return Color(UIConstants.Colors.accentColor)
        case .unknown: return Color(UIConstants.Colors.secondaryGray)
        case .maintenance: return Color.orange
        }
    }
    
    var title: String {
        switch self {
        case .available: return "AI 추천 서비스 활성화"
        case .unavailable: return "AI 추천 서비스 오류"
        case .unknown: return "AI 상태 확인 중"
        case .maintenance: return "AI 서비스 점검 중"
        }
    }
    
    var description: String {
        switch self {
        case .available: return "개인화된 추천을 제공합니다"
        case .unavailable: return "일시적인 오류가 발생했습니다"
        case .unknown: return "서비스 상태를 확인하고 있습니다"
        case .maintenance: return "시스템 점검이 진행 중입니다"
        }
    }
    
    var displayText: String {
        switch self {
        case .available: return "AI 추천 서비스가 정상 작동 중입니다"
        case .unavailable: return "AI 추천 서비스에 일시적인 문제가 있습니다"
        case .unknown: return "AI 추천 서비스 상태를 확인하고 있습니다"
        case .maintenance: return "AI 추천 서비스 점검이 진행 중입니다"
        }
    }
    
    var isAvailable: Bool {
        self == .available
    }
}

// MARK: - RecommendedCar Extensions
extension RecommendedCar {
    var scorePercentage: Int {
        Int(similarityScore * 100)
    }
    
    var displayReason: String {
        recommendationReason
    }
    
    var category: RecommendationCategory {
        // 추천 이유에 따라 카테고리 결정 (실제 구현에서는 서버에서 제공)
        if recommendationReason.contains("유사한") {
            return .similar
        } else if recommendationReason.contains("가격") {
            return .priceMatch
        } else if recommendationReason.contains("브랜드") {
            return .brandMatch
        } else if car.isNewCar {
            return .newArrivals
        } else {
            return .all
        }
    }
}

// MARK: - Previews
struct RecommendationView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            RecommendationView()
                .preferredColorScheme(.light)
                .previewDisplayName("Recommendation View - Light")
            
            RecommendationView()
                .preferredColorScheme(.dark)
                .previewDisplayName("Recommendation View - Dark")
            
            LoadingRecommendationsView()
                .previewDisplayName("Loading State")
            
            EmptyRecommendationsView(category: .all) {}
                .previewDisplayName("Empty State")
        }
    }
}
