import SwiftUI

// MARK: - Main Chart View
struct PercentageChart: View {
    let title: String
    let percentages: [NumberPercentage]
    let isByPosition: Bool
    
    @State private var searchText: String = ""
    @State private var selectedPercentage: NumberPercentage?
    @State private var hoveredNumber: Int?
    
    // Cached computed values
    private let maxPercentage: Double
    private let sortedPercentages: [NumberPercentage]
    
    init(title: String, percentages: [NumberPercentage], isByPosition: Bool = false) {
        self.title = title
        self.percentages = percentages
        self.isByPosition = isByPosition
        self.sortedPercentages = percentages.sorted { $0.number < $1.number }
        self.maxPercentage = percentages.map { $0.percentage }.max() ?? 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HeaderView(title: title, percentages: percentages)
            
            if percentages.isEmpty {
                EmptyStateView()
            } else {
                SearchBarView(searchText: $searchText)
                ChartContentView(
                    percentages: filteredPercentages,
                    maxPercentage: maxPercentage,
                    isByPosition: isByPosition,
                    selectedPercentage: $selectedPercentage,
                    hoveredNumber: $hoveredNumber
                )
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Filtering Logic
    private var filteredPercentages: [NumberPercentage] {
        if searchText.isEmpty { return sortedPercentages }
        return sortedPercentages.filter {
            String($0.number).contains(searchText)
        }
    }
}

// MARK: - Header View
struct HeaderView: View {
    let title: String
    let percentages: [NumberPercentage]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .accessibilityAddTraits(.isHeader)
                .padding(.top)
            
            if !percentages.isEmpty {
                StatsView(percentages: percentages)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Stats View
struct StatsView: View {
    let percentages: [NumberPercentage]
    
    var body: some View {
        HStack(spacing: 16) {
            StatView(title: "Total Numbers", value: "\(percentages.count)")
            StatView(
                title: "Most Frequent",
                value: percentages.max { $0.percentage < $1.percentage }
                    .map { "#\($0.number)" } ?? "N/A"
            )
        }
        .padding(.bottom, 4)
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    var body: some View {
        Text("No data available")
            .font(.callout)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 20)
    }
}

// MARK: - Search Bar View
struct SearchBarView: View {
    @Binding var searchText: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search number", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)
                .accessibilityLabel("Search numbers")
        }
        .padding(.horizontal)
    }
}

// MARK: - Chart Content View
struct ChartContentView: View {
    let percentages: [NumberPercentage]
    let maxPercentage: Double
    let isByPosition: Bool
    @Binding var selectedPercentage: NumberPercentage?
    @Binding var hoveredNumber: Int?
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(percentages) { item in
                    ChartRowView(
                        item: item,
                        maxPercentage: maxPercentage,
                        isSelected: false,
                        isHovered: hoveredNumber == item.number,
                        onTap: {},
                        onHover: { hoveredNumber = $0 ? item.number : nil }
                    )
                }
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: isByPosition ? 300 : nil)
    }
}

// MARK: - Chart Row View
struct ChartRowView: View {
    let item: NumberPercentage
    let maxPercentage: Double
    let isSelected: Bool
    let isHovered: Bool
    let onTap: () -> Void
    let onHover: (Bool) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            NumberCircleView(number: item.number, isHovered: isHovered, onHover: onHover)
            PercentageBarView(percentage: item.percentage, maxPercentage: maxPercentage)
        }
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Number \(item.number): \(String(format: "%.1f", item.percentage))%")
    }
}

// MARK: - Number Circle View
struct NumberCircleView: View {
    let number: Int
    let isHovered: Bool
    let onHover: (Bool) -> Void
    
    var body: some View {
        Text("\(number)")
            .font(.system(.body, design: .rounded, weight: .medium))
            .frame(width: 36, height: 36)
            .background(
                Circle()
                    .fill(Color.blue.opacity(isHovered ? 0.2 : 0.1))
                    .animation(.easeInOut(duration: 0.2), value: isHovered)
            )
            .onHover(perform: onHover)
    }
}

// MARK: - Percentage Bar View
struct PercentageBarView: View {
    let percentage: Double
    let maxPercentage: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.3),
                                Color.blue.opacity(0.15)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(geometry.size.width * CGFloat(percentage / (maxPercentage * 1.1)), 40))
                    .animation(.spring(response: 0.3), value: percentage)
                
                Text(String(format: "%.1f%%", percentage))
                    .font(.system(.callout, design: .rounded, weight: .medium))
                    .foregroundColor(.primary)
                    .padding(.leading, 8)
            }
        }
        .frame(height: 24)
    }
}

// MARK: - Stat View
struct StatView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Preview
#Preview {
    PercentageChart(
        title: "Number Percentages",
        percentages: [
            NumberPercentage(from: NumberFrequency(number: 1, count: 0, percentage: 0.0)),
            NumberPercentage(from: NumberFrequency(number: 2, count: 75, percentage: 7.5)),
            NumberPercentage(from: NumberFrequency(number: 3, count: 40, percentage: 4.0))
        ],
        isByPosition: true
    )
    .padding()
    .previewLayout(.sizeThatFits)
}
