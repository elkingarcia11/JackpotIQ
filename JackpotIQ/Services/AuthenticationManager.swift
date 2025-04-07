import Foundation
import DeviceCheck

class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    
    @Published var isAuthenticated = false
    @Published var isAuthenticating = false
    @Published var authError: Error?
    
    private var deviceId: String?
    
    // Check if we can use App Attest on this device
    var canUseAppAttest: Bool {
        if #available(iOS 14.0, *) {
            return DCAppAttestService.shared.isSupported
        }
        return false
    }
    
    private init() {
        // Check if we have a stored deviceId
        if let storedDeviceId = UserDefaults.standard.string(forKey: "deviceId") {
            self.deviceId = storedDeviceId
            self.isAuthenticated = UserDefaults.standard.string(forKey: "authToken") != nil
        }
    }
    
    @MainActor
    func authenticate() async {
        guard !isAuthenticated else { return }
        
        isAuthenticating = true
        defer { isAuthenticating = false }
        
        do {
            // If we already have a deviceId, just get a new token
            if let deviceId = deviceId {
                try await refreshToken(with: deviceId)
                return
            }
            
            // Otherwise do the full attestation flow
            if canUseAppAttest {
                try await performAppAttestation()
            } else {
                // Fallback for devices that don't support App Attest
                try await generateDeviceId()
            }
            
            isAuthenticated = true
        } catch {
            authError = error
            isAuthenticated = false
        }
    }
    
    private func performAppAttestation() async throws {
        guard #available(iOS 14.0, *) else {
            throw AuthError.unsupportedDevice
        }
        
        // Generate a random challenge
        let challenge = UUID().uuidString
        
        // Generate a new key
        let keyId = try await DCAppAttestService.shared.generateKey()
        
        // Get the attestation
        let attestationData = try await DCAppAttestService.shared.attestKey(keyId, clientDataHash: challenge.data(using: .utf8)!)
        
        // Send to server for verification
        let attestationBase64 = attestationData.base64EncodedString()
        let response = try await NetworkService.shared.verifyAppAttest(
            attestation: attestationBase64,
            challenge: challenge
        )
        
        // Save the deviceId
        self.deviceId = response.deviceId
        UserDefaults.standard.set(response.deviceId, forKey: "deviceId")
        
        // Get the JWT token
        try await refreshToken(with: response.deviceId)
    }
    
    private func generateDeviceId() async throws {
        // For devices without App Attest, generate a unique identifier
        let newDeviceId = UUID().uuidString
        self.deviceId = newDeviceId
        UserDefaults.standard.set(newDeviceId, forKey: "deviceId")
        
        // Get the JWT token
        try await refreshToken(with: newDeviceId)
    }
    
    private func refreshToken(with deviceId: String) async throws {
        let response = try await NetworkService.shared.generateToken(deviceId: deviceId)
        UserDefaults.standard.set(response.token, forKey: "authToken")
        isAuthenticated = true
    }
    
    func signOut() {
        UserDefaults.standard.removeObject(forKey: "authToken")
        isAuthenticated = false
    }
}

enum AuthError: LocalizedError {
    case unsupportedDevice
    case attestationFailed
    
    var errorDescription: String? {
        switch self {
        case .unsupportedDevice:
            return "This device does not support App Attest."
        case .attestationFailed:
            return "Device attestation failed."
        }
    }
} 
