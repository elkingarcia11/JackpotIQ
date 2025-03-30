import Foundation
import SwiftUI

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
        
        var canCheckCombination: Bool {
            selectedNumbers.count == 5 && selectedSpecialBall != nil
        }
    }
    
    // MARK: - Properties
    let type: LotteryType
    private let networkService: NetworkServiceProtocol
    
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
        latestResults.min { $0.date < $1.date }?.date ?? Date()
    }
    
    // MARK: - Initialization
    init(type: LotteryType, networkService: NetworkServiceProtocol = NetworkService.shared) {
        self.type = type
        self.networkService = networkService
    }
    
    // MARK: - Public Methods
    func loadAllData() async {
        viewState = .loading
        
        do {
            async let latestTask = networkService.fetchLatestCombinations(for: type, page: 1, pageSize: 20)
            async let mainFrequenciesTask = networkService.fetchNumberFrequencies(for: type, category: "main")
            async let specialFrequenciesTask = networkService.fetchNumberFrequencies(for: type, category: "special")
            async let positionFrequenciesTask = networkService.fetchPositionFrequencies(for: type, position: nil)
            
            let (latestResponse, mainFrequencies, specialFrequencies, positionFrequencies) =
                try await (latestTask, mainFrequenciesTask, specialFrequenciesTask, positionFrequenciesTask)
            
            latestResults = latestResponse.combinations
            hasMoreResults = latestResponse.hasMore
            
            frequencyState.numberPercentages = mainFrequencies.map(NumberPercentage.init)
            frequencyState.specialBallPercentages = specialFrequencies.map(NumberPercentage.init)
            
            // Group position frequencies by position
            let groupedPositions = Dictionary(grouping: positionFrequencies) { $0.position }
            frequencyState.positionPercentages = groupedPositions.map { position, frequencies in
                PositionPercentages(
                    position: position,
                    percentages: frequencies.map { frequency in
                        NumberPercentage(from: NumberFrequency(
                            number: frequency.number,
                            count: frequency.count,
                            percentage: frequency.percentage
                        ))
                    }
                )
            }.sorted { $0.position < $1.position }
            
            viewState = .loaded
        } catch {
            viewState = .error(error.localizedDescription)
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
            let response = try await networkService.checkCombination(
                numbers: Array(selectionState.selectedNumbers).sorted(),
                specialBall: selectionState.selectedSpecialBall,
                type: type
            )
            
            selectionState.winningDates = response.dates
            selectionState.frequency = response.frequency
            viewState = .loaded
        } catch {
            viewState = .error(error.localizedDescription)
        }
    }
    
    func generateCombination(optimized: Bool = true) async {
        viewState = .loading
        
        do {
            let mainNumbers: [Int]
            let specialBall: Int
            
            if optimized {
                let response = try await networkService.generateOptimizedCombination(for: type)
                mainNumbers = response.mainNumbers
                specialBall = response.specialBall
                
                // Update position percentages for optimized combinations
                if let positionPercentages = response.positionPercentages {
                    let groupedPercentages = Dictionary(grouping: positionPercentages.map { (position, percentage) in
                        let number = mainNumbers[Int(position)! - 1]
                        return PositionFrequency(position: Int(position)!, number: number, count: 0, percentage: percentage)
                    }) { $0.position }
                    
                    frequencyState.positionPercentages = groupedPercentages.map { position, frequencies in
                        PositionPercentages(
                            position: position,
                            percentages: frequencies.map { frequency in
                                NumberPercentage(from: NumberFrequency(
                                    number: frequency.number,
                                    count: frequency.count,
                                    percentage: frequency.percentage
                                ))
                            }
                        )
                    }.sorted { $0.position < $1.position }
                }
            } else {
                let response = try await networkService.generateRandomCombination(for: type)
                mainNumbers = response.mainNumbers
                specialBall = response.specialBall
                // Clear position percentages for random combinations
                frequencyState.positionPercentages = []
            }
            
            selectionState.selectedNumbers = Set(mainNumbers)
            selectionState.selectedSpecialBall = specialBall
            viewState = .loaded
        } catch {
            viewState = .error(error.localizedDescription)
        }
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
            let response = try await networkService.checkCombination(
                numbers: Array(searchState.searchNumbers).sorted(),
                specialBall: searchState.searchSpecialBall,  // Pass the special ball if selected
                type: type
            )
            
            // Convert matches to LatestCombination objects
            searchState.searchResults = response.matches.map { match in
                LatestCombination(
                    drawDate: match.date,
                    mainNumbers: response.mainNumbers,
                    specialBall: match.specialBall,
                    prize: match.prize
                )
            }
            viewState = .loaded
        } catch {
            viewState = .error(error.localizedDescription)
        }
    }
    
    func clearSearch() {
        searchState.reset()
    }
    
    func filteredResults(for date: Date) -> [LatestCombination] {
        let calendar = Calendar.current
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: date) ?? date
        return latestResults.filter { combination in
            combination.date <= endOfDay
        }
    }
    
    // MARK: - Private Methods
    private func resetResults() {
        selectionState.winningDates = nil
        selectionState.frequency = nil
    }
}
