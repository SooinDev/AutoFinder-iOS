import SwiftUI
import UIKit

// MARK: - 테마 매니저 (싱글톤)
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    // MARK: - Published Properties
    @Published var currentTheme: AppTheme {
        didSet {
            saveTheme()
            applyTheme()
            NotificationCenter.default.post(
                name: Notification.Name(NotificationNames.themeDidChange),
                object: currentTheme
            )
        }
    }
    
    @Published var systemThemeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(systemThemeEnabled, forKey: "system_theme_enabled")
            if systemThemeEnabled {
                updateToSystemTheme()
            }
        }
    }
    
    // MARK: - Theme Properties
    var colors: ThemeColors {
        return currentTheme.colors
    }
    
    var typography: ThemeTypography {
        return currentTheme.typography
    }
    
    var spacing: ThemeSpacing {
        return currentTheme.spacing
    }
    
    var cornerRadius: ThemeCornerRadius {
        return currentTheme.cornerRadius
    }
    
    var shadows: ThemeShadows {
        return currentTheme.shadows
    }
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    
    private init() {
        // 저장된 테마 불러오기
        if let savedThemeRawValue = userDefaults.string(forKey: UserDefaultsKeys.appTheme),
           let savedTheme = AppTheme(rawValue: savedThemeRawValue) {
            self.currentTheme = savedTheme
        } else {
            self.currentTheme = .light
        }
        
        // 시스템 테마 설정 불러오기
        self.systemThemeEnabled = userDefaults.bool(forKey: "system_theme_enabled")
        
        // 시스템 테마가 활성화되어 있으면 현재 시스템 설정 적용
        if systemThemeEnabled {
            updateToSystemTheme()
        }
        
        // 시스템 테마 변경 감지
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemThemeChanged),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        // 초기 테마 적용
        applyTheme()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Theme Management
    
    /// 테마 변경
    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        systemThemeEnabled = false
    }
    
    /// 시스템 테마 토글
    func toggleSystemTheme() {
        systemThemeEnabled.toggle()
    }
    
    /// 다크모드 토글 (시스템 테마 비활성화 상태에서)
    func toggleDarkMode() {
        if !systemThemeEnabled {
            currentTheme = currentTheme == .light ? .dark : .light
        }
    }
    
    /// 현재 시스템 테마로 업데이트
    private func updateToSystemTheme() {
        let interfaceStyle = UITraitCollection.current.userInterfaceStyle
        let systemTheme: AppTheme = interfaceStyle == .dark ? .dark : .light
        
        if currentTheme != systemTheme {
            currentTheme = systemTheme
        }
    }
    
    /// 시스템 테마 변경 감지
    @objc private func systemThemeChanged() {
        if systemThemeEnabled {
            updateToSystemTheme()
        }
    }
    
    /// 테마 저장
    private func saveTheme() {
        userDefaults.set(currentTheme.rawValue, forKey: UserDefaultsKeys.appTheme)
    }
    
    /// 테마 적용
    private func applyTheme() {
        DispatchQueue.main.async {
            // UIKit 컴포넌트에 테마 적용
            self.applyUIKitTheme()
            
            // 상태바 스타일 적용
            self.updateStatusBarStyle()
            
            // 키보드 스타일 적용
            self.updateKeyboardAppearance()
        }
    }
    
    /// UIKit 컴포넌트 테마 적용
    private func applyUIKitTheme() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(colors.cardBackground)
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor(colors.textPrimary),
            .font: UIFont.systemFont(ofSize: typography.headline, weight: .semibold)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(colors.textPrimary),
            .font: UIFont.systemFont(ofSize: typography.largeTitle, weight: .bold)
        ]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // 탭바 외관
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(colors.cardBackground)
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        
        // 기타 컴포넌트
        UITableView.appearance().backgroundColor = UIColor(colors.backgroundColor)
        UITextField.appearance().tintColor = UIColor(colors.primaryBlue)
    }
    
    /// 상태바 스타일 업데이트
    private func updateStatusBarStyle() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            let statusBarStyle: UIStatusBarStyle = currentTheme == .dark ? .lightContent : .darkContent
            
            if #available(iOS 13.0, *) {
                window.overrideUserInterfaceStyle = currentTheme == .dark ? .dark : .light
            }
        }
    }
    
    /// 키보드 외관 업데이트
    private func updateKeyboardAppearance() {
        UITextField.appearance().keyboardAppearance = currentTheme == .dark ? .dark : .light
        UITextView.appearance().keyboardAppearance = currentTheme == .dark ? .dark : .light
    }
}

// MARK: - ThemeManager Extensions

extension ThemeManager {
    
    // MARK: - Color Helpers
    
    /// 동적 색상 생성 (라이트/다크 모드 대응)
    func dynamicColor(light: Color, dark: Color) -> Color {
        return currentTheme == .dark ? dark : light
    }
    
    /// 배경 그라데이션
    var backgroundGradient: LinearGradient {
        return LinearGradient(
            gradient: Gradient(colors: [
                colors.backgroundColor,
                colors.backgroundColor.opacity(0.8)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// 카드 그림자
    var cardShadow: some View {
        return Rectangle()
            .fill(Color.clear)
            .shadow(
                color: shadows.cardShadowColor,
                radius: shadows.cardShadowRadius,
                x: shadows.cardShadowOffset.width,
                y: shadows.cardShadowOffset.height
            )
    }
    
    // MARK: - Animation Helpers
    
    /// 테마 전환 애니메이션
    func withThemeTransition<Result>(_ body: () throws -> Result) rethrows -> Result {
        return try withAnimation(.easeInOut(duration: 0.3)) {
            try body()
        }
    }
    
    // MARK: - Component Styles
    
    /// 기본 버튼 스타일
    var primaryButtonStyle: some ButtonStyle {
        return PrimaryButtonStyle(theme: self)
    }
    
    /// 보조 버튼 스타일
    var secondaryButtonStyle: some ButtonStyle {
        return SecondaryButtonStyle(theme: self)
    }
    
    /// 텍스트 필드 스타일
    var textFieldStyle: some TextFieldStyle {
        return ThemedTextFieldStyle(theme: self)
    }
    
    // MARK: - Utility Methods
    
    /// 색상 접근성 확인
    func hasAccessibleContrast(foreground: Color, background: Color) -> Bool {
        // WCAG 2.1 AA 기준 (4.5:1 대비율)
        let contrastRatio = calculateContrastRatio(foreground: foreground, background: background)
        return contrastRatio >= 4.5
    }
    
    /// 대비율 계산
    private func calculateContrastRatio(foreground: Color, background: Color) -> Double {
        let fgLuminance = getLuminance(color: foreground)
        let bgLuminance = getLuminance(color: background)
        
        let lighter = max(fgLuminance, bgLuminance)
        let darker = min(fgLuminance, bgLuminance)
        
        return (lighter + 0.05) / (darker + 0.05)
    }
    
    /// 휘도 계산
    private func getLuminance(color: Color) -> Double {
        // 간단한 휘도 계산 (실제로는 더 복잡한 계산이 필요)
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return 0.299 * Double(red) + 0.587 * Double(green) + 0.114 * Double(blue)
    }
}

// MARK: - 테마 정의

enum AppTheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case auto = "auto"
    
    var displayName: String {
        switch self {
        case .light: return "라이트"
        case .dark: return "다크"
        case .auto: return "시스템 설정"
        }
    }
    
    var iconName: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .auto: return "circle.lefthalf.filled"
        }
    }
    
    var colors: ThemeColors {
        switch self {
        case .light:
            return LightThemeColors()
        case .dark:
            return DarkThemeColors()
        case .auto:
            // 시스템 설정을 따라가는 경우 현재 시스템 테마 반환
            let interfaceStyle = UITraitCollection.current.userInterfaceStyle
            return interfaceStyle == .dark ? DarkThemeColors() : LightThemeColors()
        }
    }
    
    var typography: ThemeTypography {
        return DefaultTypography()
    }
    
    var spacing: ThemeSpacing {
        return DefaultSpacing()
    }
    
    var cornerRadius: ThemeCornerRadius {
        return DefaultCornerRadius()
    }
    
    var shadows: ThemeShadows {
        switch self {
        case .light:
            return LightShadows()
        case .dark:
            return DarkShadows()
        case .auto:
            let interfaceStyle = UITraitCollection.current.userInterfaceStyle
            return interfaceStyle == .dark ? DarkShadows() : LightShadows()
        }
    }
}

// MARK: - 테마 컴포넌트 프로토콜

protocol ThemeColors {
    var primaryBlue: Color { get }
    var secondaryGray: Color { get }
    var backgroundColor: Color { get }
    var cardBackground: Color { get }
    var textPrimary: Color { get }
    var textSecondary: Color { get }
    var accentColor: Color { get }
    var successColor: Color { get }
    var warningColor: Color { get }
    var errorColor: Color { get }
    var borderColor: Color { get }
    var separatorColor: Color { get }
}

protocol ThemeTypography {
    var largeTitle: CGFloat { get }
    var title1: CGFloat { get }
    var title2: CGFloat { get }
    var title3: CGFloat { get }
    var headline: CGFloat { get }
    var body: CGFloat { get }
    var callout: CGFloat { get }
    var subheadline: CGFloat { get }
    var footnote: CGFloat { get }
    var caption1: CGFloat { get }
    var caption2: CGFloat { get }
}

protocol ThemeSpacing {
    var xs: CGFloat { get }
    var sm: CGFloat { get }
    var md: CGFloat { get }
    var lg: CGFloat { get }
    var xl: CGFloat { get }
    var xxl: CGFloat { get }
}

protocol ThemeCornerRadius {
    var small: CGFloat { get }
    var medium: CGFloat { get }
    var large: CGFloat { get }
    var extraLarge: CGFloat { get }
}

protocol ThemeShadows {
    var cardShadowColor: Color { get }
    var cardShadowRadius: CGFloat { get }
    var cardShadowOffset: CGSize { get }
    var buttonShadowColor: Color { get }
    var buttonShadowRadius: CGFloat { get }
    var buttonShadowOffset: CGSize { get }
}

// MARK: - 라이트 테마 구현

struct LightThemeColors: ThemeColors {
    let primaryBlue = Color(red: 0/255, green: 122/255, blue: 255/255)
    let secondaryGray = Color(red: 142/255, green: 142/255, blue: 147/255)
    let backgroundColor = Color(red: 242/255, green: 242/255, blue: 247/255)
    let cardBackground = Color.white
    let textPrimary = Color.black
    let textSecondary = Color(red: 109/255, green: 109/255, blue: 128/255)
    let accentColor = Color(red: 255/255, green: 59/255, blue: 48/255)
    let successColor = Color(red: 52/255, green: 199/255, blue: 89/255)
    let warningColor = Color(red: 255/255, green: 149/255, blue: 0/255)
    let errorColor = Color(red: 255/255, green: 59/255, blue: 48/255)
    let borderColor = Color(red: 209/255, green: 209/255, blue: 214/255)
    let separatorColor = Color(red: 198/255, green: 198/255, blue: 200/255)
}

struct DarkThemeColors: ThemeColors {
    let primaryBlue = Color(red: 10/255, green: 132/255, blue: 255/255)
    let secondaryGray = Color(red: 174/255, green: 174/255, blue: 178/255)
    let backgroundColor = Color(red: 28/255, green: 28/255, blue: 30/255)
    let cardBackground = Color(red: 44/255, green: 44/255, blue: 46/255)
    let textPrimary = Color.white
    let textSecondary = Color(red: 174/255, green: 174/255, blue: 178/255)
    let accentColor = Color(red: 255/255, green: 69/255, blue: 58/255)
    let successColor = Color(red: 48/255, green: 209/255, blue: 88/255)
    let warningColor = Color(red: 255/255, green: 159/255, blue: 10/255)
    let errorColor = Color(red: 255/255, green: 69/255, blue: 58/255)
    let borderColor = Color(red: 84/255, green: 84/255, blue: 88/255)
    let separatorColor = Color(red: 56/255, green: 56/255, blue: 58/255)
}

struct DefaultTypography: ThemeTypography {
    let largeTitle: CGFloat = 34
    let title1: CGFloat = 28
    let title2: CGFloat = 22
    let title3: CGFloat = 20
    let headline: CGFloat = 17
    let body: CGFloat = 17
    let callout: CGFloat = 16
    let subheadline: CGFloat = 15
    let footnote: CGFloat = 13
    let caption1: CGFloat = 12
    let caption2: CGFloat = 11
}

struct DefaultSpacing: ThemeSpacing {
    let xs: CGFloat = 4
    let sm: CGFloat = 8
    let md: CGFloat = 16
    let lg: CGFloat = 24
    let xl: CGFloat = 32
    let xxl: CGFloat = 48
}

struct DefaultCornerRadius: ThemeCornerRadius {
    let small: CGFloat = 8
    let medium: CGFloat = 12
    let large: CGFloat = 16
    let extraLarge: CGFloat = 20
}

struct LightShadows: ThemeShadows {
    let cardShadowColor = Color.black.opacity(0.1)
    let cardShadowRadius: CGFloat = 8
    let cardShadowOffset = CGSize(width: 0, height: 2)
    let buttonShadowColor = Color.black.opacity(0.15)
    let buttonShadowRadius: CGFloat = 4
    let buttonShadowOffset = CGSize(width: 0, height: 2)
}

struct DarkShadows: ThemeShadows {
    let cardShadowColor = Color.black.opacity(0.3)
    let cardShadowRadius: CGFloat = 12
    let cardShadowOffset = CGSize(width: 0, height: 4)
    let buttonShadowColor = Color.black.opacity(0.4)
    let buttonShadowRadius: CGFloat = 6
    let buttonShadowOffset = CGSize(width: 0, height: 3)
}

// MARK: - 테마 적용 버튼 스타일

struct PrimaryButtonStyle: ButtonStyle {
    let theme: ThemeManager
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                theme.colors.primaryBlue
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .cornerRadius(theme.cornerRadius.medium)
            .shadow(
                color: theme.shadows.buttonShadowColor,
                radius: theme.shadows.buttonShadowRadius,
                x: theme.shadows.buttonShadowOffset.width,
                y: theme.shadows.buttonShadowOffset.height
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    let theme: ThemeManager
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(theme.colors.primaryBlue)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius.medium)
                    .stroke(theme.colors.primaryBlue, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ThemedTextFieldStyle: TextFieldStyle {
    let theme: ThemeManager
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(theme.colors.cardBackground)
            .cornerRadius(theme.cornerRadius.small)
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius.small)
                    .stroke(theme.colors.borderColor, lineWidth: 1)
            )
            .foregroundColor(theme.colors.textPrimary)
    }
}

// MARK: - 테마 적용 뷰 모디파이어

struct ThemedCard: ViewModifier {
    let theme: ThemeManager
    
    func body(content: Content) -> some View {
        content
            .background(theme.colors.cardBackground)
            .cornerRadius(theme.cornerRadius.medium)
            .shadow(
                color: theme.shadows.cardShadowColor,
                radius: theme.shadows.cardShadowRadius,
                x: theme.shadows.cardShadowOffset.width,
                y: theme.shadows.cardShadowOffset.height
            )
    }
}

extension View {
    func themedCard() -> some View {
        self.modifier(ThemedCard(theme: ThemeManager.shared))
    }
}

// MARK: - 테마 설정 뷰

struct ThemeSettingsView: View {
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(spacing: themeManager.spacing.lg) {
            // 테마 선택
            VStack(alignment: .leading, spacing: themeManager.spacing.md) {
                Text("테마 설정")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.colors.textPrimary)
                
                VStack(spacing: themeManager.spacing.sm) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        ThemeOptionView(
                            theme: theme,
                            isSelected: themeManager.currentTheme == theme,
                            onSelect: {
                                themeManager.setTheme(theme)
                            }
                        )
                    }
                }
            }
            
            // 시스템 테마 토글
            VStack(alignment: .leading, spacing: themeManager.spacing.sm) {
                Toggle("시스템 설정 따르기", isOn: $themeManager.systemThemeEnabled)
                    .foregroundColor(themeManager.colors.textPrimary)
                
                Text("기기의 다크 모드 설정을 자동으로 따릅니다")
                    .font(.caption)
                    .foregroundColor(themeManager.colors.textSecondary)
            }
            
            Spacer()
        }
        .padding()
        .background(themeManager.colors.backgroundColor)
    }
}

struct ThemeOptionView: View {
    let theme: AppTheme
    let isSelected: Bool
    let onSelect: () -> Void
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: theme.iconName)
                    .foregroundColor(isSelected ? .white : themeManager.colors.primaryBlue)
                    .font(.title3)
                
                Text(theme.displayName)
                    .foregroundColor(isSelected ? .white : themeManager.colors.textPrimary)
                    .fontWeight(.medium)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                        .font(.title3)
                }
            }
            .padding()
            .background(isSelected ? themeManager.colors.primaryBlue : themeManager.colors.cardBackground)
            .cornerRadius(themeManager.cornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: themeManager.cornerRadius.medium)
                    .stroke(
                        isSelected ? Color.clear : themeManager.colors.borderColor,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 프리뷰
struct ThemeManager_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ThemeSettingsView()
                .preferredColorScheme(.light)
                .previewDisplayName("Theme Settings - Light")
            
            ThemeSettingsView()
                .preferredColorScheme(.dark)
                .previewDisplayName("Theme Settings - Dark")
        }
    }
}
