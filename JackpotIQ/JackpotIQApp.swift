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
                            color: .green
                        )
                    }
                    
                    NavigationLink {
                        LotteryView(type: .powerball)
                    } label: {
                        LotteryButton(
                            image: "Powerball",
                            color: .red
                        )
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(hex: "ADD8E6"),  // Light blue
                        Color(hex: "90EE90")   // Light green
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
    }
}

struct LotteryButton: View {
    let image: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(image)
                .resizable()
                .scaledToFit()
                .frame(height: 44)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2, y: 1)
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
