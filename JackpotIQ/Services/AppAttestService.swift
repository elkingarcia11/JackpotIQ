import Foundation
import DeviceCheck
import OSLog

/// Service responsible for handling App Attest flow for secure app authentication
actor AppAttestService {
    private let networkService: NetworkService
    private var keyID: String?
    private var attestationService: DCAppAttestService?
    private var savedChallenge: Data?
    private let baseURL: URL
    private let logger = Logger(subsystem: "com.jackpotiq.app", category: "AppAttestService")
    
    init(networkService: NetworkService) {
        self.networkService = networkService
        self.baseURL = URL(string: networkService.configuration.baseURL)!
        
        // Call actor-isolated method properly using a Task
        Task { await setupAttestationService() }
    }
    
    private func setupAttestationService() {
        let service = DCAppAttestService.shared
        if service.isSupported {
            attestationService = service
        } else {
            logger.warning("App Attest is not supported on this device")
        }
    }
    
    /// Performs the complete App Attest flow
    /// - Returns: JWT token if successful
    func performAppAttestation() async throws -> String {
        // Step 1: Request a challenge from the server
        let challenge = try await requestChallenge()
        
        // Step 2: Generate a new key
        let keyID = try await generateKey()
        
        // Step 3: Generate attestation
        let attestation = try await generateAttestation(keyID: keyID, challenge: challenge)
        
        // Step 4: Send attestation to server for verification
        return try await verifyAttestation(keyID: keyID, challenge: challenge, attestation: attestation)
    }
    
    private func requestChallenge() async throws -> Data {
        struct ChallengeResponse: Decodable {
            let challenge: String
        }
        
        // Minimal logging without sensitive details
        logger.debug("APP-ATTEST: Requesting challenge")
        
        let response: ChallengeResponse = try await networkService.performRequest(
            endpoint: "auth/app-attest-challenge",
            method: .get
        )
        
        logger.debug("APP-ATTEST: Challenge received")
        
        // Convert base64 challenge to Data
        guard let challengeData = Data(base64Encoded: response.challenge) else {
            logger.error("APP-ATTEST: Failed to decode challenge data")
            throw AppAttestError.invalidChallengeData
        }
        
        // Don't log challenge length or any details about it
        logger.debug("APP-ATTEST: Challenge decoded successfully")
        
        // Save the challenge for later use
        self.savedChallenge = challengeData
        return challengeData
    }
    
    private func generateKey() async throws -> String {
        guard let attestationService = self.attestationService else {
            throw AppAttestError.notAvailable
        }
        
        do {
            let keyID = try await attestationService.generateKey()
            self.keyID = keyID
            return keyID
        } catch {
            // Don't log the actual error details
            logger.error("APP-ATTEST: Key generation failed")
            throw AppAttestError.keyGenerationFailed(error: error)
        }
    }
    
    private func generateAttestation(keyID: String, challenge: Data) async throws -> Data {
        guard let attestationService = self.attestationService else {
            throw AppAttestError.notAvailable
        }
        
        // Remove keyID and challenge data from logs
        logger.debug("APP-ATTEST: Generating attestation")
        
        do {
            let attestation = try await attestationService.attestKey(keyID, clientDataHash: challenge)
            // Don't log attestation details
            logger.debug("APP-ATTEST: Attestation generated successfully")
            
            // Remove diagnostic parsing which logs sensitive data
            // printAttestationDetails(attestation)
            
            return attestation
        } catch {
            // Generic error without details
            logger.error("APP-ATTEST: Attestation generation failed")
            throw AppAttestError.attestationFailed(error: error)
        }
    }
    
    /// Prints detailed diagnostic information about the attestation structure
    private func printAttestationDetails(_ attestation: Data) {
        // This method has been intentionally disabled to prevent logging sensitive data
    }
    
    private func verifyAttestation(keyID: String, challenge: Data, attestation: Data) async throws -> String {
        struct VerifyRequest: Encodable {
            let keyID: String
            let challenge: String
            let attestation: String
        }
        
        struct VerifyResponse: Decodable {
            let token: String
        }
        
        logger.debug("APP-ATTEST: Starting attestation verification")
        
        let requestBody = VerifyRequest(
            keyID: keyID,
            challenge: challenge.base64EncodedString(),
            attestation: attestation.base64EncodedString()
        )
        
        do {
            let response: VerifyResponse = try await networkService.performRequest(
                endpoint: "auth/verify-attestation",
                method: .post,
                body: requestBody
            )
            
            logger.debug("APP-ATTEST: Verification successful")
            return response.token
        } catch {
            // Don't log specific error details
            logger.error("APP-ATTEST: Verification failed")
            throw error
        }
    }
}

// MARK: - Helper Extensions
extension Data {
    /// Human-readable hex string representation of the data
    var hexDescription: String {
        return self.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}

// MARK: - Custom Error Types
enum AppAttestError: Error, LocalizedError {
    case notAvailable
    case invalidChallengeData
    case keyGenerationFailed(error: Error)
    case attestationFailed(error: Error)
    case verificationFailed
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "App Attest is not available on this device"
        case .invalidChallengeData:
            return "Invalid challenge data received from server"
        case .keyGenerationFailed(let error):
            return "Failed to generate App Attest key: \(error.localizedDescription)"
        case .attestationFailed(let error):
            return "Failed to generate attestation: \(error.localizedDescription)"
        case .verificationFailed:
            return "Server failed to verify attestation"
        }
    }
}
