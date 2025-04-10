import Foundation
import Combine
import OSLog

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case decodingFailed(Error)
    case serverError(status: Int, message: String?)
    case unauthorizedError
    
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
    let debug: Bool
    
    static let development = NetworkConfiguration(
        baseURL: "https://jackpot-iq-api-669259029283.us-central1.run.app/api/",
        debug: true
    )
    
    // Alternative configuration for simulators that can't connect to host.docker.internal
    static let developmentFallback = NetworkConfiguration(
        baseURL: "https://jackpot-iq-api-669259029283.us-central1.run.app/api/",
        debug: true
    )
    
    static let production = NetworkConfiguration(
        baseURL: "https://api.jackpotiq.com/api/", // Replace with production URL
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

@Observable
class NetworkService: NetworkServiceProtocol {
    static let shared = NetworkService()
    private let baseURL: URL
    private var authToken: String?
    let configuration: NetworkConfiguration
    private let logger = Logger(subsystem: "com.jackpotiq.app", category: "NetworkService")
    private let session: URLSession
    
    // For testing purposes - set to false to bypass authentication
    private let requireAuthentication = false
    
    init(configuration: NetworkConfiguration = .developmentFallback) {
        self.configuration = configuration
        
        guard let url = URL(string: configuration.baseURL) else {
            fatalError("Invalid base URL: \(configuration.baseURL)")
        }
        self.baseURL = url
        
        // Print the base URL for debugging
        print("DEBUG: Base URL initialized as: \(self.baseURL.absoluteString)")
        
        // Create a custom session configuration that allows insecure loads for development
        let sessionConfig = URLSessionConfiguration.default
        if configuration.debug {
            // This is for development only - allows connection to localhost, etc.
            sessionConfig.timeoutIntervalForRequest = 60 // Increase timeout to 60 seconds
            sessionConfig.timeoutIntervalForResource = 60 // Increase timeout to 60 seconds
            // Disable ATS for development only
            sessionConfig.waitsForConnectivity = true
            // Allow insecure HTTP loads for development
            sessionConfig.allowsExpensiveNetworkAccess = true
            sessionConfig.allowsConstrainedNetworkAccess = true
            
            #if DEBUG
            // This is needed because we're setting ATS exceptions in Info.plist instead
            // but the environment might not pick it up correctly
            if let dict = Bundle.main.object(forInfoDictionaryKey: "NSAppTransportSecurity") as? [String: Any] {
                sessionConfig.connectionProxyDictionary = ["NSAppTransportSecurity": dict]
            }
            #endif
            
            logger.debug("Using development session configuration with ATS exceptions")
        }
        self.session = URLSession(configuration: sessionConfig)
        
        // Load token from secure storage if available
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            self.authToken = token
            logger.debug("Loaded auth token from UserDefaults")
        }
    }
    
    // Set authentication token for authorized requests
    func setAuthToken(_ token: String) {
        self.authToken = token
        UserDefaults.standard.set(token, forKey: "authToken")
        logger.debug("Auth token set and saved to UserDefaults")
    }
    
    // Clear authentication token
    func clearAuthToken() {
        self.authToken = nil
        UserDefaults.standard.removeObject(forKey: "authToken")
        logger.debug("Auth token cleared from memory and UserDefaults")
    }
    
    func performRequest<T: Decodable>(endpoint: String, method: HTTPMethod = .get, body: Encodable? = nil) async throws -> T {
        // Create URL and request
        guard let url = URL(string: endpoint, relativeTo: self.baseURL) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token if available
        if let token = authToken {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add body if provided
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        // Enhanced request logging
        let isAppAttestChallengeEndpoint = endpoint == "auth/app-attest-challenge"
        if configuration.debug || isAppAttestChallengeEndpoint {
            // Only log that a request was made, no details
            logger.debug("Making API request")
        }
        
        do {
            if configuration.debug {
                logger.debug("Attempting connection")
            }
            
            // Use our custom session instead of the shared one
            let (data, response) = try await session.data(for: request)
            
            // Enhanced response logging
            if configuration.debug || isAppAttestChallengeEndpoint {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                // Only log status code, not response body
                logger.debug("Response received: \(statusCode)")
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid response type")
                throw NetworkError.invalidResponse
            }
            
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
                // Don't log raw error messages which might contain sensitive info
                logger.error("Server error (\(httpResponse.statusCode))")
                throw NetworkError.serverError(status: httpResponse.statusCode, message: nil)
            }
        } catch let error as NetworkError {
            throw error
        } catch {
            logger.error("Network request failed")
            throw NetworkError.requestFailed(error)
        }
    }
    
    // MARK: - Authentication Methods
    
    func verifyAppAttest(attestation: String, challenge: String) async throws -> AppAttestResponse {
        return try await performRequest(
            endpoint: "auth/verify-app-attest",
            method: .post,
            body: AppAttestRequest(attestation: attestation, challenge: challenge)
        )
    }
    
    func generateToken(deviceId: String) async throws -> TokenResponse {
        let response: TokenResponse = try await performRequest(
            endpoint: "auth/token",
            method: .post,
            body: TokenRequest(deviceId: deviceId)
        )
        
        // Don't log token
        logger.debug("Auth token received")
        
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
            // Remove specific combination info
            logger.debug("Generated optimized combination")
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
            // Remove specific combination info
            logger.debug("Generated random combination")
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
            // Log only count, not actual combinations
            logger.debug("Received \(latestDraws.count) latest combinations")
        }
        
        // Create a LatestCombinationsResponse from the array
        return LatestCombinationsResponse(
            combinations: latestDraws,
            totalCount: latestDraws.count,
            hasMore: latestDraws.count == pageSize
        )
    }
    
    func searchLotteryDraws(type: LotteryType, numbers: [Int], specialBall: Int?) async throws -> [LatestCombination] {
        // Create a proper Encodable struct instead of a dictionary
        let searchRequest = LotterySearchRequest(
            type: type.rawValue,
            numbers: numbers.isEmpty ? nil : numbers,
            specialBall: specialBall
        )
        
        if configuration.debug {
            // Log without specifics
            logger.debug("Searching for lottery draws")
        }
        
        // Response will be an array of LatestCombination objects
        let results: [LatestCombination] = try await performRequest(
            endpoint: "lottery/search",
            method: .post,
            body: searchRequest
        )
        
        if configuration.debug {
            // Log only count, not actual results
            logger.debug("Found \(results.count) matching lottery draws")
        }
        
        return results
    }
}
