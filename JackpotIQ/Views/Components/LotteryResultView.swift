import SwiftUI

struct LotteryResultView: View {
    let type: LotteryType
    let numbers: [Int]
    let specialBall: Int
    let winningDates: [String]?
    let frequency: Int?
    
    var body: some View {
        VStack(spacing: 24) {
            // Numbers display
            HStack(spacing: 12) {
                ForEach(numbers, id: \.self) { number in
                    NumberBall(number: number, color: .blue)
                }
                
                // Special ball with gradient
                NumberBall(
                    number: specialBall,
                    color: .clear,
                    background: type == .megaMillions ?
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [.red, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                )
            }
            .padding(.top, 32)
            
            if let dates = winningDates, !dates.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Winning Dates")
                            .font(.headline)
                        Spacer()
                        if let frequency = frequency {
                            Text("Won \(frequency) times")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    ForEach(dates, id: \.self) { date in
                        Text(date)
                            .font(.body)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
            } else {
                Text("This combination has never won")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Results")
    }
}

struct NumberBall: View {
    let number: Int
    let color: Color
    var background: LinearGradient?
    
    init(number: Int, color: Color, background: LinearGradient? = nil) {
        self.number = number
        self.color = color
        self.background = background
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(background ?? LinearGradient(
                    colors: [color],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            
            Text("\(number)")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: 44, height: 44)
    }
}

#Preview {
    NavigationView {
        LotteryResultView(
            type: .megaMillions,
            numbers: [1, 2, 3, 4, 5],
            specialBall: 6,
            winningDates: ["January 1, 2024", "February 15, 2024"],
            frequency: 2
        )
    }
}
