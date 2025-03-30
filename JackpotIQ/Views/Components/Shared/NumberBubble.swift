import SwiftUI

/// A view that displays a lottery number in a circular bubble with a modern gradient design
/// - Note: Used across different lottery views to maintain consistent number display
struct NumberBubble: View {
    let number: Int
    var isSpecial: Bool = false
    
    private var bubbleGradient: LinearGradient {
        LinearGradient(
            colors: isSpecial ?
                [Color.red.opacity(0.9), Color.red.opacity(0.7)] :
                [Color.blue.opacity(0.9), Color.blue.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        Text("\(number)")
            .font(.system(.body, design: .rounded, weight: .bold))
            .frame(width: 40, height: 40)
            .background(bubbleGradient)
            .foregroundColor(.white)
            .clipShape(Circle())
            .shadow(color: isSpecial ? .red.opacity(0.3) : .blue.opacity(0.3),
                   radius: 4, x: 0, y: 2)
    }
}

#Preview {
    HStack(spacing: 12) {
        NumberBubble(number: 42)
        NumberBubble(number: 7, isSpecial: true)
    }
    .padding()
}
