import SwiftUI
import Combine
import OSLog

@main
struct JackpotIQApp: App {
    @State private var networkService = NetworkService(configuration: .developmentFallback)
    @StateObject private var authService = AuthService(networkService: NetworkService(configuration: .developmentFallback))
    @State private var isShowingSplash = true
    @State private var startFadeContent = false
    private let logger = Logger(subsystem: "com.jackpotiq.app", category: "AppDelegate")
    
    // App initialization logic
    init() {
        setupApp()
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(authService)
                    .task {
                        do {
                            try await authService.authenticate()
                            logger.debug("Authentication completed")
                        } catch {
                            logger.error("Authentication failed")
                            // Authentication failed but app can continue with limited functionality
                        }
                    }
                    .opacity(startFadeContent ? 1 : 0)
                
                if isShowingSplash {
                    SplashScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                        .onAppear {
                            // Start fading in the main content slightly before the splash disappears
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                withAnimation(.easeIn(duration: 1.0)) {
                                    startFadeContent = true
                                }
                            }
                            
                            // Remove the splash screen after animation completes
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                withAnimation(.easeOut(duration: 0.8)) {
                                    isShowingSplash = false
                                }
                            }
                        }
                }
            }
            .onAppear {
                // Preload app data during splash screen
                Task {
                    // Use this time to preload any essential data
                    // This runs in parallel with the splash screen animation
                    logger.debug("App launched")
                }
            }
        }
    }
    
    private func setupApp() {
        // Any additional setup logic that was previously in AppDelegate
    }
}

struct SplashScreenView: View {
    @State private var logoScale = 0.6
    @State private var logoOpacity = 0.0
    @State private var rotation = 0.0
    @State private var showText = false
    @State private var animateBalls = false
    @State private var ballOpacity = 0.0
    
    // Random positions for lottery balls
    let ballPositions = (0..<6).map { _ in 
        CGPoint(
            x: CGFloat.random(in: -160...160),
            y: CGFloat.random(in: -300...300)
        )
    }
    
    // Different colors for the balls
    let ballColors: [Color] = [
        .red, .blue, .green, .yellow, .purple, .orange
    ]
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.3),
                    Color(red: 0.2, green: 0.2, blue: 0.5)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Lottery balls floating animation
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(ballColors[index])
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text("\(Int.random(in: 1...50))")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .shadow(radius: 2)
                    .offset(
                        x: animateBalls ? ballPositions[index].x : 0,
                        y: animateBalls ? ballPositions[index].y : 0
                    )
                    .opacity(ballOpacity)
            }
            
            VStack(spacing: 20) {
                // App logo with animation
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(rotation))
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .shadow(color: .white.opacity(0.5), radius: 10)
                
                // App name with fade-in animation
                if showText {
                    Text("JackpotIQ")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .white.opacity(0.7), radius: 4)
                        .transition(.opacity)
                }
                
                if showText {
                    Text("Play Smarter")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.top, -10)
                        .transition(.opacity)
                }
            }
        }
        .onAppear {
            // First show the balls with a subtle fade in
            withAnimation(.easeIn(duration: 0.3)) {
                ballOpacity = 0.7
            }
            
            // Then animate them outward
            withAnimation(.spring(response: 2.0, dampingFraction: 0.65).delay(0.1)) {
                animateBalls = true
            }
            
            // Start logo animations sequence
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.3)) {
                logoScale = 1.0
                logoOpacity = 1.0
                rotation = 360
            }
            
            // Show text after initial animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeIn(duration: 0.5)) {
                    showText = true
                }
            }
        }
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
