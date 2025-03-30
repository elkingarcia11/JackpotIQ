import SwiftUI

struct NumberGrid: View {
    let range: ClosedRange<Int>
    let columns: Int
    let selectedNumbers: Set<Int>
    let maxSelections: Int
    let onNumberTapped: (Int) -> Void
    
    private let gridItems: [GridItem]
    
    init(
        range: ClosedRange<Int>,
        columns: Int = 7,
        selectedNumbers: Set<Int>,
        maxSelections: Int,
        onNumberTapped: @escaping (Int) -> Void
    ) {
        self.range = range
        self.columns = columns
        self.selectedNumbers = selectedNumbers
        self.maxSelections = maxSelections
        self.onNumberTapped = onNumberTapped
        
        self.gridItems = Array(repeating: GridItem(.flexible(), spacing: 8), count: columns)
    }
    
    var body: some View {
        LazyVGrid(columns: gridItems, spacing: 8) {
            ForEach(range, id: \.self) { number in
                NumberCell(
                    number: number,
                    isSelected: selectedNumbers.contains(number),
                    isEnabled: selectedNumbers.contains(number) || selectedNumbers.count < maxSelections
                )
                .onTapGesture {
                    onNumberTapped(number)
                }
            }
        }
        .padding()
    }
}

struct NumberCell: View {
    let number: Int
    let isSelected: Bool
    let isEnabled: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
            
            Text("\(number)")
                .font(.system(.body, design: .rounded))
                .foregroundColor(textColor)
        }
        .frame(width: 40, height: 40)
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return .blue
        }
        return isEnabled ? Color(.systemGray6) : Color(.systemGray4)
    }
    
    private var textColor: Color {
        isSelected ? .white : .primary
    }
}

struct NumberGrid_Previews: PreviewProvider {
    static var previews: some View {
        NumberGrid(
            range: 1...69,
            selectedNumbers: [1, 2, 3],
            maxSelections: 5,
            onNumberTapped: { _ in }
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
