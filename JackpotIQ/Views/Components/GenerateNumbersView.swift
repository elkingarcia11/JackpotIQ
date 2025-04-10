import SwiftUI

struct GenerateNumbersView: View {
    @ObservedObject var viewModel: LotteryViewModel
    @State private var showingFrequencyInfo = false
    @State private var animationId = UUID()
    @State private var showError = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.selectionState.selectedNumbers.isEmpty {
                    EmptyGenerationState()
                        .transition(.opacity)
                } else {
                    GeneratedCombinationCard(
                        viewModel: viewModel,
                        mainNumbers: Array(viewModel.selectionState.selectedNumbers),
                        specialBall: viewModel.selectionState.selectedSpecialBall ?? 0,
                        frequency: viewModel.selectionState.frequency,
                        specialBallPercentages: Dictionary(
                            viewModel.frequencyState.specialBallPercentages.map { ($0.number, $0.percentage) },
                            uniquingKeysWith: { first, _ in first }
                        ),
                        showingFrequencyInfo: $showingFrequencyInfo
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                GenerationControls(viewModel: viewModel)
                
                // Gambling disclaimer moved to bottom as footer
                LotteryDisclaimerText()
                    .padding(.top, 16)
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
    let specialBallPercentages: [Int: Double]
    @Binding var showingFrequencyInfo: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title and stats - without dropdown button
            Text(viewModel.selectionState.optimizationMethod.title)
                .font(.headline)
                .foregroundColor(.primary)
            
            // Numbers display - optimized by position
            HStack(spacing: 12) {
                ForEach(mainNumbers.sorted(), id: \.self) { number in
                    NumberBall(number: number, color: .blue)
                }
                
                // Special ball with gradient
                NumberBall(
                    number: specialBall,
                    color: .clear,
                    background: viewModel.type == .megaMillions ?
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.9), Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [Color.red.opacity(0.9), Color.red.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                    isSpecialBall: true
                )
            }
            .padding(.vertical, 8)
            
            // Display optimized by frequency combination if available
            if !viewModel.frequencyState.optimizedByFrequency.isEmpty && !viewModel.frequencyState.optimizedByPosition.isEmpty {
                Divider()
                Text("Optimized by General Frequency")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.top, 4)
                
                // Display optimized by frequency numbers with consistent size
                HStack(spacing: 12) {
                    ForEach(viewModel.frequencyState.optimizedByFrequency.prefix(5), id: \.self) { number in
                        NumberBall(number: number, color: .blue)
                    }
                    
                    // Special ball with gradient
                    if let specialBall = viewModel.frequencyState.optimizedByFrequency.last, viewModel.frequencyState.optimizedByFrequency.count > 5 {
                        NumberBall(
                            number: specialBall,
                            color: .clear,
                            background: viewModel.type == .megaMillions ?
                                LinearGradient(
                                    colors: [Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.9), Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [Color.red.opacity(0.9), Color.red.opacity(0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                            isSpecialBall: true
                        )
                    }
                }
            }
            
            Divider()
            
            // Show appropriate generation note
            // If we have optimized data (when optimized button was pressed), show the optimized note
            if !viewModel.frequencyState.optimizedByFrequency.isEmpty || !viewModel.frequencyState.optimizedByPosition.isEmpty || frequency != nil {
                OptimizedGenerationNote()
            } else {
                // Otherwise show the random note (when random button was pressed)
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

/// Displays ball-based percentage analysis
private struct BallAnalysisView: View {
    let mainNumbers: [Int]
    let specialBall: Int
    let positionPercentages: [PositionPercentages]
    let specialBallPercentages: [Int: Double]
    @EnvironmentObject var viewModel: LotteryViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Ball Analysis")
                .font(.headline)
                .padding(.bottom, 4)
            
            Text("Analysis method: \(viewModel.selectionState.optimizationMethod.title)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
            
            ForEach(mainNumbers.sorted().indices, id: \.self) { index in
                let number = mainNumbers.sorted()[index]
                let position = index + 1
                
                if let positionData = positionPercentages.first(where: { $0.position == position }) {
                    // Calculate total count for this position
                    let totalCount = positionData.percentages.reduce(0) { $0 + $1.count }
                    
                    if let numberData = positionData.percentages.first(where: { $0.number == number }) {
                        BallPercentageRow(
                            position: position,
                            number: number,
                            count: numberData.count,
                            totalCount: totalCount,
                            percentage: numberData.percentage,
                            method: viewModel.selectionState.optimizationMethod
                        )
                    }
                }
            }
            
            if let specialBallPercentage = specialBallPercentages[specialBall] {
                // Calculate total count for special balls
                let totalSpecialCount = viewModel.frequencyState.specialBallPercentages.reduce(0) { $0 + $1.count }
                let specialCount = viewModel.frequencyState.specialBallPercentages
                    .first(where: { $0.number == specialBall })?.count ?? 0
                
                SpecialBallPercentageRow(
                    number: specialBall,
                    count: specialCount,
                    totalCount: totalSpecialCount,
                    percentage: specialBallPercentage,
                    lotteryType: viewModel.type
                )
            }
        }
    }
}

private struct BallPercentageRow: View {
    let position: Int
    let number: Int
    let count: Int
    let totalCount: Int
    let percentage: Double
    let method: OptimizationDisplayMethod
    
    var body: some View {
        Text("Ball \(position): \(number) appeared \(count) times (\(String(format: "%.2f", percentage))%)")
            .foregroundColor(.secondary)
            .font(.subheadline)
    }
}

private struct SpecialBallPercentageRow: View {
    let number: Int
    let count: Int
    let totalCount: Int
    let percentage: Double
    let lotteryType: LotteryType
    
    var body: some View {
        Text("\(lotteryType == .megaMillions ? "Mega Ball" : "Powerball"): \(number) appeared \(count) times (\(String(format: "%.2f", percentage))%)")
            .foregroundColor(.secondary)
            .font(.subheadline)
            .padding(.top, 4)
    }
}

/// Displays a disclaimer note for optimized number generation
private struct OptimizedGenerationNote: View {
    var body: some View {
        Text("Note: These drawings are optimized using historical data but does not aim to predict or guarantee future success.")
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
    @ObservedObject var viewModel: LotteryViewModel
    @State private var optimizedGenerated = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Generate Optimized button (without dropdown)
            Button {
                Task {
                    optimizedGenerated = true
                    await viewModel.generateCombination(optimized: true)
                }
            } label: {
                HStack {
                    Image(systemName: "wand.and.stars")
                    Text("Generate Optimized")
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
            .disabled(optimizedGenerated)
            .opacity(optimizedGenerated ? 0.6 : 1.0)
            
            Button {
                Task {
                    // Re-enable the optimized button when random is pressed
                    optimizedGenerated = false
                    
                    await viewModel.generateCombination(optimized: false)
                }
            } label: {
                HStack {
                    Image(systemName: "dice")
                    Text("Generate Random")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(colors: [.purple, .purple.opacity(0.8)],
                                 startPoint: .top,
                                 endPoint: .bottom)
                )
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(color: .purple.opacity(0.3), radius: 5, x: 0, y: 2)
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
