import SwiftUI

struct SearchNumbersSheet: View {
    @ObservedObject var viewModel: LotteryViewModel
    @Environment(\.dismiss) private var dismiss
    
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let mainNumbersRange: ClosedRange<Int>
    private let specialBallRange: ClosedRange<Int>
    
    init(viewModel: LotteryViewModel) {
        self.viewModel = viewModel
        switch viewModel.type {
        case .megaMillions:
            mainNumbersRange = 1...70
            specialBallRange = 1...25
        case .powerball:
            mainNumbersRange = 1...69
            specialBallRange = 1...26
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Select 5 Main Numbers")
                            .font(.headline)
                        Text("\(viewModel.searchState.searchNumbers.count)/5 selected")
                            .font(.subheadline)
                            .foregroundColor(viewModel.searchState.searchNumbers.count == 5 ? .green : .secondary)
                    }
                    
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(mainNumbersRange, id: \.self) { number in
                            NumberButton(
                                number: number,
                                isSelected: viewModel.searchState.searchNumbers.contains(number),
                                action: { viewModel.toggleSearchNumber(number) }
                            )
                        }
                    }
                    
                    Text("Select \(viewModel.type.specialBallName) (Optional)")
                        .font(.headline)
                    
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(specialBallRange, id: \.self) { number in
                            NumberButton(
                                number: number,
                                isSelected: viewModel.searchState.searchSpecialBall == number,
                                isSpecialBall: true,
                                action: { viewModel.toggleSearchSpecialBall(number) }
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Search by Numbers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Search") {
                        Task {
                            await viewModel.searchWinningNumbers()
                            dismiss()
                        }
                    }
                    .disabled(!viewModel.searchState.canSearch)
                }
            }
            .environment(\.lotteryType, viewModel.type)
        }
    }
}

private struct NumberButton: View {
    let number: Int
    let isSelected: Bool
    var isSpecialBall: Bool = false
    let action: () -> Void
    @Environment(\.lotteryType) private var type
    
    var body: some View {
        Button(action: action) {
            Text("\(number)")
                .font(.system(.body, design: .rounded))
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(backgroundColor)
                )
                .foregroundColor(foregroundColor)
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            if isSpecialBall {
                return type == .megaMillions ? Color(red: 1.0, green: 0.84, blue: 0.0) : .red
            }
            return .blue
        }
        return Color(.systemGray5)
    }
    
    private var foregroundColor: Color {
        if isSelected {
            if isSpecialBall && type == .megaMillions {
                return .black
            }
            return .white
        }
        return .primary
    }
}

private struct LotteryTypeKey: EnvironmentKey {
    static let defaultValue: LotteryType = .megaMillions
}

extension EnvironmentValues {
    var lotteryType: LotteryType {
        get { self[LotteryTypeKey.self] }
        set { self[LotteryTypeKey.self] = newValue }
    }
}
