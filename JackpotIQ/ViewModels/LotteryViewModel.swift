import Foundation
import SwiftUI
import OSLog

// Move enum outside the class
enum OptimizationDisplayMethod {
    case byPosition
    case byGeneralFrequency
    
    var title: String {
        switch self {
        case .byPosition:
            return "Optimized by Ball Position"
        case .byGeneralFrequency:
            return "Optimized by Overall Frequency"
        }
    }
    
    var apiMethod: OptimizationMethod {
        switch self {
        case .byPosition:
            return .byPosition
        case .byGeneralFrequency:
            return .byGeneralFrequency
        }
    }
}

@MainActor
class LotteryViewModel: ObservableObject {
    // MARK: - Types
    enum ViewState: Equatable {
        case idle
        case loading
        case error(String)
        case loaded
        
        static func == (lhs: ViewState, rhs: ViewState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle),
                 (.loading, .loading),
                 (.loaded, .loaded):
                return true
            case (.error(let lhsError), .error(let rhsError)):
                return lhsError == rhsError
            default:
                return false
            }
        }
    }
    
    struct FrequencyState {
        var numberPercentages: [NumberPercentage] = []
        var positionPercentages: [PositionPercentages] = []
        var specialBallPercentages: [NumberPercentage] = []
        var totalDraws: Int = 0
        var optimizedByPosition: [Int] = []
        var optimizedByFrequency: [Int] = []
        var lastRefreshed: Date?
    }
    
    struct SearchState {
        var isSearching: Bool = false
        var showSearchSheet: Bool = false
        var searchNumbers: Set<Int> = []
        var searchSpecialBall: Int?
        var searchResults: [LatestCombination] = []
        
        var canSearch: Bool {
            searchNumbers.count == 5
        }
        
        mutating func reset() {
            searchNumbers.removeAll()
            searchSpecialBall = nil
            searchResults.removeAll()
            isSearching = false
        }
    }
    
    struct SelectionState {
        var selectedNumbers: Set<Int> = []
        var selectedSpecialBall: Int?
        var winningDates: [String]?
        var frequency: Int?
        var optimizationMethod: OptimizationDisplayMethod = .byPosition
        
        var canCheckCombination: Bool {
            selectedNumbers.count == 5 && selectedSpecialBall != nil
        }
    }
    
    // MARK: - Properties
    let type: LotteryType
    private let networkService: NetworkServiceProtocol
    private let logger = Logger(subsystem: "com.jackpotiq.app", category: "LotteryViewModel")
    
    @Published private(set) var viewState: ViewState = .idle
    @Published private(set) var frequencyState = FrequencyState()
    @Published var selectionState = SelectionState()
    @Published var searchState = SearchState()
    @Published var latestResults: [LatestCombination] = []
    @Published var hasMoreResults = false
    @Published var currentPage = 1
    
    var error: String? {
        if case .error(let message) = viewState {
            return message
        }
        return nil
    }
    
    var isLoading: Bool {
        viewState == .loading
    }
    
    var oldestResultDate: Date {
        latestResults.min { $0.formattedDate < $1.formattedDate }?.formattedDate ?? Date()
    }
    
    // MARK: - Initialization
    init(type: LotteryType, networkService: NetworkServiceProtocol = NetworkService.shared) {
        self.type = type
        self.networkService = networkService
    }
    
    // MARK: - Public Methods
    func loadAllData() async {
        viewState = .loading
        
        // First, let's load the latest combinations (most important for the Latest tab)
        do {
            let latestResponse = try await networkService.fetchLatestCombinations(for: type, page: 1, pageSize: 20)
            
            // Update UI with latest combinations immediately
            latestResults = latestResponse.combinations
            hasMoreResults = latestResponse.hasMore
            currentPage = 1
            
            // Check if we need to reload frequency data
            let shouldRefreshFrequencyData = needsFrequencyRefresh()
            
            if shouldRefreshFrequencyData {
                await loadFrequencyData()
            } else if frequencyState.lastRefreshed == nil {
                // If we've never loaded frequency data, load it
                await loadFrequencyData()
            }
            
            // Even if frequencies fail, we've loaded the latest tab data
            if viewState == .loading {
                viewState = .loaded
            }
        } catch {
            viewState = .error("Failed to load latest drawings: \(error.localizedDescription)")
        }
    }
    
    // Helper method to determine if frequency data needs a refresh
    private func needsFrequencyRefresh() -> Bool {
        guard let lastRefreshed = frequencyState.lastRefreshed else {
            // Never refreshed before, so yes
            return true
        }
        
        // Get current date/time
        let now = Date()
        let calendar = Calendar.current
        
        // Create 12:10 AM threshold for today
        var refreshThresholdComponents = calendar.dateComponents([.year, .month, .day], from: now)
        refreshThresholdComponents.hour = 0
        refreshThresholdComponents.minute = 10
        refreshThresholdComponents.second = 0
        
        guard let refreshThreshold = calendar.date(from: refreshThresholdComponents) else {
            // If we can't create the time, default to refreshing
            return true
        }
        
        // Check if lastRefreshed is before 12:10 AM today and now is after 12:10 AM
        let lastRefreshDay = calendar.startOfDay(for: lastRefreshed)
        let nowDay = calendar.startOfDay(for: now)
        
        // Different days and now is past threshold time, or
        // Same day but lastRefreshed is before threshold and now is after threshold
        return (lastRefreshDay != nowDay && now >= refreshThreshold) ||
               (lastRefreshDay == nowDay && lastRefreshed < refreshThreshold && now >= refreshThreshold)
    }
    
    // New method to load frequency data separately
    private func loadFrequencyData() async {
        do {
            // Load statistics first to get the totalDraws and optimized combinations
            let stats = try await networkService.fetchLotteryStatistics(for: type)
            
            // Safely assign values with defensive coding
            frequencyState.totalDraws = stats.totalDraws
            
            // Check if optimizedByPosition exists and is not empty
            if !stats.optimizedByPosition.isEmpty {
                frequencyState.optimizedByPosition = stats.optimizedByPosition
            }
            
            // Check if optimizedByGeneralFrequency exists and is not empty
            if !stats.optimizedByGeneralFrequency.isEmpty {
                frequencyState.optimizedByFrequency = stats.optimizedByGeneralFrequency
            }
            
            // Load main frequencies
            let mainFrequencies = try await networkService.fetchNumberFrequencies(for: type, category: "main")
            frequencyState.numberPercentages = mainFrequencies.map(NumberPercentage.init)
            
            // Load special ball frequencies
            let specialFrequencies = try await networkService.fetchNumberFrequencies(for: type, category: "special")
            frequencyState.specialBallPercentages = specialFrequencies.map(NumberPercentage.init)
            
            // Load position frequencies
            let positionFrequencies = try await networkService.fetchPositionFrequencies(for: type, position: nil)
            
            // Group position frequencies by position
            let groupedPositions = Dictionary(grouping: positionFrequencies) { $0.position }
            frequencyState.positionPercentages = groupedPositions.map { position, frequencies in
                PositionPercentages(
                    position: position,
                    percentages: frequencies.map { frequency in
                        NumberPercentage(from: frequency)
                    }
                )
            }.sorted { $0.position < $1.position }
            
            // Record the time we refreshed
            frequencyState.lastRefreshed = Date()
            
            viewState = .loaded
        } catch {
            // Don't set viewState to error, as we want to show latest results even if frequencies fail
            logger.error("Error loading frequency data: \(error.localizedDescription)")
        }
    }
    
    func loadMoreResults() async {
        guard hasMoreResults else { return }
        
        do {
            let nextPage = currentPage + 1
            let response = try await networkService.fetchLatestCombinations(
                for: type,
                page: nextPage,
                pageSize: 20
            )
            
            latestResults.append(contentsOf: response.combinations)
            hasMoreResults = response.hasMore
            currentPage = nextPage
        } catch {
            viewState = .error(error.localizedDescription)
        }
    }
    
    func checkCombination() async {
        guard selectionState.canCheckCombination else { return }
        
        viewState = .loading
        selectionState.winningDates = nil
        selectionState.frequency = nil
        
        do {
            // Use searchLotteryDraws for consistency with the search API
            let searchResults = try await networkService.searchLotteryDraws(
                type: type,
                numbers: Array(selectionState.selectedNumbers).sorted(),
                specialBall: selectionState.selectedSpecialBall
            )
            
            // Extract dates and calculate frequency from the results
            let dates = searchResults.map { $0.date }
            selectionState.winningDates = dates.isEmpty ? nil : dates
            selectionState.frequency = dates.isEmpty ? nil : dates.count
            
            viewState = .loaded
        } catch {
            viewState = .error(error.localizedDescription)
        }
    }
    
    // MARK: - Generate Optimized Combinations
    func generateCombination(optimized: Bool = true) async {
        viewState = .loading
        
        do {
            let mainNumbers: [Int]
            let specialBall: Int
            
            if optimized {
                // Generate optimized by position numbers
                let positionMethod = OptimizationMethod.byPosition
                let positionResponse = try await networkService.generateOptimizedCombination(for: type, method: positionMethod)
                mainNumbers = positionResponse.mainNumbers
                specialBall = positionResponse.specialBall
                
                // Set the selection state to the optimized by position results
                selectionState.selectedNumbers = Set(mainNumbers)
                selectionState.selectedSpecialBall = specialBall
                selectionState.optimizationMethod = .byPosition
                
                // Calculate position percentages based on frequencies
                await calculatePositionPercentages(for: mainNumbers, method: .byPosition)
                
                // Generic logging without number details
                logger.debug("Generated optimized combination")
                
                // Now calculate the optimized by frequency numbers for display
                let frequencyMethod = OptimizationMethod.byGeneralFrequency
                let frequencyResponse = try await networkService.generateOptimizedCombination(for: type, method: frequencyMethod)
                
                // Store the optimized by frequency numbers separately
                frequencyState.optimizedByFrequency = frequencyResponse.mainNumbers + [frequencyResponse.specialBall]
                frequencyState.optimizedByPosition = positionResponse.mainNumbers + [positionResponse.specialBall]
            } else {
                // Generate random combination
                let response = try await networkService.generateRandomCombination(for: type)
                mainNumbers = response.mainNumbers
                specialBall = response.specialBall
                
                // For random numbers, we keep the position percentages for the Analysis tab
                // but clear the optimized arrays for display purposes
                selectionState.optimizationMethod = .byPosition // Reset this to default
                
                // Set the selection state to the random results
                selectionState.selectedNumbers = Set(mainNumbers)
                selectionState.selectedSpecialBall = specialBall
                
                // Clear these for UI purposes only - this indicates a random generation
                // but doesn't affect the analysis tab data
                frequencyState.optimizedByFrequency = []
                frequencyState.optimizedByPosition = []
                
                // Simple log without details
                logger.debug("Generated random combination")
            }
            
            viewState = .loaded
        } catch {
            viewState = .error(error.localizedDescription)
        }
    }
    
    /// Logs basic information without exposing generated numbers
    private func debugPrintBallStatistics(mainNumbers: [Int], specialBall: Int) {
        // Just log a basic message with no sensitive data
        logger.debug("Generated combination statistics processed")
    }
    
    func toggleNumber(_ number: Int) {
        if selectionState.selectedNumbers.contains(number) {
            selectionState.selectedNumbers.remove(number)
        } else if selectionState.selectedNumbers.count < 5 {
            selectionState.selectedNumbers.insert(number)
        }
        resetResults()
    }
    
    func selectSpecialBall(_ number: Int) {
        if selectionState.selectedSpecialBall == number {
            selectionState.selectedSpecialBall = nil
        } else {
            selectionState.selectedSpecialBall = number
        }
        resetResults()
    }
    
    // MARK: - Search Methods
    func toggleSearchNumber(_ number: Int) {
        if searchState.searchNumbers.contains(number) {
            searchState.searchNumbers.remove(number)
        } else if searchState.searchNumbers.count < 5 {
            searchState.searchNumbers.insert(number)
        }
    }
    
    func toggleSearchSpecialBall(_ number: Int) {
        if searchState.searchSpecialBall == number {
            searchState.searchSpecialBall = nil
        } else {
            searchState.searchSpecialBall = number
        }
    }
    
    func searchWinningNumbers() async {
        guard searchState.canSearch else { return }
        
        viewState = .loading
        searchState.isSearching = true
        searchState.searchResults.removeAll()
        
        do {
            // Use searchLotteryDraws which returns the proper array response format
            searchState.searchResults = try await networkService.searchLotteryDraws(
                type: type,
                numbers: Array(searchState.searchNumbers).sorted(),
                specialBall: searchState.searchSpecialBall
            )
            
            viewState = .loaded
        } catch {
            viewState = .error(error.localizedDescription)
        }
    }
    
    func clearSearch() {
        searchState.reset()
    }
    
    func filteredResults(for date: Date) -> [LatestCombination] {
        // Convert the selected date to a string in yyyy-MM-dd format for direct string comparison
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0) // UTC
        
        // Get the selected date in string format
        let selectedDateString = dateFormatter.string(from: date)
        
        // Basic logging without specifics
        logger.debug("Filtering results by date")
        
        // Filter based on string comparison - only include dates less than or equal to the selected date
        let filteredResults = latestResults.filter { combination in
            // Direct string comparison (yyyy-MM-dd format ensures chronological ordering)
            return combination.date <= selectedDateString
        }
        
        // Just log the count
        logger.debug("Found \(filteredResults.count) filtered results")
        
        return filteredResults
    }
    
    // MARK: - Private Methods
    private func resetResults() {
        selectionState.winningDates = nil
        selectionState.frequency = nil
    }
    
    private func calculatePositionPercentages(for mainNumbers: [Int], method: OptimizationDisplayMethod) async {
        do {
            var positionPercentagesResult: [PositionPercentages] = []
            
            switch method {
            case .byPosition:
                // Fetch position frequencies and calculate percentages based on totalDraws
                let positionFrequencies = try await networkService.fetchPositionFrequencies(for: type, position: nil)
                let stats = try await networkService.fetchLotteryStatistics(for: type)
                let totalDraws = stats.totalDraws
                
                // Group position frequencies by position
                let groupedPositions = Dictionary(grouping: positionFrequencies) { $0.position }
                
                // Create position percentages with corrected calculation
                positionPercentagesResult = groupedPositions.map { position, frequencies in
                    // Calculate percentages based on totalDraws instead of sum at position
                    let adjustedPercentages = frequencies.map { frequency in
                        let adjustedPercentage = Double(frequency.count) / Double(totalDraws) * 100
                        return NumberPercentage(
                            from: NumberFrequency(
                                number: frequency.number,
                                count: frequency.count,
                                percentage: adjustedPercentage
                            )
                        )
                    }
                    
                    return PositionPercentages(
                        position: position,
                        percentages: adjustedPercentages
                    )
                }.sorted { $0.position < $1.position }
                
            case .byGeneralFrequency:
                // Fetch general frequencies and calculate percentages
                let mainFrequencies = try await networkService.fetchNumberFrequencies(for: type, category: "main")
                let stats = try await networkService.fetchLotteryStatistics(for: type)
                let totalDraws = stats.totalDraws
                
                // For each position, find the number's general frequency
                for (index, number) in mainNumbers.sorted().enumerated() {
                    let position = index + 1
                    
                    // Find the frequency data for this number
                    if let frequencyData = mainFrequencies.first(where: { $0.number == number }) {
                        // Create a percentages array with just this number
                        let percentage = Double(frequencyData.count) / Double(totalDraws) * 100
                        
                        let positionPercentage = PositionPercentages(
                            position: position,
                            percentages: [
                                NumberPercentage(
                                    from: NumberFrequency(
                                        number: number,
                                        count: frequencyData.count,
                                        percentage: percentage
                                    )
                                )
                            ]
                        )
                        
                        positionPercentagesResult.append(positionPercentage)
                    }
                }
            }
            
            frequencyState.positionPercentages = positionPercentagesResult
        } catch {
            logger.error("Error calculating position percentages: \(error.localizedDescription)")
        }
    }
    
    func toggleOptimizationMethod() {
        switch selectionState.optimizationMethod {
        case .byPosition:
            selectionState.optimizationMethod = .byGeneralFrequency
        case .byGeneralFrequency:
            selectionState.optimizationMethod = .byPosition
        }
    }
}
