import Foundation

// MARK: - Protocols
protocol LotteryGame {
    var mainNumberRange: ClosedRange<Int> { get }
    var specialBallRange: ClosedRange<Int> { get }
    var specialBallName: String { get }
    var apiEndpoint: String { get }
    var specialBallKey: String { get }
}

// MARK: - Enums
enum LotteryType: String, Hashable {
    case megaMillions = "mega-millions"
    case powerball = "powerball"
}

extension LotteryType: LotteryGame {
    var mainNumberRange: ClosedRange<Int> {
        switch self {
        case .megaMillions: return 1...70
        case .powerball: return 1...69
        }
    }
    
    var specialBallRange: ClosedRange<Int> {
        switch self {
        case .megaMillions: return 1...25
        case .powerball: return 1...26
        }
    }
    
    var specialBallName: String {
        switch self {
        case .megaMillions: return "Mega Ball"
        case .powerball: return "Powerball"
        }
    }
    
    var apiEndpoint: String {
        rawValue
    }
    
    var specialBallKey: String {
        switch self {
        case .megaMillions: return "mega_ball"
        case .powerball: return "powerball"
        }
    }
}

// MARK: - API Response Models
struct LotteryStatistics: Codable {
    let type: String
    let totalDraws: Int
    let frequency: [String: Int]
    let frequencyAtPosition: [String: [String: Int]]
    let specialBallFrequency: [String: Int]
    let optimizedByPosition: [Int]
    let optimizedByGeneralFrequency: [Int]
    
    // Custom decoding to handle the numeric string keys and optional fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        type = try container.decode(String.self, forKey: .type)
        totalDraws = try container.decode(Int.self, forKey: .totalDraws)
        
        // Decode dictionaries with string keys representing numbers
        let rawFrequency = try container.decode([String: Int].self, forKey: .frequency)
        frequency = rawFrequency
        
        let rawFrequencyAtPosition = try container.decode([String: [String: Int]].self, forKey: .frequencyAtPosition)
        frequencyAtPosition = rawFrequencyAtPosition
        
        let rawSpecialBallFrequency = try container.decode([String: Int].self, forKey: .specialBallFrequency)
        specialBallFrequency = rawSpecialBallFrequency
        
        // Safely decode arrays that might be missing in older API responses
        optimizedByPosition = try container.decodeIfPresent([Int].self, forKey: .optimizedByPosition) ?? []
        optimizedByGeneralFrequency = try container.decodeIfPresent([Int].self, forKey: .optimizedByGeneralFrequency) ?? []
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case totalDraws
        case frequency
        case frequencyAtPosition
        case specialBallFrequency
        case optimizedByPosition
        case optimizedByGeneralFrequency
    }
}

struct NumberFrequency: Codable, Identifiable {
    let number: Int
    let count: Int
    let percentage: Double
    
    var id: Int { number }
}

struct PositionFrequency: Codable {
    let position: Int
    let number: Int
    let count: Int
    let percentage: Double
}

struct CombinationCheckResponse: Codable {
    let exists: Bool
    let frequency: Int?
    let dates: [String]?
    let mainNumbers: [Int]
    let specialBall: Int?
    let matches: [Match]
    
    enum CodingKeys: String, CodingKey {
        case exists, frequency, dates, matches
        case mainNumbers = "main_numbers"
        case specialBall = "special_ball"
    }
    
    struct Match: Codable {
        let date: String
        let specialBall: Int
        let prize: String?
        
        enum CodingKeys: String, CodingKey {
            case date
            case specialBall = "special_ball"
            case prize
        }
    }
}

struct OptimizedCombination: Codable {
    let mainNumbers: [Int]
    let specialBall: Int
    let positionPercentages: [String: Double]?
    let isUnique: Bool
    
    enum CodingKeys: String, CodingKey {
        case mainNumbers = "main_numbers"
        case specialBall = "special_ball"
        case positionPercentages = "position_percentages"
        case isUnique = "is_unique"
    }
}

struct RandomCombination: Codable {
    let mainNumbers: [Int]
    let specialBall: Int
    let isUnique: Bool
    
    enum CodingKeys: String, CodingKey {
        case mainNumbers = "main_numbers"
        case specialBall = "special_ball"
        case isUnique = "is_unique"
    }
}

struct LatestCombination: Codable, Identifiable {
    let date: String
    let numbers: [Int]
    let specialBall: Int
    let type: String
    let prize: String?
    
    var id: String { date }
    
    // Use a static formatter for better performance and reliability
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX") // Use POSIX locale for consistent parsing
        formatter.timeZone = TimeZone(secondsFromGMT: 0)      // Use UTC time zone
        return formatter
    }()
    
    var formattedDate: Date {
        Self.dateFormatter.date(from: date) ?? Date()
    }
}

struct LatestCombinationsResponse: Codable {
    let combinations: [LatestCombination]
    let totalCount: Int
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case combinations
        case totalCount = "total_count"
        case hasMore = "has_more"
    }
}

// MARK: - View Models
struct NumberPercentage: Identifiable, Equatable {
    let id = UUID()
    let number: Int
    let count: Int
    let percentage: Double
    
    init(from frequency: NumberFrequency) {
        self.number = frequency.number
        self.count = frequency.count
        self.percentage = frequency.percentage
    }
    
    init(from positionFrequency: PositionFrequency) {
        self.number = positionFrequency.number
        self.count = positionFrequency.count
        self.percentage = positionFrequency.percentage
    }
    
    static func == (lhs: NumberPercentage, rhs: NumberPercentage) -> Bool {
        lhs.number == rhs.number
    }
}

struct PositionPercentages: Identifiable {
    let id = UUID()
    let position: Int
    let percentages: [NumberPercentage]
}

// MARK: - Error Models
struct ErrorResponse: Codable {
    let success: Bool
    let message: String?
}

/// Represents frequency data for a specific position in the lottery numbers
struct PositionData: Identifiable {
    let id = UUID()
    let position: Int
    let percentages: [Int: Double]
}

struct LotteryGenerationResponse: Codable, Equatable {
    let main_numbers: [Int]
    let special_ball: Int
    let position_percentages: [String: Double]?
    let is_unique: Bool
    
    // Custom Equatable implementation since Dictionary is not automatically Equatable
    static func == (lhs: LotteryGenerationResponse, rhs: LotteryGenerationResponse) -> Bool {
        lhs.main_numbers == rhs.main_numbers &&
        lhs.special_ball == rhs.special_ball &&
        lhs.is_unique == rhs.is_unique &&
        lhs.position_percentages?.keys.sorted() == rhs.position_percentages?.keys.sorted() &&
        (lhs.position_percentages == nil && rhs.position_percentages == nil ||
         lhs.position_percentages?.values.sorted() == rhs.position_percentages?.values.sorted())
    }
}
