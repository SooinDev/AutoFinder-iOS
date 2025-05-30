import Foundation
import UIKit
import SwiftUI

// MARK: - 검증 헬퍼 클래스
class ValidationHelper {
    
    // MARK: - 사용자 입력 검증
    
    /// 아이디 검증
    static func validateUsername(_ username: String) -> ValidationResult {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 빈 값 체크
        guard !trimmedUsername.isEmpty else {
            return .failure("아이디를 입력해주세요")
        }
        
        // 길이 체크
        guard trimmedUsername.count >= 3 else {
            return .failure("아이디는 3자 이상이어야 합니다")
        }
        
        guard trimmedUsername.count <= 20 else {
            return .failure("아이디는 20자 이하여야 합니다")
        }
        
        // 문자 규칙 체크 (영문, 숫자, 언더스코어만 허용)
        let allowedCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        guard trimmedUsername.unicodeScalars.allSatisfy({ allowedCharacterSet.contains($0) }) else {
            return .failure("아이디는 영문, 숫자, 언더스코어만 사용 가능합니다")
        }
        
        // 첫 글자는 영문이어야 함
        guard let firstCharacter = trimmedUsername.first,
              firstCharacter.isLetter else {
            return .failure("아이디는 영문으로 시작해야 합니다")
        }
        
        // 예약어 체크
        let reservedWords = ["admin", "root", "user", "test", "guest", "null", "undefined"]
        guard !reservedWords.contains(trimmedUsername.lowercased()) else {
            return .failure("사용할 수 없는 아이디입니다")
        }
        
        return .success
    }
    
    /// 비밀번호 검증
    static func validatePassword(_ password: String) -> ValidationResult {
        // 빈 값 체크
        guard !password.isEmpty else {
            return .failure("비밀번호를 입력해주세요")
        }
        
        // 길이 체크
        guard password.count >= 6 else {
            return .failure("비밀번호는 6자 이상이어야 합니다")
        }
        
        guard password.count <= 50 else {
            return .failure("비밀번호는 50자 이하여야 합니다")
        }
        
        // 공백 체크
        guard !password.contains(" ") else {
            return .failure("비밀번호에는 공백을 사용할 수 없습니다")
        }
        
        // 보안 강도 체크 (선택사항)
        let strength = calculatePasswordStrength(password)
        if strength == .weak && password.count < 8 {
            return .warning("더 안전한 비밀번호를 사용하는 것을 권장합니다")
        }
        
        return .success
    }
    
    /// 비밀번호 확인 검증
    static func validatePasswordConfirmation(_ password: String, _ confirmation: String) -> ValidationResult {
        guard !confirmation.isEmpty else {
            return .failure("비밀번호 확인을 입력해주세요")
        }
        
        guard password == confirmation else {
            return .failure("비밀번호가 일치하지 않습니다")
        }
        
        return .success
    }
    
    /// 이메일 검증
    static func validateEmail(_ email: String) -> ValidationResult {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedEmail.isEmpty else {
            return .failure("이메일을 입력해주세요")
        }
        
        let emailRegex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        
        guard emailPredicate.evaluate(with: trimmedEmail) else {
            return .failure("올바른 이메일 형식이 아닙니다")
        }
        
        return .success
    }
    
    /// 전화번호 검증
    static func validatePhoneNumber(_ phoneNumber: String) -> ValidationResult {
        let cleanedNumber = phoneNumber.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        guard !cleanedNumber.isEmpty else {
            return .failure("전화번호를 입력해주세요")
        }
        
        // 한국 전화번호 패턴
        let patterns = [
            "^010[0-9]{8}$",     // 010-xxxx-xxxx
            "^02[0-9]{7,8}$",    // 02-xxx(x)-xxxx
            "^0[3-6][1-9][0-9]{6,7}$", // 지역번호
            "^070[0-9]{8}$"      // 070-xxxx-xxxx
        ]
        
        let isValid = patterns.contains { pattern in
            let predicate = NSPredicate(format: "SELF MATCHES %@", pattern)
            return predicate.evaluate(with: cleanedNumber)
        }
        
        guard isValid else {
            return .failure("올바른 전화번호 형식이 아닙니다")
        }
        
        return .success
    }
    
    // MARK: - 차량 관련 검증
    
    /// 차량 가격 검증
    static func validateCarPrice(_ priceString: String) -> ValidationResult {
        let cleanedPrice = priceString.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        guard !cleanedPrice.isEmpty else {
            return .failure("가격을 입력해주세요")
        }
        
        guard let price = Int(cleanedPrice) else {
            return .failure("올바른 가격을 입력해주세요")
        }
        
        guard price >= 10 else {
            return .failure("가격은 10만원 이상이어야 합니다")
        }
        
        guard price <= 100000 else {
            return .failure("가격은 10억원 이하여야 합니다")
        }
        
        return .success
    }
    
    /// 주행거리 검증
    static func validateMileage(_ mileageString: String) -> ValidationResult {
        let cleanedMileage = mileageString.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        guard !cleanedMileage.isEmpty else {
            return .failure("주행거리를 입력해주세요")
        }
        
        guard let mileage = Int(cleanedMileage) else {
            return .failure("올바른 주행거리를 입력해주세요")
        }
        
        guard mileage >= 0 else {
            return .failure("주행거리는 0 이상이어야 합니다")
        }
        
        guard mileage <= 1000000 else {
            return .failure("주행거리가 너무 큽니다")
        }
        
        return .success
    }
    
    /// 연식 검증
    static func validateCarYear(_ yearString: String) -> ValidationResult {
        let cleanedYear = yearString.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        guard !cleanedYear.isEmpty else {
            return .failure("연식을 입력해주세요")
        }
        
        guard let year = Int(cleanedYear) else {
            return .failure("올바른 연식을 입력해주세요")
        }
        
        let currentYear = Calendar.current.component(.year, from: Date())
        
        guard year >= 1990 else {
            return .failure("1990년 이후 차량만 등록 가능합니다")
        }
        
        guard year <= currentYear + 1 else {
            return .failure("올바른 연식을 입력해주세요")
        }
        
        return .success
    }
    
    // MARK: - 검색 관련 검증
    
    /// 검색어 검증
    static func validateSearchQuery(_ query: String) -> ValidationResult {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedQuery.isEmpty else {
            return .failure("검색어를 입력해주세요")
        }
        
        guard trimmedQuery.count >= 2 else {
            return .failure("검색어는 2자 이상 입력해주세요")
        }
        
        guard trimmedQuery.count <= 50 else {
            return .failure("검색어는 50자 이하로 입력해주세요")
        }
        
        // 특수문자 체크 (기본적인 특수문자만 허용)
        let allowedCharacterSet = CharacterSet.alphanumerics
            .union(CharacterSet.whitespaces)
            .union(CharacterSet(charactersIn: ".-_()[]"))
        
        guard trimmedQuery.unicodeScalars.allSatisfy({ allowedCharacterSet.contains($0) }) else {
            return .failure("허용되지 않는 문자가 포함되어 있습니다")
        }
        
        return .success
    }
    
    // MARK: - 일반적인 텍스트 검증
    
    /// 이름 검증
    static func validateName(_ name: String) -> ValidationResult {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            return .failure("이름을 입력해주세요")
        }
        
        guard trimmedName.count >= 2 else {
            return .failure("이름은 2자 이상 입력해주세요")
        }
        
        guard trimmedName.count <= 20 else {
            return .failure("이름은 20자 이하로 입력해주세요")
        }
        
        // 한글, 영문만 허용
        let allowedCharacterSet = CharacterSet(charactersIn: "가-힣ㄱ-ㅎㅏ-ㅣa-zA-Z ")
        guard trimmedName.unicodeScalars.allSatisfy({ allowedCharacterSet.contains($0) }) else {
            return .failure("이름은 한글 또는 영문만 입력 가능합니다")
        }
        
        return .success
    }
    
    /// 메모/코멘트 검증
    static func validateComment(_ comment: String) -> ValidationResult {
        let trimmedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 빈 값은 허용
        guard !trimmedComment.isEmpty else {
            return .success
        }
        
        guard trimmedComment.count <= 500 else {
            return .failure("코멘트는 500자 이하로 입력해주세요")
        }
        
        // 금지어 체크
        let bannedWords = ["욕설", "비방", "광고"]
        let containsBannedWord = bannedWords.contains { bannedWord in
            trimmedComment.lowercased().contains(bannedWord)
        }
        
        guard !containsBannedWord else {
            return .failure("부적절한 내용이 포함되어 있습니다")
        }
        
        return .success
    }
    
    // MARK: - 비밀번호 강도 계산
    
    static func calculatePasswordStrength(_ password: String) -> PasswordStrength {
        var score = 0
        
        // 길이 점수
        if password.count >= 6 { score += 1 }
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        
        // 문자 종류 점수
        if password.range(of: "[a-z]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[A-Z]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[0-9]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[^a-zA-Z0-9]", options: .regularExpression) != nil { score += 1 }
        
        // 연속된 문자 체크 (감점)
        if hasConsecutiveCharacters(password) { score -= 1 }
        if hasRepeatingCharacters(password) { score -= 1 }
        
        switch score {
        case 0...2: return .weak
        case 3...4: return .medium
        case 5...6: return .strong
        default: return .veryStrong
        }
    }
    
    private static func hasConsecutiveCharacters(_ password: String) -> Bool {
        let chars = Array(password.lowercased())
        for i in 0..<(chars.count - 2) {
            let first = chars[i].asciiValue ?? 0
            let second = chars[i + 1].asciiValue ?? 0
            let third = chars[i + 2].asciiValue ?? 0
            
            if second == first + 1 && third == second + 1 {
                return true
            }
        }
        return false
    }
    
    private static func hasRepeatingCharacters(_ password: String) -> Bool {
        let chars = Array(password.lowercased())
        for i in 0..<(chars.count - 2) {
            if chars[i] == chars[i + 1] && chars[i + 1] == chars[i + 2] {
                return true
            }
        }
        return false
    }
    
    // MARK: - 형식 검증 도우미
    
    /// URL 검증
    static func validateURL(_ urlString: String) -> ValidationResult {
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedURL.isEmpty else {
            return .failure("URL을 입력해주세요")
        }
        
        guard let url = URL(string: trimmedURL), UIApplication.shared.canOpenURL(url) else {
            return .failure("올바른 URL 형식이 아닙니다")
        }
        
        return .success
    }
    
    /// 숫자 범위 검증
    static func validateNumberRange(_ numberString: String, min: Int, max: Int, fieldName: String) -> ValidationResult {
        let cleanedNumber = numberString.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        guard !cleanedNumber.isEmpty else {
            return .failure("\(fieldName)을(를) 입력해주세요")
        }
        
        guard let number = Int(cleanedNumber) else {
            return .failure("올바른 \(fieldName)을(를) 입력해주세요")
        }
        
        guard number >= min else {
            return .failure("\(fieldName)은(는) \(min) 이상이어야 합니다")
        }
        
        guard number <= max else {
            return .failure("\(fieldName)은(는) \(max) 이하여야 합니다")
        }
        
        return .success
    }
    
    // MARK: - 실시간 검증 도우미
    
    /// 입력 중 실시간 검증 (키 입력마다)
    static func validateAsTyping(_ text: String, validationType: ValidationType) -> ValidationResult {
        switch validationType {
        case .username:
            return validateUsernameAsTyping(text)
        case .password:
            return validatePasswordAsTyping(text)
        case .email:
            return validateEmailAsTyping(text)
        case .phoneNumber:
            return validatePhoneNumberAsTyping(text)
        case .searchQuery:
            return validateSearchQueryAsTyping(text)
        }
    }
    
    private static func validateUsernameAsTyping(_ username: String) -> ValidationResult {
        // 실시간 검증은 더 관대하게
        if username.isEmpty {
            return .success // 입력 중일 때는 빈 값 허용
        }
        
        if username.count > 20 {
            return .failure("아이디는 20자 이하여야 합니다")
        }
        
        // 허용되지 않는 문자 체크
        let allowedCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        if !username.unicodeScalars.allSatisfy({ allowedCharacterSet.contains($0) }) {
            return .failure("영문, 숫자, 언더스코어만 사용 가능합니다")
        }
        
        return .success
    }
    
    private static func validatePasswordAsTyping(_ password: String) -> ValidationResult {
        if password.isEmpty {
            return .success
        }
        
        if password.count > 50 {
            return .failure("비밀번호는 50자 이하여야 합니다")
        }
        
        if password.contains(" ") {
            return .failure("비밀번호에는 공백을 사용할 수 없습니다")
        }
        
        return .success
    }
    
    private static func validateEmailAsTyping(_ email: String) -> ValidationResult {
        if email.isEmpty {
            return .success
        }
        
        // 기본적인 @ 문자 존재 여부만 체크
        if email.contains("@") && email.components(separatedBy: "@").count == 2 {
            return .success
        }
        
        return .warning("이메일 형식을 확인해주세요")
    }
    
    private static func validatePhoneNumberAsTyping(_ phoneNumber: String) -> ValidationResult {
        let cleanedNumber = phoneNumber.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        if cleanedNumber.isEmpty {
            return .success
        }
        
        if cleanedNumber.count > 11 {
            return .failure("전화번호가 너무 깁니다")
        }
        
        return .success
    }
    
    private static func validateSearchQueryAsTyping(_ query: String) -> ValidationResult {
        if query.isEmpty {
            return .success
        }
        
        if query.count > 50 {
            return .failure("검색어는 50자 이하로 입력해주세요")
        }
        
        return .success
    }
    
    // MARK: - 복합 검증
    
    /// 여러 필드를 한번에 검증
    static func validateMultipleFields(_ validations: [(String, ValidationResult)]) -> ValidationResult {
        for (fieldName, result) in validations {
            switch result {
            case .failure(let message):
                return .failure("\(fieldName): \(message)")
            case .warning(let message):
                return .warning("\(fieldName): \(message)")
            case .success:
                continue
            }
        }
        return .success
    }
    
    /// 폼 전체 검증
    static func validateForm(_ form: [String: String], rules: [String: ValidationType]) -> [String: ValidationResult] {
        var results: [String: ValidationResult] = [:]
        
        for (fieldName, validationType) in rules {
            let value = form[fieldName] ?? ""
            
            switch validationType {
            case .username:
                results[fieldName] = validateUsername(value)
            case .password:
                results[fieldName] = validatePassword(value)
            case .email:
                results[fieldName] = validateEmail(value)
            case .phoneNumber:
                results[fieldName] = validatePhoneNumber(value)
            case .searchQuery:
                results[fieldName] = validateSearchQuery(value)
            }
        }
        
        return results
    }
}

// MARK: - 검증 결과 열거형

enum ValidationResult: Equatable {
    case success
    case warning(String)
    case failure(String)
    
    var isValid: Bool {
        switch self {
        case .success, .warning:
            return true
        case .failure:
            return false
        }
    }
    
    var message: String? {
        switch self {
        case .success:
            return nil
        case .warning(let message), .failure(let message):
            return message
        }
    }
    
    var isWarning: Bool {
        switch self {
        case .warning:
            return true
        default:
            return false
        }
    }
    
    var isFailure: Bool {
        switch self {
        case .failure:
            return true
        default:
            return false
        }
    }
}

// MARK: - 검증 타입 열거형

enum ValidationType {
    case username
    case password
    case email
    case phoneNumber
    case searchQuery
}

// MARK: - 비밀번호 강도 열거형

//enum PasswordStrength: Int, CaseIterable {
//    case weak = 1
//    case medium = 2
//    case strong = 3
//    case veryStrong = 4
//    
//    var displayName: String {
//        switch self {
//        case .weak: return "약함"
//        case .medium: return "보통"
//        case .strong: return "강함"
//        case .veryStrong: return "매우 강함"
//        }
//    }
//    
//    var color: String {
//        switch self {
//        case .weak: return "red"
//        case .medium: return "orange"
//        case .strong: return "green"
//        case .veryStrong: return "blue"
//        }
//    }
//    
//    var progress: Double {
//        return Double(rawValue) / 4.0
//    }
//}

// MARK: - 검증 결과 뷰 헬퍼

struct ValidationResultView: View {
    let result: ValidationResult
    
    var body: some View {
        if let message = result.message {
            HStack {
                Image(systemName: iconName)
                    .foregroundColor(iconColor)
                
                Text(message)
                    .font(.caption)
                    .foregroundColor(textColor)
                
                Spacer()
            }
        }
    }
    
    private var iconName: String {
        switch result {
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .failure:
            return "xmark.circle.fill"
        }
    }
    
    private var iconColor: Color {
        switch result {
        case .success:
            return .green
        case .warning:
            return .orange
        case .failure:
            return .red
        }
    }
    
    private var textColor: Color {
        switch result {
        case .success:
            return .green
        case .warning:
            return .orange
        case .failure:
            return .red
        }
    }
}

// MARK: - 실시간 검증 뷰 모디파이어

struct RealTimeValidation: ViewModifier {
    let text: String
    let validationType: ValidationType
    @State private var validationResult: ValidationResult = .success
    
    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            content
                .onChange(of: text) { newValue in
                    validationResult = ValidationHelper.validateAsTyping(newValue, validationType: validationType)
                }
            
            ValidationResultView(result: validationResult)
        }
    }
}

extension View {
    func withRealTimeValidation(text: String, type: ValidationType) -> some View {
        self.modifier(RealTimeValidation(text: text, validationType: type))
    }
}

// MARK: - 검증 헬퍼 확장

extension ValidationHelper {
    
    /// 한국어 입력 검증
    static func validateKoreanText(_ text: String, minLength: Int = 1, maxLength: Int = 100) -> ValidationResult {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedText.isEmpty else {
            return .failure("텍스트를 입력해주세요")
        }
        
        guard trimmedText.count >= minLength else {
            return .failure("최소 \(minLength)자 이상 입력해주세요")
        }
        
        guard trimmedText.count <= maxLength else {
            return .failure("최대 \(maxLength)자까지 입력 가능합니다")
        }
        
        // 한글 체크
        let koreanRange = "가"..."힣"
        let hasKorean = trimmedText.contains { char in
            koreanRange.contains(String(char))
        }
        
        if !hasKorean && trimmedText.count > 0 {
            return .warning("한국어 입력을 권장합니다")
        }
        
        return .success
    }
    
    /// 숫자 포맷 검증 (쉼표, 단위 포함)
    static func validateFormattedNumber(_ numberString: String) -> ValidationResult {
        let cleanedNumber = numberString
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "만원", with: "")
            .replacingOccurrences(of: "원", with: "")
            .replacingOccurrences(of: " ", with: "")
        
        guard !cleanedNumber.isEmpty else {
            return .failure("숫자를 입력해주세요")
        }
        
        guard Int(cleanedNumber) != nil else {
            return .failure("올바른 숫자 형식이 아닙니다")
        }
        
        return .success
    }
}

// MARK: - 검증 디버그 도구 (디버그 모드에서만 사용)

#if DEBUG
extension ValidationHelper {
    static func debugValidation(_ text: String, type: ValidationType) {
        let result = validateAsTyping(text, validationType: type)
        print("🔍 Validation Debug - Input: '\(text)', Type: \(type), Result: \(result)")
    }
    
    static func printPasswordStrength(_ password: String) {
        let strength = calculatePasswordStrength(password)
        print("🔐 Password Strength: \(password) -> \(strength.displayName) (\(strength.rawValue)/4)")
    }
}
#endif
