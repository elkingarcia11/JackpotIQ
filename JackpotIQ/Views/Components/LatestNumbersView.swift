import SwiftUI

struct LatestNumbersView: View {
    @ObservedObject var viewModel: LotteryViewModel
    @State private var selectedDate = Date()
    @State private var showDatePicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Section
            VStack(spacing: 16) {
                // Search and Filter Row
                HStack(spacing: 12) {
                    // Search Button
                    Button(action: { viewModel.searchState.showSearchSheet = true }) {
                        HStack {
                            Label("Check for Match", systemImage: "magnifyingglass")
                                .font(.body.weight(.medium))
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.blue.opacity(0.9),
                                    Color.blue.opacity(0.7)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .frame(maxWidth: .infinity)
                    .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    // Filter Button
                    Button(action: { showDatePicker = true }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.blue.opacity(0.9),
                                        Color.blue.opacity(0.7)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                    }
                    .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                
                // Search note
                Text("Searching for a specific combination can help you determine whether it's statistically worth playing, as no winning combination has ever repeated.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
                
                // Search Active Indicator
                if viewModel.searchState.isSearching {
                    HStack {
                        Text("Search Results")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button(action: { viewModel.clearSearch() }) {
                            Label("Clear Search", systemImage: "xmark.circle.fill")
                                .font(.body.weight(.medium))
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    )
                }
            }
            .padding()
            .background(Color(.systemBackground))
            
            // Results Section
            ScrollView {
                LazyVStack(spacing: 12) {
                    // Title with simplified text
                    Text("Latest Winning Numbers")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                    
                    // Use results with proper filtering
                    let results = viewModel.searchState.isSearching ?
                        viewModel.searchState.searchResults :
                        viewModel.filteredResults(for: selectedDate)
                    
                    if viewModel.isLoading {
                        // Loading State
                        VStack {
                            ProgressView()
                                .scaleEffect(1.5)
                                .padding()
                            Text("Loading latest results...")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else if viewModel.searchState.isSearching && results.isEmpty {
                        // Empty Search Results
                        VStack(spacing: 20) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            VStack(spacing: 8) {
                                Text("No combinations found")
                                    .font(.title3.weight(.medium))
                                    .foregroundColor(.primary)
                                
                                Text("Try different numbers or add/remove the \(viewModel.type.specialBallName)")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else if results.isEmpty {
                        // Empty Latest Results 
                        VStack(spacing: 20) {
                            Image(systemName: "exclamationmark.circle")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            VStack(spacing: 8) {
                                Text("No results available")
                                    .font(.title3.weight(.medium))
                                    .foregroundColor(.primary)
                                
                                Text("Unable to load the latest lottery results. Try refreshing or check your connection.")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            
                            Button {
                                Task {
                                    await viewModel.loadAllData()
                                }
                            } label: {
                                Label("Refresh Data", systemImage: "arrow.clockwise")
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        // Results List
                        ForEach(Array(results.enumerated()), id: \.offset) { index, combination in
                            CombinationRow(combination: combination, type: viewModel.type)
                        }
                        
                        // Load More Indicator
                        if !viewModel.searchState.isSearching && viewModel.hasMoreResults {
                            ProgressView()
                                .padding()
                                .onAppear {
                                    Task {
                                        await viewModel.loadMoreResults()
                                    }
                                }
                        }
                    }
                }
                .padding(.vertical)
            }
        }
        .sheet(isPresented: $viewModel.searchState.showSearchSheet) {
            SearchNumbersSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showDatePicker) {
            NavigationView {
                VStack {
                    DatePicker(
                        "Select Date",
                        selection: $selectedDate,
                        in: viewModel.oldestResultDate...Calendar.current.date(from: DateComponents(year: 2025, month: 12, day: 31))!,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .padding()
                }
                .navigationTitle("Filter by Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            showDatePicker = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .task {
            if viewModel.latestResults.isEmpty && viewModel.viewState != .loading {
                await viewModel.loadAllData()
            }
        }
    }
}

private struct CombinationRow: View {
    let combination: LatestCombination
    let type: LotteryType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Date and Prize Info - Increased font size
            HStack {
                Text(formattedDate)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let prize = combination.prize {
                    Spacer()
                    Text(prize)
                        .font(.headline)
                        .foregroundColor(.green)
                }
            }
            
            // Numbers Display - All balls together with more space between
            HStack(spacing: 12) {
                // Main Numbers - Using default size from NumberBall (44pt)
                ForEach(combination.numbers, id: \.self) { number in
                    NumberBall(number: number, color: .blue)
                }
                
                // Special Ball - Now next to regular balls
                NumberBall(
                    number: combination.specialBall,
                    color: .clear,
                    background: type == .megaMillions ?
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
            .padding(.vertical, 8) // Match padding from Generate tab
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16) // Matching cornerRadius of background
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
    }
    
    // Format date to be more user-friendly
    private var formattedDate: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = dateFormatter.date(from: combination.date) else {
            return combination.date
        }
        
        // Use a more user-friendly date format
        dateFormatter.dateStyle = .medium
        return dateFormatter.string(from: date)
    }
}

// MARK: - Preview Provider
struct LatestNumbersView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LatestNumbersView(
                viewModel: LotteryViewModel(type: .megaMillions)
            )
            .sheet(isPresented: .constant(false)) {
                Text("Search Numbers")
            }
        }
    }
}
