import SwiftUI

struct FrequencyChartsView: View {
    let lotteryType: LotteryType
    let numberPercentages: [NumberPercentage]
    let positionPercentages: [Int: [NumberPercentage]]
    let specialBallPercentages: [NumberPercentage]
    let totalDraws: Int?
    let optimizedByPosition: [Int]?
    let optimizedByFrequency: [Int]?
    
    @State private var selectedTab = 0
    
    init(
        lotteryType: LotteryType,
        numberPercentages: [NumberPercentage],
        positionPercentages: [Int: [NumberPercentage]],
        specialBallPercentages: [NumberPercentage],
        totalDraws: Int? = nil,
        optimizedByPosition: [Int]? = nil,
        optimizedByFrequency: [Int]? = nil
    ) {
        self.lotteryType = lotteryType
        self.numberPercentages = numberPercentages
        self.positionPercentages = positionPercentages
        self.specialBallPercentages = specialBallPercentages
        self.totalDraws = totalDraws
        self.optimizedByPosition = optimizedByPosition
        self.optimizedByFrequency = optimizedByFrequency
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Picker
            Picker("Chart Type", selection: $selectedTab) {
                Text("General").tag(0)
                Text(lotteryType.specialBallName).tag(1)
                Text("By Ball").tag(2)
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
                                percentages: numberPercentages.sorted(by: { $0.percentage > $1.percentage })
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
                                percentages: specialBallPercentages.sorted(by: { $0.percentage > $1.percentage })
                            )
                            .padding()
                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: geometry.size.height)
                    }
                }
                .tag(1)
                
                // Ball Frequencies
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(Array(positionPercentages.keys).sorted(), id: \.self) { position in
                            if let percentages = positionPercentages[position], position < 5 {
                                PercentageChart(
                                    title: "Ball \(position+1) Frequencies",
                                    percentages: percentages.sorted(by: { $0.percentage > $1.percentage }),
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

// Helper components for the Statistics tab
struct StatisticsCardView<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
            
            content()
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
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
        ],
        totalDraws: 2909,
        optimizedByPosition: [2, 17, 31, 38, 50, 3],
        optimizedByFrequency: [10, 17, 20, 31, 46, 3]
    )
}
