import Foundation

// MARK: - DateFormatter 확장
extension DateFormatter {
    
    // MARK: - 공통 포맷터들
    
    /// 표시용 날짜 포맷터 (2024년 1월 1일)
    static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()
    
    /// 간단한 날짜 포맷터 (2024.01.01)
    static let shortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()
    
    /// 시간 포함 포맷터 (2024.01.01 09:30)
    static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        return formatter
    }()
    
    /// 시간만 포맷터 (09:30)
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    /// 월일 포맷터 (1월 1일)
    static let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일"
        return formatter
    }()
    
    /// 연월 포맷터 (2024년 1월)
    static let yearMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월"
        return formatter
    }()
    
    /// ISO 8601 포맷터 (서버 통신용)
    static let iso8601Formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter
    }()
    
    /// API 응답용 포맷터 (yyyy-MM-dd HH:mm:ss)
    static let apiFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    // MARK: - 상대적 시간 포맷터
    
    /// 상대적 시간 포맷터 (3분 전, 1시간 전)
    static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
    
    /// 긴 상대적 시간 포맷터 (3분 전, 1시간 전)
    static let relativeLongFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.unitsStyle = .full
        return formatter
    }()
}

// MARK: - Date 확장
extension Date {
    
    // MARK: - 표시용 문자열 생성
    
    /// 표시용 날짜 문자열 (2024년 1월 1일)
    var displayString: String {
        return DateFormatter.displayFormatter.string(from: self)
    }
    
    /// 간단한 날짜 문자열 (2024.01.01)
    var shortString: String {
        return DateFormatter.shortFormatter.string(from: self)
    }
    
    /// 날짜시간 문자열 (2024.01.01 09:30)
    var dateTimeString: String {
        return DateFormatter.dateTimeFormatter.string(from: self)
    }
    
    /// 시간 문자열 (09:30)
    var timeString: String {
        return DateFormatter.timeFormatter.string(from: self)
    }
    
    /// 월일 문자열 (1월 1일)
    var monthDayString: String {
        return DateFormatter.monthDayFormatter.string(from: self)
    }
    
    /// 연월 문자열 (2024년 1월)
    var yearMonthString: String {
        return DateFormatter.yearMonthFormatter.string(from: self)
    }
    
    /// ISO 8601 문자열 (서버 전송용)
    var iso8601String: String {
        return DateFormatter.iso8601Formatter.string(from: self)
    }
    
    /// API 전송용 문자열
    var apiString: String {
        return DateFormatter.apiFormatter.string(from: self)
    }
    
    // MARK: - 상대적 시간
    
    /// 상대적 시간 문자열 (3분 전, 1시간 전)
    var relativeString: String {
        return DateFormatter.relativeFormatter.localizedString(for: self, relativeTo: Date())
    }
    
    /// 긴 상대적 시간 문자열 (3분 전, 1시간 전)
    var relativeLongString: String {
        return DateFormatter.relativeLongFormatter.localizedString(for: self, relativeTo: Date())
    }
    
    // MARK: - 스마트 표시 (시간에 따라 다른 포맷)
    
    /// 스마트 날짜 표시 (오늘이면 시간만, 이번주면 요일, 그 외는 날짜)
    var smartDisplayString: String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(self) {
            // 오늘이면 시간만 표시
            return timeString
        } else if calendar.isDateInYesterday(self) {
            // 어제면 "어제" + 시간
            return "어제 \(timeString)"
        } else if calendar.isDate(self, equalTo: now, toGranularity: .weekOfYear) {
            // 이번 주면 요일 표시
            let weekdayFormatter = DateFormatter()
            weekdayFormatter.locale = Locale(identifier: "ko_KR")
            weekdayFormatter.dateFormat = "EEEE"
            return weekdayFormatter.string(from: self)
        } else if calendar.isDate(self, equalTo: now, toGranularity: .year) {
            // 올해면 월일만 표시
            return monthDayString
        } else {
            // 다른 해면 전체 날짜 표시
            return shortString
        }
    }
    
    /// 차량 등록일 표시용 (등록 시점에 따라 다른 포맷)
    var carRegistrationDisplayString: String {
        let now = Date()
        let daysSinceRegistration = Calendar.current.dateComponents([.day], from: self, to: now).day ?? 0
        
        if daysSinceRegistration == 0 {
            return "오늘 등록"
        } else if daysSinceRegistration == 1 {
            return "어제 등록"
        } else if daysSinceRegistration < 7 {
            return "\(daysSinceRegistration)일 전 등록"
        } else if daysSinceRegistration < 30 {
            let weeks = daysSinceRegistration / 7
            return "\(weeks)주 전 등록"
        } else if daysSinceRegistration < 365 {
            let months = daysSinceRegistration / 30
            return "\(months)개월 전 등록"
        } else {
            return shortString + " 등록"
        }
    }
    
    // MARK: - 날짜 계산
    
    /// 특정 일수만큼 더한 날짜
    func addingDays(_ days: Int) -> Date {
        return Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }
    
    /// 특정 주수만큼 더한 날짜
    func addingWeeks(_ weeks: Int) -> Date {
        return Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: self) ?? self
    }
    
    /// 특정 월수만큼 더한 날짜
    func addingMonths(_ months: Int) -> Date {
        return Calendar.current.date(byAdding: .month, value: months, to: self) ?? self
    }
    
    /// 특정 년수만큼 더한 날짜
    func addingYears(_ years: Int) -> Date {
        return Calendar.current.date(byAdding: .year, value: years, to: self) ?? self
    }
    
    /// 두 날짜 사이의 일수
    func daysBetween(_ otherDate: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: self, to: otherDate)
        return components.day ?? 0
    }
    
    /// 두 날짜 사이의 월수
    func monthsBetween(_ otherDate: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month], from: self, to: otherDate)
        return components.month ?? 0
    }
    
    /// 두 날짜 사이의 년수
    func yearsBetween(_ otherDate: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: self, to: otherDate)
        return components.year ?? 0
    }
    
    // MARK: - 날짜 검증
    
    /// 오늘인지 확인
    var isToday: Bool {
        return Calendar.current.isDateInToday(self)
    }
    
    /// 어제인지 확인
    var isYesterday: Bool {
        return Calendar.current.isDateInYesterday(self)
    }
    
    /// 이번 주인지 확인
    var isThisWeek: Bool {
        return Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }
    
    /// 이번 달인지 확인
    var isThisMonth: Bool {
        return Calendar.current.isDate(self, equalTo: Date(), toGranularity: .month)
    }
    
    /// 올해인지 확인
    var isThisYear: Bool {
        return Calendar.current.isDate(self, equalTo: Date(), toGranularity: .year)
    }
    
    /// 과거인지 확인
    var isPast: Bool {
        return self < Date()
    }
    
    /// 미래인지 확인
    var isFuture: Bool {
        return self > Date()
    }
    
    /// 주말인지 확인
    var isWeekend: Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: self)
        return weekday == 1 || weekday == 7 // 일요일(1) 또는 토요일(7)
    }
    
    // MARK: - 날짜 구성요소
    
    /// 연도
    var year: Int {
        return Calendar.current.component(.year, from: self)
    }
    
    /// 월
    var month: Int {
        return Calendar.current.component(.month, from: self)
    }
    
    /// 일
    var day: Int {
        return Calendar.current.component(.day, from: self)
    }
    
    /// 시간
    var hour: Int {
        return Calendar.current.component(.hour, from: self)
    }
    
    /// 분
    var minute: Int {
        return Calendar.current.component(.minute, from: self)
    }
    
    /// 요일 (1: 일요일, 7: 토요일)
    var weekday: Int {
        return Calendar.current.component(.weekday, from: self)
    }
    
    /// 한국어 요일명
    var weekdayName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: self)
    }
    
    /// 한국어 짧은 요일명 (월, 화, 수...)
    var shortWeekdayName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "E"
        return formatter.string(from: self)
    }
}

// MARK: - String to Date 변환
extension String {
    
    /// ISO 8601 문자열을 Date로 변환
    var iso8601Date: Date? {
        return DateFormatter.iso8601Formatter.date(from: self)
    }
    
    /// API 응답 문자열을 Date로 변환
    var apiDate: Date? {
        return DateFormatter.apiFormatter.date(from: self)
    }
    
    /// 간단한 날짜 문자열을 Date로 변환 (yyyy.MM.dd)
    var shortDate: Date? {
        return DateFormatter.shortFormatter.date(from: self)
    }
    
    /// 날짜시간 문자열을 Date로 변환 (yyyy.MM.dd HH:mm)
    var dateTime: Date? {
        return DateFormatter.dateTimeFormatter.date(from: self)
    }
    
    /// 다양한 포맷으로 Date 변환 시도
    var smartDate: Date? {
        let formatters = [
            DateFormatter.iso8601Formatter,
            DateFormatter.apiFormatter,
            DateFormatter.dateTimeFormatter,
            DateFormatter.shortFormatter
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: self) {
                return date
            }
        }
        
        return nil
    }
}

// MARK: - 시간 간격 유틸리티
extension TimeInterval {
    
    /// 분 단위로 변환
    var minutes: Double {
        return self / 60
    }
    
    /// 시간 단위로 변환
    var hours: Double {
        return self / 3600
    }
    
    /// 일 단위로 변환
    var days: Double {
        return self / 86400
    }
    
    /// 사람이 읽기 쉬운 형태로 변환
    var humanReadable: String {
        let hours = Int(self) / 3600
        let minutes = Int(self) % 3600 / 60
        let seconds = Int(self) % 60
        
        if hours > 0 {
            return "\(hours)시간 \(minutes)분"
        } else if minutes > 0 {
            return "\(minutes)분 \(seconds)초"
        } else {
            return "\(seconds)초"
        }
    }
}

// MARK: - 편의 생성자
extension Date {
    
    /// 연월일로 Date 생성
    init?(year: Int, month: Int, day: Int) {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        
        guard let date = Calendar.current.date(from: components) else {
            return nil
        }
        
        self = date
    }
    
    /// 연월일시분으로 Date 생성
    init?(year: Int, month: Int, day: Int, hour: Int, minute: Int) {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        
        guard let date = Calendar.current.date(from: components) else {
            return nil
        }
        
        self = date
    }
    
    /// 오늘 0시 0분 0초
    static var startOfToday: Date {
        return Calendar.current.startOfDay(for: Date())
    }
    
    /// 오늘 23시 59분 59초
    static var endOfToday: Date {
        let startOfTomorrow = Calendar.current.date(byAdding: .day, value: 1, to: startOfToday)!
        return Calendar.current.date(byAdding: .second, value: -1, to: startOfTomorrow)!
    }
    
    /// 이번 주 시작 (월요일)
    static var startOfWeek: Date {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7 // 월요일을 기준으로 계산
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: calendar.startOfDay(for: today))!
    }
    
    /// 이번 달 시작 (1일)
    static var startOfMonth: Date {
        let calendar = Calendar.current
        let today = Date()
        return calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
    }
    
    /// 올해 시작 (1월 1일)
    static var startOfYear: Date {
        let calendar = Calendar.current
        let today = Date()
        return calendar.date(from: calendar.dateComponents([.year], from: today))!
    }
}
