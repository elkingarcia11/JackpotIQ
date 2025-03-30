import SwiftUI

struct GenerateNumbersView: View {
    @ObservedObject var viewModel: LotteryViewModel
    @State private var animationId = UUID()
    @State private var showError = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Generated Numbers Display
                if !viewModel.selectionState.selectedNumbers.isEmpty {
                    GeneratedCombinationCard(
                        viewModel: viewModel,
                        mainNumbers: Array(viewModel.selectionState.selectedNumbers),
                        specialBall: viewModel.selectionState.selectedSpecialBall ?? 0,
                        frequency: viewModel.selectionState.frequency
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                } else if !viewModel.isLoading {
                    EmptyGenerationState()
                        .transition(.opacity)
                }
                
                // Generate Buttons
                GenerationControls { isOptimized in
                    Task {
                        await viewModel.generateCombination(optimized: isOptimized)
                        if isOptimized {
                            // Set frequency to 0 for optimized combinations to show percentages
                            viewModel.selectionState.frequency = 0
                        }
                        animationId = UUID()
                    }
                }
                
                // Disclaimer moved to bottom
                LotteryDisclaimerText()
            }
            .padding()
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: animationId)
        }
        .overlay {
            if viewModel.isLoading {
                LoadingOverlay()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: viewModel.isLoading)
        .onChange(of: viewModel.error) { error in
            showError = error != nil
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
    }
}

// MARK: - Subviews

/// Displays a card containing the generated lottery numbers and analysis
private struct GeneratedCombinationCard: View {
    @ObservedObject var viewModel: LotteryViewModel
    let mainNumbers: [Int]
    let specialBall: Int
    let frequency: Int?
    
    private var specialBallPercentages: [Int: Double] {
        Dictionary(
            viewModel.frequencyState.specialBallPercentages.map { ($0.number, $0.percentage) },
            uniquingKeysWith: { first, _ in first }
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Numbers")
                .font(.title2.bold())
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                ForEach(mainNumbers.sorted(), id: \.self) { number in
                    NumberBubble(number: number)
                }
                NumberBubble(number: specialBall, isSpecial: true)
            }
            .padding(.vertical, 8)
            
            if frequency != nil {
                Divider()
                if !viewModel.frequencyState.positionPercentages.isEmpty {
                    PositionAnalysisView(
                        mainNumbers: mainNumbers,
                        specialBall: specialBall,
                        positionPercentages: viewModel.frequencyState.positionPercentages,
                        specialBallPercentages: specialBallPercentages
                    )
                    Divider()
                }
                OptimizedGenerationNote()
            } else {
                Divider()
                RandomGenerationNote()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 2)
        )
    }
}

/// Displays position-based percentage analysis
private struct PositionAnalysisView: View {
    let mainNumbers: [Int]
    let specialBall: Int
    let positionPercentages: [PositionPercentages]
    let specialBallPercentages: [Int: Double]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Position Analysis")
                .font(.headline)
                .padding(.bottom, 4)
            
            ForEach(mainNumbers.sorted().indices, id: \.self) { index in
                let number = mainNumbers.sorted()[index]
                let position = index + 1
                
                if let positionData = positionPercentages.first(where: { $0.position == position }),
                   let numberData = positionData.percentages.first(where: { $0.number == number }) {
                    PositionPercentageRow(
                        position: position,
                        number: number,
                        percentage: numberData.percentage
                    )
                }
            }
            
            if let specialBallPercentage = specialBallPercentages[specialBall] {
                SpecialBallPercentageRow(
                    number: specialBall,
                    percentage: specialBallPercentage
                )
            }
        }
    }
}

private struct PositionPercentageRow: View {
    let position: Int
    let number: Int
    let percentage: Double
    
    var body: some View {
        Text("Position \(position): \(number) appears in \(Int(percentage * 100))% of winning combinations")
            .foregroundColor(.secondary)
            .font(.subheadline)
    }
}

private struct SpecialBallPercentageRow: View {
    let number: Int
    let percentage: Double
    
    var body: some View {
        Text("Special Ball: \(number) appears in \(Int(percentage * 100))% of winning combinations")
            .foregroundColor(.secondary)
            .font(.subheadline)
            .padding(.top, 4)
    }
}

/// Displays a disclaimer note for optimized number generation
private struct OptimizedGenerationNote: View {
    var body: some View {
        Text("Note: This is a unique combination optimized based on historical data. While it has never won before, past performance does not guarantee future results.")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.top, 8)
    }
}

/// Displays a disclaimer note for random number generation
private struct RandomGenerationNote: View {
    var body: some View {
        Text("Note: This is a completely random unique combination that has never won before. It is not optimized based on historical data.")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.top, 8)
    }
}

/// Displays a placeholder state when no numbers have been generated
private struct EmptyGenerationState: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "ticket.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(colors: [.blue.opacity(0.8), .blue.opacity(0.6)],
                                 startPoint: .top,
                                 endPoint: .bottom)
                )
            
            Text("Ready to Try Your Luck?")
                .font(.title3.bold())
                .foregroundColor(.primary)
            
            Text("Generate your numbers below")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 2)
        )
    }
}

/// Displays the gambling disclaimer and responsible gaming message
private struct LotteryDisclaimerText: View {
    var body: some View {
        Text("Gambling Disclaimer: Playing the lottery involves risk and should be done responsibly. These generated numbers are for entertainment purposes only and do not guarantee any winnings.")
            .font(.caption2)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
            .padding(.top, 8)
    }
}

/// Control panel for generating lottery numbers
/// - Note: Provides buttons for both optimized and random number generation
private struct GenerationControls: View {
    let onGenerate: (Bool) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Button {
                onGenerate(true)
            } label: {
                HStack {
                    Image(systemName: "wand.and.stars")
                    Text("Generate Optimized Numbers")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(colors: [.blue, .blue.opacity(0.8)],
                                 startPoint: .top,
                                 endPoint: .bottom)
                )
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 2)
            }
            
            Button {
                onGenerate(false)
            } label: {
                HStack {
                    Image(systemName: "dice")
                    Text("Generate Random Numbers")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(12)
            }
        }
    }
}

/// Overlay view displayed during number generation
private struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.2)
            
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .frame(width: 120, height: 120)
                .overlay {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Generating...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .shadow(color: .black.opacity(0.1), radius: 10)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    GenerateNumbersView(viewModel: LotteryViewModel(type: .megaMillions))
        .padding()
}
