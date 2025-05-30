import Foundation
import Combine

extension Publisher {
    func singleOutput() async throws -> Output {
        for try await value in values {
            return value
        }
        throw URLError(.badServerResponse)
    }
}
