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
        self.percentages = percentages // Keep the original percentages
        self.isByPosition = isByPosition
        // Sort by percentage in descending order
        self.sortedPercentages = percentages.sorted { $0.percentage > $1.percentage }
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