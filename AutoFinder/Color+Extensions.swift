import SwiftUI

// MARK: - Color Extensions
extension Color {
    
    // MARK: - App Colors (Asset Catalog 대신 코드로 정의)
    
    static let primaryBlue = Color(red: 0/255, green: 122/255, blue: 255/255)
    static let secondaryGray = Color(red: 142/255, green: 142/255, blue: 147/255)
    static let backgroundColor = Color(UIColor.systemBackground)
    static let cardBackground = Color(UIColor.secondarySystemBackground)
    static let textPrimary = Color(UIColor.label)
    static let textSecondary = Color(UIColor.secondaryLabel)
    static let accentColor = Color(red: 255/255, green: 59/255, blue: 48/255)
    static let successColor = Color(red: 52/255, green: 199/255, blue: 89/255)
    static let warningColor = Color(red: 255/255, green: 149/255, blue: 0/255)
    
    // MARK: - App Colors Namespace
    struct AppColors {
        static let primaryBlue = Color.primaryBlue
        static let secondaryGray = Color.secondaryGray
        static let backgroundColor = Color.backgroundColor
        static let cardBackground = Color.cardBackground
        static let textPrimary = Color.textPrimary
        static let textSecondary = Color.textSecondary
        static let accentColor = Color.accentColor
        static let successColor = Color.successColor
        static let warningColor = Color.warningColor
    }
}

// MARK: - Color Helper Functions
extension Color {
    
    /// 문자열로부터 Color 생성 (UIConstants 호환성)
    static func fromUIConstants(_ colorName: String) -> Color {
        switch colorName {
        case "PrimaryBlue":
            return .primaryBlue
        case "SecondaryGray":
            return .secondaryGray
        case "BackgroundColor":
            return .backgroundColor
        case "CardBackground":
            return .cardBackground
        case "TextPrimary":
            return .textPrimary
        case "TextSecondary":
            return .textSecondary
        case "AccentColor":
            return .accentColor
        case "SuccessColor":
            return .successColor
        case "WarningColor":
            return .warningColor
        default:
            // 기본 색상 반환
            return .primary
        }
    }
    
    /// Asset Catalog에서 색상을 로드하되 실패 시 기본 색상 사용
    static func safeAssetColor(_ name: String, fallback: Color = .primary) -> Color {
        if let uiColor = UIColor(named: name) {
            return Color(uiColor)
        } else {
            return fallback
        }
    }
}

// MARK: - Dark Mode 대응 색상
extension Color {
    
    /// 다크모드 대응 Primary Blue
    static var adaptivePrimaryBlue: Color {
        Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(red: 10/255, green: 132/255, blue: 255/255, alpha: 1.0)
            default:
                return UIColor(red: 0/255, green: 122/255, blue: 255/255, alpha: 1.0)
            }
        })
    }
    
    /// 다크모드 대응 배경색
    static var adaptiveBackground: Color {
        Color(UIColor.systemBackground)
    }
    
    /// 다크모드 대응 카드 배경색
    static var adaptiveCardBackground: Color {
        Color(UIColor.secondarySystemBackground)
    }
    
    /// 다크모드 대응 텍스트 색상
    static var adaptiveTextPrimary: Color {
        Color(UIColor.label)
    }
    
    /// 다크모드 대응 보조 텍스트 색상
    static var adaptiveTextSecondary: Color {
        Color(UIColor.secondaryLabel)
    }
}

// MARK: - UIConstants 호환성을 위한 생성자
extension Color {
    
    /// UIConstants 문자열을 Color로 변환하는 생성자
    init(_ uiConstantColorName: String) {
        self = Color.fromUIConstants(uiConstantColorName)
    }
}

// MARK: - 색상 유틸리티
extension Color {
    
    /// Hex 색상 코드로부터 Color 생성
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    /// RGB 값으로부터 Color 생성
    init(red255: Double, green255: Double, blue255: Double, alpha: Double = 1.0) {
        self.init(
            red: red255 / 255.0,
            green: green255 / 255.0,
            blue: blue255 / 255.0,
            opacity: alpha
        )
    }
}

// MARK: - 색상 테마 관리자 (간단 버전)
class SimpleColorManager: ObservableObject {
    static let shared = SimpleColorManager()
    
    @Published var isDarkMode: Bool = false
    
    private init() {
        // 시스템 다크모드 설정 감지
        isDarkMode = UITraitCollection.current.userInterfaceStyle == .dark
    }
    
    func getPrimaryColor() -> Color {
        return isDarkMode ? Color.adaptivePrimaryBlue : Color.primaryBlue
    }
    
    func getBackgroundColor() -> Color {
        return Color.adaptiveBackground
    }
    
    func getTextColor() -> Color {
        return Color.adaptiveTextPrimary
    }
}

// MARK: - View Extension for Easy Color Access
extension View {
    
    /// 앱의 기본 색상을 쉽게 사용할 수 있는 헬퍼
    func appPrimaryColor() -> some View {
        self.foregroundColor(.primaryBlue)
    }
    
    func appBackgroundColor() -> some View {
        self.background(Color.backgroundColor)
    }
    
    func appCardBackground() -> some View {
        self.background(Color.cardBackground)
    }
    
    func appTextPrimary() -> some View {
        self.foregroundColor(.textPrimary)
    }
    
    func appTextSecondary() -> some View {
        self.foregroundColor(.textSecondary)
    }
}
