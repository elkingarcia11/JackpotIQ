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
                            Label("Search Numbers", systemImage: "magnifyingglass")
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
                    let results = viewModel.searchState.isSearching ?
                        viewModel.searchState.searchResults :
                        viewModel.filteredResults(for: selectedDate)
                    
                    if viewModel.searchState.isSearching && results.isEmpty {
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
                    } else {
                        // Results List
                        ForEach(results, id: \.drawDate) { combination in
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
                        in: viewModel.oldestResultDate...Date(),
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
    }
}

private struct CombinationRow: View {
    let combination: LatestCombination
    let type: LotteryType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Date and Prize Info
            HStack {
                Text(combination.drawDate)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                
                if let prize = combination.prize {
                    Spacer()
                    Text(prize)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.green)
                }
            }
            
            // Numbers Display
            HStack(spacing: 8) {
                // Main Numbers
                ForEach(combination.mainNumbers, id: \.self) { number in
                    Text("\(number)")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color.blue.opacity(0.9))
                                .shadow(color: .blue.opacity(0.3), radius: 2, x: 0, y: 2)
                        )
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Special Ball
                Text("\(combination.specialBall)")
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(type == .megaMillions ?
                                Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.9) :
                                Color.red.opacity(0.9))
                            .shadow(color: (type == .megaMillions ?
                                Color.yellow : Color.red).opacity(0.3),
                                radius: 2, x: 0, y: 2)
                    )
                    .foregroundColor(type == .megaMillions ? .black : .white)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .padding(.horizontal)
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
