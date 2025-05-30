import Foundation

enum NetworkError: Error, Equatable {
    case noInternetConnection
    case unauthorized
    case forbidden
    case notFound
    case serverError
    case serverUnavailable
    case serviceUnavailable
    case invalidResponse
    case parsingFailed
    case timeout
    case unknown
    case tokenExpired
    case invalidCredentials
    case invalidData
    case custom(String)
    
    var localizedDescription: String {
        switch self {
        case .noInternetConnection:
            return "인터넷 연결을 확인해주세요"
        case .unauthorized:
            return "인증이 필요합니다"
        case .forbidden:
            return "접근 권한이 없습니다"
        case .notFound:
            return "요청한 정보를 찾을 수 없습니다"
        case .serverError:
            return "서버 오류가 발생했습니다"
        case .serverUnavailable:
            return "서버를 사용할 수 없습니다"
        case .serviceUnavailable:
            return "서비스를 사용할 수 없습니다"
        case .invalidResponse:
            return "잘못된 응답입니다"
        case .parsingFailed:
            return "데이터 처리 중 오류가 발생했습니다"
        case .timeout:
            return "요청 시간이 초과되었습니다"
        case .unknown:
            return "알 수 없는 오류가 발생했습니다"
        case .tokenExpired:
            return "세션이 만료되었습니다. 다시 로그인 해주세요."
        case .invalidCredentials:
            return "아이디 또는 비밀번호가 올바르지 않습니다."
        case .invalidData:
            return "잘못된 데이터를 수신했습니다."
        case .custom(let message):
            return message
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .noInternetConnection, .serverError, .serverUnavailable, .serviceUnavailable, .timeout:
            return true
        default:
            return false
        }
    }
    
    static func from(httpStatusCode: Int) -> NetworkError {
        switch httpStatusCode {
        case 401:
            return .unauthorized
        case 403:
            return .forbidden
        case 404:
            return .notFound
        case 500..<600:
            return .serverError
        case 503:
            return .serviceUnavailable
        default:
            return .unknown
        }
    }
    
    static func from(alamofireError: Error) -> NetworkError {
        if let urlError = alamofireError as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .noInternetConnection
            case .timedOut:
                return .timeout
            default:
                return .unknown
            }
        }
        return .unknown
    }
}
