import SwiftUI
import Combine

// MARK: - 설정 뷰
struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var userBehaviorService = UserBehaviorService.shared
    @State private var preferences = UserPreferences()
    @State private var showingResetAlert = false
    @State private var showingClearCacheAlert = false
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: UIConstants.Spacing.lg) {
                    // 일반 설정
                    SettingsSection(title: "일반") {
                        SettingsRow(
                            icon: "bell.fill",
                            title: "푸시 알림",
                            subtitle: "새로운 추천 및 업데이트 알림"
                        ) {
                            Toggle("", isOn: $preferences.enablePushNotifications)
                                .labelsHidden()
                        }
                        
                        SettingsRow(
                            icon: "eye.fill",
                            title: "행동 추적",
                            subtitle: "개인화 추천을 위한 사용 패턴 수집"
                        ) {
                            Toggle("", isOn: $preferences.enableBehaviorTracking)
                                .labelsHidden()
                                .onChange(of: preferences.enableBehaviorTracking) { enabled in
                                    userBehaviorService.updateTrackingSettings(enabled: enabled)
                                }
                        }
                    }
                    
                    // 테마 설정
                    SettingsSection(title: "화면") {
                        SettingsRow(
                            icon: "moon.fill",
                            title: "테마 모드",
                            subtitle: "라이트, 다크, 시스템 설정"
                        ) {
                            Menu {
                                ForEach(UserPreferences.ThemeMode.allCases, id: \.self) { mode in
                                    Button(mode.displayName) {
                                        preferences.themeMode = mode
                                        applyThemeChange()
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(preferences.themeMode.displayName)
                                        .foregroundColor(Color(UIConstants.Colors.primaryBlue))
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                        .foregroundColor(Color(UIConstants.Colors.primaryBlue))
                                }
                            }
                        }
                    }
                    
                    // 지역 설정
                    SettingsSection(title: "선호 설정") {
                        NavigationLink(destination: PreferredRegionsView(selectedRegions: $preferences.preferredRegions)) {
                            SettingsRow(
                                icon: "location.fill",
                                title: "선호 지역",
                                subtitle: "\(preferences.preferredRegions.count)개 지역 선택됨"
                            ) {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(Color(UIConstants.Colors.secondaryGray))
                            }
                        }
                        
                        NavigationLink(destination: DefaultFiltersView(filters: $preferences.favoriteFilters)) {
                            SettingsRow(
                                icon: "slider.horizontal.3",
                                title: "기본 필터",
                                subtitle: "자주 사용하는 검색 조건 저장"
                            ) {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(Color(UIConstants.Colors.secondaryGray))
                            }
                        }
                    }
                    
                    // 데이터 관리
                    SettingsSection(title: "데이터") {
                        SettingsActionRow(
                            icon: "trash.circle.fill",
                            title: "캐시 삭제",
                            subtitle: "저장된 임시 데이터 삭제",
                            iconColor: Color(UIConstants.Colors.warningColor),
                            action: { showingClearCacheAlert = true }
                        )
                        
                        SettingsActionRow(
                            icon: "arrow.clockwise.circle.fill",
                            title: "설정 초기화",
                            subtitle: "모든 설정을 기본값으로 복원",
                            iconColor: Color(UIConstants.Colors.accentColor),
                            action: { showingResetAlert = true }
                        )
                    }
                    
                    // 앱 정보
                    SettingsSection(title: "정보") {
                        SettingsRow(
                            icon: "info.circle.fill",
                            title: "앱 버전",
                            subtitle: AppConstants.version
                        ) {
                            EmptyView()
                        }
                        
                        SettingsActionRow(
                            icon: "doc.text.fill",
                            title: "개인정보 처리방침",
                            subtitle: "개인정보 보호 및 처리 방침",
                            action: { openPrivacyPolicy() }
                        )
                        
                        SettingsActionRow(
                            icon: "doc.plaintext.fill",
                            title: "서비스 이용약관",
                            subtitle: "AutoFinder 서비스 이용 약관",
                            action: { openTermsOfService() }
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("닫기") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("저장") {
                        saveSettings()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(Color(UIConstants.Colors.primaryBlue))
                }
            }
        }
        .alert("캐시 삭제", isPresented: $showingClearCacheAlert) {
            Button("취소", role: .cancel) {}
            Button("삭제", role: .destructive) {
                clearCache()
            }
        } message: {
            Text("저장된 임시 데이터를 모두 삭제하시겠습니까?")
        }
        .alert("설정 초기화", isPresented: $showingResetAlert) {
            Button("취소", role: .cancel) {}
            Button("초기화", role: .destructive) {
                resetSettings()
            }
        } message: {
            Text("모든 설정이 기본값으로 복원됩니다. 계속하시겠습니까?")
        }
        .onAppear {
            loadSettings()
        }
    }
    
    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: UserDefaultsKeys.userPreferences),
           let loadedPreferences = try? JSONDecoder().decode(UserPreferences.self, from: data) {
            preferences = loadedPreferences
        }
    }
    
    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(encoded, forKey: UserDefaultsKeys.userPreferences)
        }
        
        // 테마 변경 알림
        NotificationCenter.default.post(
            name: Notification.Name(NotificationNames.themeDidChange),
            object: preferences.themeMode
        )
    }
    
    private func applyThemeChange() {
        // 테마 변경 로직 (필요시 구현)
        saveSettings()
    }
    
    private func clearCache() {
        CacheManager.shared.clearAll()
        
        // 성공 피드백 (햅틱)
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func resetSettings() {
        preferences = UserPreferences()
        saveSettings()
    }
    
    private func openPrivacyPolicy() {
        // 개인정보 처리방침 웹페이지 열기
        if let url = URL(string: "https://autofinder.example.com/privacy") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openTermsOfService() {
        // 서비스 이용약관 웹페이지 열기
        if let url = URL(string: "https://autofinder.example.com/terms") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - 설정 섹션
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.sm) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Color(UIConstants.Colors.textSecondary))
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                content
            }
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
}

// MARK: - 설정 행
struct SettingsRow<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content
    
    var body: some View {
        HStack(spacing: UIConstants.Spacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(Color(UIConstants.Colors.primaryBlue))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color(UIConstants.Colors.textPrimary))
                
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(Color(UIConstants.Colors.textSecondary))
                }
            }
            
            Spacer()
            
            content
        }
        .padding()
    }
}

// MARK: - 설정 액션 행
struct SettingsActionRow: View {
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
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color(UIConstants.Colors.textPrimary))
                    
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(Color(UIConstants.Colors.textSecondary))
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color(UIConstants.Colors.secondaryGray))
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 선호 지역 설정 뷰
struct PreferredRegionsView: View {
    @Binding var selectedRegions: [String]
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: UIConstants.Spacing.md) {
                ForEach(CarConstants.regions, id: \.self) { region in
                    RegionToggleButton(
                        region: region,
                        isSelected: selectedRegions.contains(region),
                        onToggle: {
                            if selectedRegions.contains(region) {
                                selectedRegions.removeAll { $0 == region }
                            } else {
                                selectedRegions.append(region)
                            }
                        }
                    )
                }
            }
            .padding()
        }
        .navigationTitle("선호 지역")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("완료") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

// MARK: - 지역 토글 버튼
struct RegionToggleButton: View {
    let region: String
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: UIConstants.Spacing.sm) {
                Image(systemName: "location.fill")
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : Color(UIConstants.Colors.primaryBlue))
                
                Text(region)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : Color(UIConstants.Colors.textPrimary))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? Color(UIConstants.Colors.primaryBlue) : Color(UIConstants.Colors.cardBackground))
            .overlay(
                RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium)
                    .stroke(Color(UIConstants.Colors.primaryBlue), lineWidth: isSelected ? 0 : 1)
            )
            .cornerRadius(UIConstants.CornerRadius.medium)
        }
    }
}

// MARK: - 기본 필터 설정 뷰
struct DefaultFiltersView: View {
    @Binding var filters: CarFilterParams
    @Environment(\.presentationMode) var presentationMode
    @State private var tempFilters: CarFilterParams
    
    init(filters: Binding<CarFilterParams>) {
        self._filters = filters
        self._tempFilters = State(initialValue: filters.wrappedValue)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: UIConstants.Spacing.lg) {
                // 가격 범위
                VStack(alignment: .leading, spacing: UIConstants.Spacing.md) {
                    Text("가격 범위")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("최소 가격")
                                .font(.caption)
                                .foregroundColor(Color(UIConstants.Colors.textSecondary))
                            
                            TextField("0", value: $tempFilters.minPrice, format: .number)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        VStack(alignment: .leading) {
                            Text("최대 가격")
                                .font(.caption)
                                .foregroundColor(Color(UIConstants.Colors.textSecondary))
                            
                            TextField("무제한", value: $tempFilters.maxPrice, format: .number)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                }
                
                // 연료 타입
                VStack(alignment: .leading, spacing: UIConstants.Spacing.md) {
                    Text("연료 타입")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: UIConstants.Spacing.sm) {
                        ForEach(CarConstants.fuelTypes, id: \.self) { fuel in
                            Button(action: {
                                tempFilters.fuel = tempFilters.fuel == fuel ? nil : fuel
                            }) {
                                Text(fuel)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(tempFilters.fuel == fuel ? .white : Color(UIConstants.Colors.primaryBlue))
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(tempFilters.fuel == fuel ? Color(UIConstants.Colors.primaryBlue) : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium)
                                            .stroke(Color(UIConstants.Colors.primaryBlue), lineWidth: 1)
                                    )
                                    .cornerRadius(UIConstants.CornerRadius.medium)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("기본 필터")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("저장") {
                    filters = tempFilters
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

// MARK: - 프리뷰
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SettingsView()
                .preferredColorScheme(.light)
                .previewDisplayName("Settings View - Light")
            
            SettingsView()
                .preferredColorScheme(.dark)
                .previewDisplayName("Settings View - Dark")
        }
    }
}
