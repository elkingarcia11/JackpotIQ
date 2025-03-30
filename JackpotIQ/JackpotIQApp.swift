import SwiftUI

@main
struct JackpotIQApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // App Logo
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .padding(.top, 40)
                
                // Lottery Options
                VStack(spacing: 24) {
                    NavigationLink {
                        LotteryView(type: .megaMillions)
                    } label: {
                        LotteryButton(
                            image: "MegaMillions",
                            color: Color(hex: "#21AB4B"),  // Mega Millions green
                            accessibilityLabel: "Play Mega Millions"
                        )
                    }
                    
                    NavigationLink {
                        LotteryView(type: .powerball)
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
        }
    }
}

struct LotteryButton: View {
    let image: String
    let color: Color
    let accessibilityLabel: String
    @State private var isPressed = false
    
    var body: some View {
        HStack {
            Image(image)
                .resizable()
                .scaledToFit()
                .frame(height: 44)
                .foregroundColor(color)
                .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                color.opacity(0.15),
                                color.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        color.opacity(0.3),
                        lineWidth: 1
                    )
            }
        )
        .cornerRadius(12)
        .shadow(
            color: color.opacity(0.3),
            radius: isPressed ? 2 : 5,
            x: 0,
            y: isPressed ? 1 : 2
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .accessibilityLabel(accessibilityLabel)
        .pressEvents {
            isPressed = true
        } onRelease: {
            isPressed = false
        }
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
