import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse(Int)
    case decodingError(String)
    case serverError(String)
    case noData
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse(let statusCode):
            return "Invalid response from server (Status: \(statusCode))"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .noData:
            return "No data received from server"
        }
    }
}

struct NetworkConfiguration {
    let baseURL: String
    let debug: Bool
    
    static let development = NetworkConfiguration(
        baseURL: "http://192.168.1.244:8000",
        debug: true
    )
    
    static let production = NetworkConfiguration(
        baseURL: "http://192.168.1.244:8000", // Replace with production URL
        debug: false
    )
}

protocol NetworkServiceProtocol {
    func fetchNumberFrequencies(for type: LotteryType, category: String) async throws -> [NumberFrequency]
    func fetchPositionFrequencies(for type: LotteryType, position: Int?) async throws -> [PositionFrequency]
    func checkCombination(numbers: [Int], specialBall: Int?, type: LotteryType) async throws -> CombinationCheckResponse
    func generateOptimizedCombination(for type: LotteryType) async throws -> OptimizedCombination
    func generateRandomCombination(for type: LotteryType) async throws -> RandomCombination
    func fetchLatestCombinations(for type: LotteryType, page: Int, pageSize: Int) async throws -> LatestCombinationsResponse
}

class NetworkService: NetworkServiceProtocol {
    static let shared = NetworkService()
    private let configuration: NetworkConfiguration
    
    init(configuration: NetworkConfiguration = .development) {
        self.configuration = configuration
    }
    
    private func performRequest<T: Decodable>(endpoint: String, method: String = "GET", body: [String: Any]? = nil) async throws -> T {
        guard let url = URL(string: "\(configuration.baseURL)/\(endpoint)") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse(-1)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message ?? "Unknown error")
            }
            throw NetworkError.invalidResponse(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    func fetchNumberFrequencies(for type: LotteryType, category: String) async throws -> [NumberFrequency] {
        return try await performRequest(endpoint: "\(type.apiEndpoint)/number-frequencies?category=\(category)")
    }
    
    func fetchPositionFrequencies(for type: LotteryType, position: Int? = nil) async throws -> [PositionFrequency] {
        var endpoint = "\(type.apiEndpoint)/position-frequencies"
        if let position = position {
            endpoint += "?position=\(position)"
        }
        return try await performRequest(endpoint: endpoint)
    }
    
    func checkCombination(numbers: [Int], specialBall: Int?, type: LotteryType) async throws -> CombinationCheckResponse {
        var body: [String: Any] = ["numbers": numbers]
        if let specialBall = specialBall {
            body["special_ball"] = specialBall
        }
        return try await performRequest(
            endpoint: "\(type.apiEndpoint)/check-combination",
            method: "POST",
            body: body
        )
    }
    
    func generateOptimizedCombination(for type: LotteryType) async throws -> OptimizedCombination {
        return try await performRequest(endpoint: "\(type.apiEndpoint)/generate-optimized")
    }
    
    func generateRandomCombination(for type: LotteryType) async throws -> RandomCombination {
        return try await performRequest(endpoint: "\(type.apiEndpoint)/generate-random")
    }
    
    func fetchLatestCombinations(for type: LotteryType, page: Int = 1, pageSize: Int = 20) async throws -> LatestCombinationsResponse {
        return try await performRequest(endpoint: "\(type.apiEndpoint)/latest-combinations?page=\(page)&page_size=\(pageSize)")
    }
}
