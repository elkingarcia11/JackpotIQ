import SwiftUI
import Combine

@main
struct JackpotIQApp: App {
    @State private var networkService = NetworkService(configuration: .developmentFallback)
    @StateObject private var authService = AuthService(networkService: NetworkService(configuration: .developmentFallback))
    
    // App initialization logic
    init() {
        setupApp()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .task {
                    do {
                        try await authService.authenticate()
                    } catch {
                        // Authentication failed but app can continue with limited functionality
                    }
                }
        }
    }
    
    private func setupApp() {
        // Any additional setup logic that was previously in AppDelegate
    }
}

struct ContentView: View {
    @State private var selectedLottery: LotteryType?
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // App Logo
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .padding(.top, 40)
                
                // Lottery Options
                VStack(spacing: 24) {
                    Button {
                        selectedLottery = .megaMillions
                    } label: {
                        LotteryButton(
                            image: "MegaMillions",
                            color: Color(hex: "#21AB4B"),  // Mega Millions green
                            accessibilityLabel: "Play Mega Millions"
                        )
                    }
                    
                    Button {
                        selectedLottery = .powerball
                    } label: {
                        LotteryButton(
                            image: "Powerball",
                            color: Color(hex: "#D43333"),  // Powerball red
                            accessibilityLabel: "Play Powerball"
                        )
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationDestination(item: $selectedLottery) { type in
                LotteryView(type: type)
                    .navigationTitle(type == .megaMillions ? "Mega Millions" : "Powerball")
            }
        }
    }
}

struct LotteryButton: View {
    let image: String
    let color: Color
    let accessibilityLabel: String
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack {
            Image(image)
                .resizable()
                .scaledToFit()
                .frame(height: 40)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(.black) : .white)
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.1), color.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(color.opacity(0.2), lineWidth: 1)
            }
        )
        .shadow(color: color.opacity(0.2), radius: 8, x: 0, y: 4)
        .accessibilityLabel(accessibilityLabel)
    }
}

// Helper for button press gestures
extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onPress() }
                    .onEnded { _ in onRelease() }
            )
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    ContentView()
}
