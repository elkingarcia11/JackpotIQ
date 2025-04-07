import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse(Int)
    case decodingError(String)
    case serverError(String)
    case noData
    case authenticationError(String)
    
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
        case .authenticationError(let message):
            return "Authentication error: \(message)"
        }
    }
}

struct NetworkConfiguration {
    let baseURL: String
    let debug: Bool
    
    static let development = NetworkConfiguration(
        baseURL: "http://localhost:3000/api",
        debug: true
    )
    
    static let production = NetworkConfiguration(
        baseURL: "https://api.jackpotiq.com/api", // Replace with production URL
        debug: false
    )
}

// MARK: - Authentication Models
struct AppAttestRequest: Codable {
    let attestation: String
    let challenge: String
}

struct AppAttestResponse: Codable {
    let verified: Bool
    let deviceId: String
}

struct TokenRequest: Codable {
    let deviceId: String
}

struct TokenResponse: Codable {
    let token: String
}

// Add enum for optimization method
enum OptimizationMethod {
    case byPosition
    case byGeneralFrequency
}

protocol NetworkServiceProtocol {
    // Authentication
    func verifyAppAttest(attestation: String, challenge: String) async throws -> AppAttestResponse
    func generateToken(deviceId: String) async throws -> TokenResponse
    
    // Statistics
    func fetchLotteryStatistics(for type: LotteryType) async throws -> LotteryStatistics
    
    // Lottery
    func fetchNumberFrequencies(for type: LotteryType, category: String) async throws -> [NumberFrequency]
    func fetchPositionFrequencies(for type: LotteryType, position: Int?) async throws -> [PositionFrequency]
    func generateOptimizedCombination(for type: LotteryType, method: OptimizationMethod) async throws -> OptimizedCombination
    func generateRandomCombination(for type: LotteryType) async throws -> RandomCombination
    func fetchLatestCombinations(for type: LotteryType, page: Int, pageSize: Int) async throws -> LatestCombinationsResponse
    func searchLotteryDraws(type: LotteryType, numbers: [Int], specialBall: Int?) async throws -> [LatestCombination]
}

class NetworkService: NetworkServiceProtocol {
    static let shared = NetworkService()
    private let configuration: NetworkConfiguration
    private var authToken: String?
    
    // For testing purposes - set to false to bypass authentication
    private let requireAuthentication = false
    
    init(configuration: NetworkConfiguration = .development) {
        self.configuration = configuration
        // Load token from secure storage if available
        self.authToken = UserDefaults.standard.string(forKey: "authToken")
    }
    
    private func performRequest<T: Decodable>(endpoint: String, method: String = "GET", body: [String: Any]? = nil, requiresAuth: Bool = true) async throws -> T {
        guard let url = URL(string: "\(configuration.baseURL)/\(endpoint)") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        // Add authorization header if required (but skip during testing)
        if requiresAuth && requireAuthentication, let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if configuration.debug {
            print("📡 API Request: \(method) \(url)")
            if let body = body {
                print("📦 Body: \(body)")
            }
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse(-1)
        }
        
        if configuration.debug {
            print("📡 API Response: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("📦 Data: \(responseString)")
            }
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw NetworkError.authenticationError("Authentication required")
            }
             
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message ?? "Unknown error")
            }
            throw NetworkError.invalidResponse(httpResponse.statusCode)
        }
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingError(error.localizedDescription)
        }
    }
    
    // MARK: - Authentication Methods
    
    func verifyAppAttest(attestation: String, challenge: String) async throws -> AppAttestResponse {
        return try await performRequest(
            endpoint: "auth/verify-app-attest",
            method: "POST",
            body: ["attestation": attestation, "challenge": challenge],
            requiresAuth: false
        )
    }
    
    func generateToken(deviceId: String) async throws -> TokenResponse {
        let response: TokenResponse = try await performRequest(
            endpoint: "auth/token",
            method: "POST",
            body: ["deviceId": deviceId],
            requiresAuth: false
        )
        
        // Save token for future requests
        self.authToken = response.token
        UserDefaults.standard.set(response.token, forKey: "authToken")
        
        return response
    }
    
    // MARK: - Statistics Methods
    
    func fetchLotteryStatistics(for type: LotteryType) async throws -> LotteryStatistics {
        return try await performRequest(endpoint: "stats?type=\(type.apiEndpoint)")
    }
    
    // MARK: - Lottery Methods
    
    func fetchNumberFrequencies(for type: LotteryType, category: String) async throws -> [NumberFrequency] {
        // Using statistics endpoint instead of direct number-frequencies
        let stats = try await fetchLotteryStatistics(for: type)
        
        if category == "main" {
            return stats.frequency.compactMap { numStr, count in 
                guard let number = Int(numStr) else { return nil }
                // Calculate percentage by dividing count by totalDraws
                let percentage = Double(count) / Double(stats.totalDraws) * 100
                return NumberFrequency(number: number, count: count, percentage: percentage)
            }
        } else {
            // For special balls, calculate percentage based on total special ball count
            let totalSpecialBallCount = stats.specialBallFrequency.values.reduce(0, +)
            
            return stats.specialBallFrequency.compactMap { numStr, count in
                guard let number = Int(numStr) else { return nil }
                // Calculate percentage by dividing count by total special ball count
                let percentage = Double(count) / Double(totalSpecialBallCount) * 100
                return NumberFrequency(number: number, count: count, percentage: percentage)
            }
        }
    }
    
    func fetchPositionFrequencies(for type: LotteryType, position: Int? = nil) async throws -> [PositionFrequency] {
        let stats = try await fetchLotteryStatistics(for: type)
        var results: [PositionFrequency] = []
        
        // Process each position separately to calculate correct percentages
        if let position = position, let positionData = stats.frequencyAtPosition[String(position)] {
            // Calculate the sum of all counts for this position
            let totalCountForPosition = positionData.values.reduce(0, +)
            
            for (numStr, count) in positionData {
                guard let number = Int(numStr) else { continue }
                // Calculate percentage based on sum of counts for this position
                let percentage = Double(count) / Double(totalCountForPosition) * 100
                results.append(PositionFrequency(position: position, number: number, count: count, percentage: percentage))
            }
        } else {
            // Process all positions
            for (posStr, positionData) in stats.frequencyAtPosition {
                guard let pos = Int(posStr) else { continue }
                // Calculate the sum of all counts for this position
                let totalCountForPosition = positionData.values.reduce(0, +)
                
                for (numStr, count) in positionData {
                    guard let number = Int(numStr) else { continue }
                    // Calculate percentage based on sum of counts for this position
                    let percentage = Double(count) / Double(totalCountForPosition) * 100
                    results.append(PositionFrequency(position: pos, number: number, count: count, percentage: percentage))
                }
            }
        }
        
        return results
    }
    
    func generateOptimizedCombination(for type: LotteryType, method: OptimizationMethod = .byPosition) async throws -> OptimizedCombination {
        // Get statistics from the API
        let stats = try await fetchLotteryStatistics(for: type)
        
        // Select the appropriate optimization method
        let optimizedNumbers: [Int]
        
        switch method {
        case .byPosition:
            optimizedNumbers = stats.optimizedByPosition
        case .byGeneralFrequency:
            optimizedNumbers = stats.optimizedByGeneralFrequency
        }
        
        // Extract main numbers and special ball
        let mainNumbers = Array(optimizedNumbers.prefix(5))
        let specialBall = optimizedNumbers.last!
        
        if configuration.debug {
            print("DEBUG: Generated optimized combination using \(method) method: \(mainNumbers), \(specialBall)")
        }
        
        return OptimizedCombination(
            mainNumbers: mainNumbers,
            specialBall: specialBall,
            positionPercentages: nil,
            isUnique: true
        )
    }
    
    func generateRandomCombination(for type: LotteryType) async throws -> RandomCombination {
        // Using the specified API endpoint format: lottery/generate-random?type=powerball
        let endpoint = "lottery/generate-random?type=\(type.rawValue)"
        
        // The response has a structure like:
        // { "type": "powerball", "numbers": [18, 28, 43, 45, 68], "specialBall": 14 }
        struct RandomNumberResponse: Codable {
            let type: String
            let numbers: [Int]
            let specialBall: Int
        }
        
        let result: RandomNumberResponse = try await performRequest(endpoint: endpoint)
        
        if configuration.debug {
            print("DEBUG: Generated random combination: \(result.numbers), \(result.specialBall)")
        }
        
        return RandomCombination(
            mainNumbers: result.numbers,
            specialBall: result.specialBall,
            isUnique: true // Assuming the generated combination is unique
        )
    }
    
    func fetchLatestCombinations(for type: LotteryType, page: Int = 1, pageSize: Int = 20) async throws -> LatestCombinationsResponse {
        // The API returns an array of LatestCombination directly instead of a wrapped response
        let latestDraws: [LatestCombination] = try await performRequest(
            endpoint: "lottery?type=\(type.rawValue)&limit=\(pageSize)&offset=\((page-1)*pageSize)"
        )
        
        if configuration.debug {
            print("📊 Received \(latestDraws.count) latest combinations")
        }
        
        // Create a LatestCombinationsResponse from the array
        return LatestCombinationsResponse(
            combinations: latestDraws,
            totalCount: latestDraws.count,
            hasMore: latestDraws.count == pageSize
        )
    }
    
    func searchLotteryDraws(type: LotteryType, numbers: [Int], specialBall: Int?) async throws -> [LatestCombination] {
        // Create request body matching expected format:
        // {
        //   "type": "mega-millions",  // Required: "mega-millions" or "powerball"
        //   "numbers": [1, 2, 3],     // Optional: array of numbers to search for
        //   "specialBall": 10         // Optional: special ball number
        // }
        var body: [String: Any] = [
            "type": type.rawValue
        ]
        
        // Only include numbers if there are some to search for
        if !numbers.isEmpty {
            body["numbers"] = numbers
        }
        
        // Only include specialBall if provided
        if let specialBall = specialBall {
            body["specialBall"] = specialBall
        }
        
        if configuration.debug {
            print("🔍 Searching for lottery draws with params: \(body)")
        }
        
        // Response will be an array of LatestCombination objects
        let results: [LatestCombination] = try await performRequest(
            endpoint: "lottery/search",
            method: "POST",
            body: body
        )
        
        if configuration.debug {
            print("🔍 Found \(results.count) matching lottery draws")
        }
        
        return results
    }
}
