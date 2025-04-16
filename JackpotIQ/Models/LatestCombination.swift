import Foundation

struct LatestCombination: Identifiable, Codable {
    var id: String { date }
    let date: String
    let numbers: [Int]
    let specialBall: Int
    let type: String
    
    enum CodingKeys: String, CodingKey {
        case date
        case numbers
        case specialBall = "special_ball"
        case type
    }
    
    // Computed property to get the lottery type
    var lotteryType: LotteryType {
        return type == "mega-millions" ? .megaMillions : .powerball
    }
    
    // Format the date for display
    var formattedDate: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        if let date = dateFormatter.date(from: date) {
            dateFormatter.dateStyle = .medium
            return dateFormatter.string(from: date)
        }
        
        return date
    }
} 