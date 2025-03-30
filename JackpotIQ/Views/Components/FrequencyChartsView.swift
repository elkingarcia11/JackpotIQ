import SwiftUI

struct FrequencyChartsView: View {
    let lotteryType: LotteryType
    let numberPercentages: [NumberPercentage]
    let positionPercentages: [Int: [NumberPercentage]]
    let specialBallPercentages: [NumberPercentage]
    
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Picker
            Picker("Chart Type", selection: $selectedTab) {
                Text("General").tag(0)
                Text(lotteryType.specialBallName).tag(1)
                Text("By Position").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()
            .background(Color(.systemBackground))
            
            TabView(selection: $selectedTab) {
                // General Frequencies
                GeometryReader { geometry in
                    ScrollView {
                        VStack {
                            PercentageChart(
                                title: "General Number Frequencies",
                                percentages: numberPercentages
                            )
                            .padding()
                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: geometry.size.height)
                    }
                }
                .tag(0)
                
                // Special Ball Frequencies
                GeometryReader { geometry in
                    ScrollView {
                        VStack {
                            PercentageChart(
                                title: "\(lotteryType == .megaMillions ? "Mega Ball" : "Powerball") Frequencies",
                                percentages: specialBallPercentages
                            )
                            .padding()
                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: geometry.size.height)
                    }
                }
                .tag(1)
                
                // Position Frequencies
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(Array(positionPercentages.keys).sorted(), id: \.self) { position in
                            if let percentages = positionPercentages[position] {
                                PercentageChart(
                                    title: "Position \(position + 1) Frequencies",
                                    percentages: percentages,
                                    isByPosition: true
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                }
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .background(Color(.systemGroupedBackground))
        }
        .navigationTitle("Frequency Analysis")
    }
}

#Preview {
    FrequencyChartsView(
        lotteryType: .megaMillions,
        numberPercentages: [
            NumberPercentage(from: NumberFrequency(number: 1, count: 50, percentage: 5.0)),
            NumberPercentage(from: NumberFrequency(number: 2, count: 75, percentage: 7.5))
        ],
        positionPercentages: [
            0: [NumberPercentage(from: NumberFrequency(number: 1, count: 30, percentage: 3.0))],
            1: [NumberPercentage(from: NumberFrequency(number: 2, count: 40, percentage: 4.0))]
        ],
        specialBallPercentages: [
            NumberPercentage(from: NumberFrequency(number: 1, count: 60, percentage: 6.0))
        ]
    )
}
