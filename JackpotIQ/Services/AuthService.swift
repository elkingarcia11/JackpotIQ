import Foundation
import Security
import Combine
import OSLog

/// Service responsible for handling authentication
class AuthService: ObservableObject {
    private let networkService: NetworkService
    private let appAttestService: AppAttestService
    private let serviceName = "com.jackpotiq.app"
    private let tokenKey = "auth_token"
    private let logger = Logger(subsystem: "com.jackpotiq.app", category: "AuthService")
    
    @Published var isAuthenticating = false
    @Published private(set) var authenticationError: Error?
    @Published private(set) var isAuthenticated = false
    
    init(networkService: NetworkService) {
        self.networkService = networkService
        self.appAttestService = AppAttestService(networkService: networkService)
        self.isAuthenticated = getFromKeychain() != nil
    }
    
    /// Authenticates the app using App Attest
    func authenticate() async throws {
        do {
            await setAuthenticatingState(true)
            
            // Perform attestation and get JWT token
            let token = try await appAttestService.performAppAttestation()
            
            // Save token to keychain
            try saveToKeychain(token)
            
            // Set token in network service for authorized requests
            networkService.setAuthToken(token)
            
            await updateAuthState(true, error: nil)
        } catch {
            logger.error("Authentication failed: \(error.localizedDescription)")
            await updateAuthState(false, error: error)
            throw error
        }
    }
    
    /// Retrieves the stored authentication token
    func getAuthToken() -> String? {
        return getFromKeychain()
    }
    
    /// Logs out the user by removing the stored token
    func logout() {
        deleteFromKeychain()
        networkService.clearAuthToken()
        
        Task { @MainActor in
            isAuthenticated = false
            objectWillChange.send()
        }
    }
    
    // MARK: - Private Methods
    
    @MainActor
    private func setAuthenticatingState(_ authenticating: Bool) {
        isAuthenticating = authenticating
        authenticationError = nil
    }
    
    @MainActor
    private func updateAuthState(_ authenticated: Bool, error: Error?) {
        isAuthenticating = false
        isAuthenticated = authenticated
        authenticationError = error
    }
    
    // MARK: - Keychain Operations
    
    private func saveToKeychain(_ token: String) throws {
        deleteFromKeychain() // Remove any existing item
        
        guard let tokenData = token.data(using: .utf8) else {
            throw AuthError.tokenConversionFailed
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey,
            kSecAttrService as String: serviceName,
            kSecValueData as String: tokenData
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AuthError.keychainSaveFailed(status: status)
        }
    }
    
    private func getFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey,
            kSecAttrService as String: serviceName,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess, 
              let data = item as? Data, 
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return token
    }
    
    private func deleteFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey,
            kSecAttrService as String: serviceName
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Custom Error Types
enum AuthError: Error, LocalizedError {
    case tokenConversionFailed
    case keychainSaveFailed(status: OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .tokenConversionFailed:
            return "Failed to convert token to data"
        case .keychainSaveFailed(let status):
            return "Failed to save token to keychain (status: \(status))"
        }
    }
} 
