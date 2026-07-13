import Foundation

struct LatestLoadGeneration {
    private var value = 0

    mutating func begin() -> Int {
        value += 1
        return value
    }

    func isCurrent(_ candidate: Int) -> Bool {
        candidate == value
    }
}
