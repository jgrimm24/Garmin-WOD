import Foundation

enum MovementDisplayFormatter {
    static func heroTitle(for rawMovement: String?) -> String {
        let words = normalizedWords(from: rawMovement)
        guard !words.isEmpty else {
            return "NONE"
        }

        guard words.count > 1 else {
            return words[0]
        }

        let splitIndex = balancedSplitIndex(for: words)
        let firstLine = words[..<splitIndex].joined(separator: " ")
        let secondLine = words[splitIndex...].joined(separator: " ")

        return "\(firstLine)\n\(secondLine)"
    }

    private static func normalizedWords(from rawMovement: String?) -> [String] {
        guard let rawMovement else {
            return []
        }

        return rawMovement
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .map { String($0).uppercased() }
    }

    private static func balancedSplitIndex(for words: [String]) -> Int {
        guard words.count > 1 else {
            return 1
        }

        let wordLengths = words.map(\.count)
        let totalCharacters = wordLengths.reduce(0, +) + max(words.count - 1, 0)
        var bestIndex = 1
        var bestScore = Int.max

        for index in 1..<words.count {
            let firstLineCharacters = wordLengths[..<index].reduce(0, +) + max(index - 1, 0)
            let secondWordCount = words.count - index
            let secondLineCharacters = wordLengths[index...].reduce(0, +) + max(secondWordCount - 1, 0)
            let balanceScore = abs(firstLineCharacters - secondLineCharacters)
            let targetScore = abs((totalCharacters / 2) - firstLineCharacters)
            let score = balanceScore + targetScore

            if score < bestScore {
                bestScore = score
                bestIndex = index
            }
        }

        return bestIndex
    }
}
