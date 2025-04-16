import Foundation

struct LotterySearchRequest: Codable {
    let type: String
    let numbers: String
    let specialBall: Int?
    
    enum CodingKeys: String, CodingKey {
        case type
        case numbers
        case specialBall = "special_ball"
    }
    
    init(type: String, numbers: String, specialBall: Int?) {
        self.type = type
        self.numbers = numbers
        self.specialBall = specialBall
    }
} 