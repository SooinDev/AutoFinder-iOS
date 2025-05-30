import SwiftUI
import Combine

// MARK: - 프로필 뷰
struct ProfileView: View {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var favoriteService = FavoriteService.shared
    @StateObject private var userBehaviorService = UserBehaviorService.shared
    @State private var showingSettings = false
    @State private var showingLogoutAlert = false
    @State private var showingBehaviorAnalysis = false
    // 이제 BehaviorSummary는 UserBehaviorService.swift 또는 Models.swift에 정의된 것을 사용
    @State private var behaviorSummary: BehaviorSummary?
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: UIConstants.Spacing.lg) { // UIConstants가 Constants.swift에 정의되어 있다고 가정
                    UserProfileHeaderView()
                    ActivityStatsView()
                    FavoriteSummaryView() // FavoriteStatistics는 FavoriteService.swift 또는 Models.swift에 정의된 것 사용
                    
                    if let summary = behaviorSummary {
                        BehaviorSummaryView(summary: summary) { // summary는 이제 중앙 정의된 BehaviorSummary 타입
                            showingBehaviorAnalysis = true
                        }
                    }
                    
                    AccountManagementView(
                        onSettings: { showingSettings = true },
                        onLogout: { showingLogoutAlert = true }
                    )
                }
                .padding()
            }
            .navigationTitle("프로필")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadProfileData()
            }
        }
        .sheet(isPresented: $showingSettings) {
            AppSettingsView() // AppSettingsView가 다른 곳에 정의되어 있다고 가정
        }
        .sheet(isPresented: $showingBehaviorAnalysis) {
            BehaviorAnalysisView() // BehaviorAnalysisView가 다른 곳에 정의되어 있다고 가정
        }
        .alert("로그아웃", isPresented: $showingLogoutAlert) {
            Button("취소", role: .cancel) {}
            Button("로그아웃", role: .destructive) {
                authManager.logout()
            }
        } message: {
            Text("로그아웃하시겠습니까?")
        }
        .onAppear {
            loadBehaviorSummary()
        }
    }
    
    @MainActor
    private func loadProfileData() async {
        async let favoriteTask: Void = {
            do {
                // FavoriteService의 refresh가 AnyPublisher<Void, NetworkError>를 반환한다고 가정
                // Publisher 확장에 waitForCompletion이 정의되어 있다고 가정
                try await favoriteService.refresh().waitForCompletion()
            } catch {
                print("Failed to refresh favorites: \(error)")
            }
        }()
        
        async let behaviorTask: Void = { // UserBehaviorService.loadBehaviorAnalysis()가 내부적으로 behaviorSummary를 업데이트
            do {
                // UserBehaviorService.loadBehaviorAnalysis()가 AnyPublisher<UserBehaviorAnalysis, NetworkError>를 반환하고,
                // 해당 서비스 내에서 @Published var behaviorSummary를 업데이트 한다고 가정.
                // 여기서는 완료만 기다리거나, 값을 받아 사용하지 않는다면 아래처럼 처리.
                 _ = await userBehaviorService.loadBehaviorAnalysis().firstOutput()
            } catch {
                print("Failed to load behavior analysis for profile data: \(error)")
            }
        }()
        
        _ = await [favoriteTask, behaviorTask]
        
        // loadBehaviorAnalysis()의 sink에서 userBehaviorService.behaviorSummary를 참조하여
        // self.behaviorSummary를 업데이트하므로, loadBehaviorSummary()를 다시 호출
        loadBehaviorSummary()
    }
    
    // ProfileView.swift
    private func loadBehaviorSummary() {
        userBehaviorService.loadBehaviorAnalysis() // 이 메서드가 AnyPublisher<UserBehaviorAnalysis, NetworkError>를 반환한다고 가정
            .sink(
                receiveCompletion: { completion in // [weak self] 제거
                    if case .failure(let error) = completion {
                        print("Failed to load behavior summary: \(error.localizedDescription)")
                        // TODO: 사용자에게 오류 알림
                    }
                },
                receiveValue: { (analysis: UserBehaviorAnalysis) in // [weak self] 제거, 명시적 타입 사용 권장
                    // self가 구조체이므로 직접 참조 가능
                    DispatchQueue.main.async {
                        // UserBehaviorService 내의 behaviorSummary가 업데이트 된다고 가정하거나,
                        // 받은 analysis를 사용하여 self.behaviorSummary를 설정
                        // 'self'를 명시적으로 사용하지 않아도 되지만, 명확성을 위해 사용할 수 있습니다.
                        // 예: self.behaviorSummary = self.userBehaviorService.behaviorSummary
                        // 또는
                        // this.behaviorSummary = this.userBehaviorService.behaviorSummary (만약 self 대신 다른 이름을 사용하고 싶다면, 하지만 일반적으로 self 사용)
                        // 가장 중요한 것은 [weak self]를 제거하는 것입니다.
                        // 아래 코드는 self를 명시적으로 사용하지 않은 예시입니다.
                        // 만약 ProfileView 내의 상태 변수를 업데이트하려면 self. 키워드가 필요합니다.
                        // 현재 코드에서는 self.userBehaviorService.behaviorSummary를 this.behaviorSummary (ProfileView의 @State 변수)에 할당하는 것이므로 self.가 필요합니다.
                        self.behaviorSummary = self.userBehaviorService.behaviorSummary // 이 라인도 self가 필요
                    }
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - 사용자 프로필 헤더
struct UserProfileHeaderView: View {
    @StateObject private var authManager = AuthManager.shared
    
    var body: some View {
        VStack(spacing: UIConstants.Spacing.md) {
            Circle()
                .fill(Color(UIConstants.Colors.primaryBlue))
                .frame(width: 80, height: 80)
                .overlay(
                    Text(authManager.userDisplayName.prefix(1).uppercased())
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            VStack(spacing: UIConstants.Spacing.xs) {
                Text(authManager.userDisplayName)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(UIConstants.Colors.textPrimary))
                
                Text("AutoFinder 회원")
                    .font(.caption)
                    .foregroundColor(Color(UIConstants.Colors.textSecondary))
                
                if authManager.isAdmin {
                    Text("관리자")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, UIConstants.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(Color(UIConstants.Colors.accentColor))
                        .cornerRadius(4)
                }
            }
        }
        .padding()
        .background(Color(UIConstants.Colors.cardBackground))
        .cornerRadius(UIConstants.CornerRadius.large)
        .shadow(
            color: Color.black.opacity(UIConstants.Shadow.opacity),
            radius: UIConstants.Shadow.radius,
            x: UIConstants.Shadow.offset.width,
            y: UIConstants.Shadow.offset.height
        )
    }
}

// MARK: - 활동 통계 뷰
struct ActivityStatsView: View {
    @StateObject private var favoriteService = FavoriteService.shared
    @StateObject private var carService = CarService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.md) {
            Text("활동 통계")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(Color(UIConstants.Colors.textPrimary))
            
            HStack(spacing: UIConstants.Spacing.md) {
                StatCardView(
                    title: "즐겨찾기",
                    value: "\(favoriteService.favoriteCount)",
                    subtitle: "관심 차량",
                    icon: "heart.fill",
                    color: Color(UIConstants.Colors.accentColor)
                )
                
                StatCardView(
                    title: "검색 기록",
                    value: "\(carService.searchHistory.count)",
                    subtitle: "검색 횟수",
                    icon: "magnifyingglass",
                    color: Color(UIConstants.Colors.primaryBlue)
                )
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
}

// MARK: - 통계 카드
struct StatCardView: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: UIConstants.Spacing.sm) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(spacing: 2) {
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(Color(UIConstants.Colors.textPrimary))
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Color(UIConstants.Colors.textSecondary))
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(Color(UIConstants.Colors.textSecondary))
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(UIConstants.CornerRadius.medium)
    }
}

// MARK: - 즐겨찾기 요약 뷰
struct FavoriteSummaryView: View {
    @StateObject private var favoriteService = FavoriteService.shared
    
    // FavoriteStatistics는 FavoriteService.swift 또는 Models.swift에 정의된 것을 사용
    private var statistics: FavoriteStatistics {
        return favoriteService.statistics
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.md) {
            HStack {
                Text("즐겨찾기 요약")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(UIConstants.Colors.textPrimary))
                
                Spacer()
                
                NavigationLink(destination: FavoriteView()) { // FavoriteView가 정의되어 있다고 가정
                    Text("전체 보기")
                        .font(.caption)
                        .foregroundColor(Color(UIConstants.Colors.primaryBlue))
                }
            }
            
            if favoriteService.isEmpty {
                EmptyFavoriteSummaryView()
            } else {
                FavoriteStatsGridView(statistics: statistics)
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
}

// MARK: - 빈 즐겨찾기 요약
struct EmptyFavoriteSummaryView: View {
    var body: some View {
        VStack(spacing: UIConstants.Spacing.sm) {
            Image(systemName: "heart")
                .font(.title)
                .foregroundColor(Color(UIConstants.Colors.secondaryGray))
            
            Text("아직 즐겨찾기한 차량이 없습니다")
                .font(.subheadline)
                .foregroundColor(Color(UIConstants.Colors.textSecondary))
                .multilineTextAlignment(.center)
            
            NavigationLink(destination: HomeView()) { // HomeView가 정의되어 있다고 가정
                Text("차량 둘러보기")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Color(UIConstants.Colors.primaryBlue))
                    .padding(.horizontal, UIConstants.Spacing.sm)
                    .padding(.vertical, UIConstants.Spacing.xs)
                    .background(Color(UIConstants.Colors.primaryBlue).opacity(0.1))
                    .cornerRadius(UIConstants.CornerRadius.small)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, UIConstants.Spacing.lg)
    }
}

// MARK: - 즐겨찾기 통계 그리드
struct FavoriteStatsGridView: View {
    // FavoriteStatistics는 FavoriteService.swift 또는 Models.swift에 정의된 것을 사용
    let statistics: FavoriteStatistics
    
    var body: some View {
        VStack(spacing: UIConstants.Spacing.sm) {
            HStack {
                InfoItemView(
                    label: "평균 가격",
                    value: statistics.formattedAveragePrice
                )
                
                Spacer()
                
                InfoItemView(
                    label: "선호 브랜드",
                    value: statistics.topBrand ?? "다양함"
                )
            }
            
            HStack {
                InfoItemView(
                    label: "선호 연료",
                    value: statistics.topFuelType ?? "다양함"
                )
                
                Spacer()
                
                InfoItemView(
                    label: "가격대",
                    value: statistics.mostCommonPriceRange ?? "다양함"
                )
            }
        }
    }
}

// MARK: - 정보 아이템
struct InfoItemView: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(Color(UIConstants.Colors.textSecondary))
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color(UIConstants.Colors.textPrimary))
                .lineLimit(1)
        }
    }
}

// MARK: - 행동 분석 요약 뷰
struct BehaviorSummaryView: View {
    // BehaviorSummary는 UserBehaviorService.swift 또는 Models.swift에 정의된 것을 사용
    let summary: BehaviorSummary
    let onDetailTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.md) {
            HStack {
                Text("사용 패턴 분석")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(UIConstants.Colors.textPrimary))
                
                Spacer()
                
                Button("자세히 보기") {
                    onDetailTap()
                }
                .font(.caption)
                .foregroundColor(Color(UIConstants.Colors.primaryBlue))
            }
            
            VStack(spacing: UIConstants.Spacing.sm) {
                HStack {
                    BehaviorMetricView(
                        title: "총 활동",
                        value: "\(summary.totalActions)",
                        subtitle: "회"
                    )
                    
                    Spacer()
                    
                    BehaviorMetricView(
                        title: "활동 일수",
                        value: "\(summary.activeDays)",
                        subtitle: "일"
                    )
                    
                    Spacer()
                    
                    BehaviorMetricView(
                        title: "평균 세션",
                        value: summary.formattedSessionDuration,
                        subtitle: ""
                    )
                }
                
                VStack(alignment: .leading, spacing: UIConstants.Spacing.xs) {
                    HStack {
                        Text("참여도")
                            .font(.caption)
                            .foregroundColor(Color(UIConstants.Colors.textSecondary))
                        
                        Spacer()
                        
                        // UserBehaviorService.swift 내 BehaviorSummary의 engagementScore를 사용
                        Text("\(Int(summary.engagementScore * 10))/10")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color(UIConstants.Colors.primaryBlue))
                    }
                    
                    ProgressView(value: summary.engagementScore, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: Color(UIConstants.Colors.primaryBlue)))
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
    }
}

// MARK: - 행동 메트릭 뷰
struct BehaviorMetricView: View {
    let title: String
    let value: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(Color(UIConstants.Colors.textPrimary))
            
            Text(title)
                .font(.caption2)
                .foregroundColor(Color(UIConstants.Colors.textSecondary))
            
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(Color(UIConstants.Colors.textSecondary))
            }
        }
    }
}

// MARK: - 계정 관리 뷰
struct AccountManagementView: View {
    let onSettings: () -> Void
    let onLogout: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.md) {
            Text("계정 관리")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(Color(UIConstants.Colors.textPrimary))
            
            VStack(spacing: 0) {
                AccountActionRow(
                    icon: "gearshape.fill",
                    title: "설정",
                    subtitle: "알림, 테마, 개인정보 설정",
                    action: onSettings
                )
                
                Divider()
                    .padding(.leading, 44)
                
                AccountActionRow(
                    icon: "rectangle.portrait.and.arrow.right.fill",
                    title: "로그아웃",
                    subtitle: "계정에서 로그아웃",
                    iconColor: Color(UIConstants.Colors.accentColor),
                    action: onLogout
                )
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
}

// MARK: - 계정 액션 행
struct AccountActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var iconColor: Color = Color(UIConstants.Colors.primaryBlue)
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: UIConstants.Spacing.md) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
                    .frame(width: 24, alignment: .center)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color(UIConstants.Colors.textPrimary))
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(Color(UIConstants.Colors.textSecondary))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color(UIConstants.Colors.secondaryGray))
            }
            .padding(.vertical, UIConstants.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 임시 뷰 정의 (실제 프로젝트에서는 별도 파일에 있어야 함)
// struct AppSettingsView: View { var body: some View { Text("App Settings") } }
// struct BehaviorAnalysisView: View { var body: some View { Text("Behavior Analysis") } }
// struct FavoriteView: View { var body: some View { Text("Favorites") } }
// struct HomeView: View { var body: some View { Text("Home") } }

/*
 아래 모델 정의는 ProfileView.swift 파일에서 제거하고,
 각각 UserBehaviorService.swift 또는 FavoriteService.swift 또는 Models.swift 파일로 이동해야 합니다.
 여기서는 ProfileView 컴파일을 위해 임시로 남겨둘 수 있지만, 최종적으로는 제거 대상입니다.
*/
// struct BehaviorSummary { ... } // 이 파일에서 제거하고 UserBehaviorService.swift 또는 Models.swift로 이동
// struct FavoriteStatistics { ... } // 이 파일에서 제거하고 FavoriteService.swift 또는 Models.swift로 이동


// MARK: - 프리뷰
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            // .environmentObject(AuthManager.shared) // 실제 프리뷰 시 필요
            // .environmentObject(FavoriteService.shared)
            // .environmentObject(UserBehaviorService.shared)
            // .environmentObject(CarService.shared)
    }
}

// Publisher 확장은 이미 존재하므로 여기서는 생략합니다.
// UIConstants 등은 Constants.swift에 정의되어 있다고 가정합니다.

struct AppSettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    var body: some View {
        NavigationView {
            Text("앱 설정 화면 (구현 예정)")
                .navigationTitle("설정")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("닫기") { presentationMode.wrappedValue.dismiss() }
                    }
                }
        }
    }
}

struct BehaviorAnalysisView: View {
    @Environment(\.presentationMode) var presentationMode
    var body: some View {
        NavigationView {
            Text("행동 분석 상세 화면 (구현 예정)")
                .navigationTitle("행동 분석")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("닫기") { presentationMode.wrappedValue.dismiss() }
                    }
                }
        }
    }
}

extension Publisher {
    /// 첫 번째 값을 비동기적으로 기다리거나, Publisher가 실패하거나 값 없이 완료되면 nil을 반환합니다.
    func firstOutput() async -> Output? {
        do {
            for try await value in self.values { // 'self.values'로 명시
                return value
            }
            return nil
        } catch {
            return nil
        }
    }

    /// Publisher가 값을 방출하지 않고 완료될 때까지 기다립니다. (주로 Void 타입 Publisher에 사용)
    /// Publisher의 Failure 타입이 Never가 아니면 오류를 다시 throw 할 수 있도록 수정합니다.
    func waitForCompletion() async throws {
        do {
            for try await _ in self.values { // 'self.values'로 명시
                // 값을 방출하는 경우 무시하고 완료될 때까지 기다림
            }
        } catch {
            // Publisher에서 발생한 오류를 그대로 다시 throw
            throw error
        }
    }
}
