import Foundation
import Combine
import OSLog
import Security

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case decodingFailed(Error)
    case serverError(status: Int, message: String?)
    case unauthorizedError
    case invalidRequest(message: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The URL is invalid"
        case .requestFailed(let error):
            return "Request failed: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let status, let message):
            return "Server error (\(status)): \(message ?? "No details provided")"
        case .unauthorizedError:
            return "Unauthorized access"
        case .invalidRequest(let message):
            return message
        }
    }
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

struct NetworkConfiguration {
    let baseURL: String
    
    static let production = NetworkConfiguration(
        baseURL: "https://jackpot-iq-api-669259029283.us-central1.run.app/api/"
    )
    
    static let current = production
}

// MARK: - Authentication Models
struct AppAttestRequest: Codable {
    let attestation: String
    let challenge: String
    let keyID: String
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
enum OptimizationMethod: String, Codable {
    case byPosition = "position"
    case byGeneralFrequency = "frequency"
}

// Add this struct near the other request models at the top of the file
struct LotterySearchRequest: Codable {
    let type: String
    let numbers: [Int]?
    let specialBall: Int?
}

protocol NetworkServiceProtocol {
    // Authentication
    func verifyAppAttest(attestation: String, challenge: String, keyID: String) async throws -> AppAttestResponse
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

@Observable
class NetworkService: NetworkServiceProtocol {
    static let shared = NetworkService()
    private let baseURL: URL
    private var authToken: String?
    let configuration: NetworkConfiguration
    private let logger = Logger(subsystem: "com.jackpotiq.app", category: "NetworkService")
    private let session: URLSession
    private let tokenKey = "com.jackpotiq.app.authToken"
    
    init(configuration: NetworkConfiguration = .current) {
        self.configuration = configuration
        
        guard let url = URL(string: configuration.baseURL) else {
            fatalError("Invalid base URL: \(configuration.baseURL)")
        }
        self.baseURL = url
        
        // Create a standard session configuration
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 30
        sessionConfig.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: sessionConfig)
        
        // Load token from keychain if available
        self.authToken = loadTokenFromKeychain()
    }
    
    private func loadTokenFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return token
    }
    
    private func saveTokenToKeychain(_ token: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey,
            kSecValueData as String: token.data(using: .utf8)!
        ]
        
        // First try to delete any existing token
        SecItemDelete(query as CFDictionary)
        
        // Then add the new token
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            logger.error("Failed to save token to keychain: \(status)")
        }
    }
    
    private func deleteTokenFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            logger.error("Failed to delete token from keychain: \(status)")
        }
    }
    
    // Set authentication token for authorized requests
    func setAuthToken(_ token: String) {
        self.authToken = token
        saveTokenToKeychain(token)
    }
    
    // Clear authentication token
    func clearAuthToken() {
        self.authToken = nil
        deleteTokenFromKeychain()
    }
    
    func performRequest<T: Decodable>(endpoint: String, method: HTTPMethod = .get, body: Encodable? = nil) async throws -> T {
        // Create URL and request
        guard let url = URL(string: endpoint, relativeTo: self.baseURL) else {
            logger.error("Invalid URL: \(endpoint)")
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token if available
        if let token = authToken {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            logger.debug("Auth token present")
        } else {
            logger.debug("No auth token available")
        }
        
        // Add body if provided
        if let body = body {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(body)
            request.httpBody = jsonData
            
            // Log only non-sensitive information
            if endpoint == "auth/verify-app-attest" {
                logger.debug("Sending attestation request")
            } else if endpoint == "auth/token" {
                logger.debug("Sending token request")
            } else {
                logger.debug("Request body present")
            }
        }
        
        do {
            logger.debug("Making request to: \(endpoint)")
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid response type")
                throw NetworkError.invalidResponse
            }
            
            // Log only status code, not headers
            logger.debug("Response status: \(httpResponse.statusCode)")
            
            // Handle HTTP status codes
            switch httpResponse.statusCode {
            case 200...299: // Success
                do {
                    let decoder = JSONDecoder()
                    return try decoder.decode(T.self, from: data)
                } catch {
                    logger.error("Decoding failed")
                    throw NetworkError.decodingFailed(error)
                }
            case 401: // Unauthorized
                logger.error("Unauthorized access")
                throw NetworkError.unauthorizedError
            default:
                logger.error("Server error: \(httpResponse.statusCode)")
                throw NetworkError.serverError(status: httpResponse.statusCode, message: nil)
            }
        } catch {
            logger.error("Request failed")
            throw NetworkError.requestFailed(error)
        }
    }
    
    // MARK: - Authentication Methods
    
    func verifyAppAttest(attestation: String, challenge: String, keyID: String) async throws -> AppAttestResponse {
        logger.debug("Verifying app attestation")
        
        // Ensure the attestation is properly formatted
        let formattedAttestation = attestation.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Create the request body
        let requestBody = AppAttestRequest(
            attestation: formattedAttestation,
            challenge: challenge,
            keyID: keyID
        )
        
        // Make the request
        return try await performRequest(
            endpoint: "auth/verify-app-attest",
            method: .post,
            body: requestBody
        )
    }
    
    func generateToken(deviceId: String) async throws -> TokenResponse {
        let response: TokenResponse = try await performRequest(
            endpoint: "auth/token",
            method: .post,
            body: TokenRequest(deviceId: deviceId)
        )
        
        // Save token for future requests
        self.authToken = response.token
        saveTokenToKeychain(response.token)
        
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
        
        // Create a LatestCombinationsResponse from the array
        return LatestCombinationsResponse(
            combinations: latestDraws,
            totalCount: latestDraws.count,
            hasMore: latestDraws.count == pageSize
        )
    }
    
    // MARK: - Lottery Search Methods
    
    func searchLotteryDraws(type: LotteryType, numbers: [Int], specialBall: Int? = nil) async throws -> [LatestCombination] {
        // Log only non-sensitive information
        logger.debug("Searching lottery draws for type: \(type.rawValue)")
        
        // Format numbers as comma-separated string for the query parameter
        let numbersString = numbers.map { String($0) }.joined(separator: ",")
        
        // Build the URL with query parameters
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent("lottery/search"), resolvingAgainstBaseURL: true)!
        urlComponents.queryItems = [
            URLQueryItem(name: "type", value: type.rawValue),
            URLQueryItem(name: "numbers", value: numbersString)
        ]
        
        // Add special ball if provided
        if let specialBall = specialBall {
            urlComponents.queryItems?.append(URLQueryItem(name: "specialBall", value: String(specialBall)))
        }
        
        guard let url = urlComponents.url else {
            logger.error("Failed to construct search URL")
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"  // Using GET with query parameters
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            logger.debug("Auth token present for search request")
        } else {
            logger.warning("No auth token available for search request")
        }
        
        // Log only the endpoint path, not the full URL with parameters
        logger.debug("Making search request to lottery/search endpoint")
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Invalid response type for search request")
            throw NetworkError.invalidResponse
        }
        
        logger.debug("Search response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 401 {
            logger.error("Unauthorized search request")
            throw NetworkError.unauthorizedError
        }
        
        guard httpResponse.statusCode == 200 else {
            logger.error("Server error during search: \(httpResponse.statusCode)")
            throw NetworkError.serverError(status: httpResponse.statusCode, message: nil)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let results = try decoder.decode([LatestCombination].self, from: data)
        
        // Log only the count, not the actual results
        logger.debug("Search completed successfully with \(results.count) results")
        
        return results
    }
}
