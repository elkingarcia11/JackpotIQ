import SwiftUI

/// A reusable component that displays a lottery number in a circular ball
/// - Note: Used across the app for consistent number display
struct NumberBall: View {
    let number: Int
    var size: CGFloat = 44
    var color: Color = .blue
    var background: LinearGradient?
    var isSpecialBall: Bool = false
    
    init(
        number: Int,
        size: CGFloat = 44,
        color: Color = .blue,
        background: LinearGradient? = nil,
        isSpecialBall: Bool = false
    ) {
        self.number = number
        self.size = size
        self.color = color
        self.background = background
        self.isSpecialBall = isSpecialBall
    }
    
    var body: some View {
        ZStack {
            if let gradient = background {
                Circle()
                    .fill(gradient)
                    .frame(width: size, height: size)
                    .shadow(color: (isSpecialBall ? Color.orange : Color.blue).opacity(0.3), radius: 3, x: 0, y: 2)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)
                    .shadow(color: color.opacity(0.3), radius: 3, x: 0, y: 2)
            }
            
            Text("\(number)")
                .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                .foregroundColor(foregroundColor)
        }
    }
    
    private var foregroundColor: Color {
        if let gradient = background {
            // Instead of checking stops (which doesn't exist), check if this is a Mega Ball
            // Mega Balls use yellow/orange gradient and need black text for contrast
            if isSpecialBall {
                // Check if this is likely a Mega Ball (yellow gradient) vs Powerball (red gradient)
                let gradientDescription = String(describing: gradient)
                if gradientDescription.contains("yellow") {
                    return .black
                }
            }
        }
        return .white
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 10) {
            // Regular number balls
            NumberBall(number: 12)
            NumberBall(number: 37)
            NumberBall(number: 48)
        }
        
        HStack(spacing: 10) {
            // Mega Ball
            NumberBall(
                number: 25,
                color: .clear,
                background: LinearGradient(
                    colors: [.yellow, .orange],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                isSpecialBall: true
            )
            
            // Powerball
            NumberBall(
                number: 18,
                color: .clear,
                background: LinearGradient(
                    colors: [.red, .pink],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                isSpecialBall: true
            )
        }
        
        // Different sizes
        HStack(spacing: 10) {
            NumberBall(number: 7, size: 32)
            NumberBall(number: 7, size: 44)
            NumberBall(number: 7, size: 56)
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
