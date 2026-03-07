import Foundation

struct NumericInputBuffer: Equatable {
    private(set) var text: String
    let maxFractionDigits: Int

    init(initialValue: Decimal = 0, maxFractionDigits: Int = 4) {
        self.maxFractionDigits = max(0, maxFractionDigits)

        if initialValue == 0 {
            self.text = ""
        } else {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.usesGroupingSeparator = false
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = self.maxFractionDigits
            formatter.decimalSeparator = "."
            self.text = formatter.string(from: NSDecimalNumber(decimal: initialValue)) ?? ""
        }
    }

    init(initialText: String, maxFractionDigits: Int = 4) {
        self.maxFractionDigits = max(0, maxFractionDigits)
        self.text = ""

        // If a dot already exists, treat commas as grouping separators.
        // Otherwise allow a single comma to behave like a decimal separator.
        let containsDot = initialText.contains(".")
        initialText.forEach { character in
            if containsDot, character == "," {
                return
            }
            appendCharacter(character)
        }
    }

    var decimalValue: Decimal {
        guard !text.isEmpty else { return 0 }
        return Decimal(string: text) ?? 0
    }

    mutating func appendCharacter(_ character: Character) {
        if character.isNumber {
            appendDigit(character)
            return
        }

        if character == "." || character == "," {
            insertDecimalSeparator()
        }
    }

    mutating func appendDigit(_ digitCharacter: Character) {
        guard digitCharacter.isNumber else { return }

        if let decimalIndex = text.firstIndex(of: ".") {
            let fractionCount = text.distance(from: text.index(after: decimalIndex), to: text.endIndex)
            guard fractionCount < maxFractionDigits else { return }
        }

        text.append(digitCharacter)
    }

    mutating func insertDecimalSeparator() {
        guard maxFractionDigits > 0 else { return }
        guard !text.contains(".") else { return }

        if text.isEmpty {
            text = "0."
        } else {
            text.append(".")
        }
    }

    mutating func backspace() {
        guard !text.isEmpty else { return }
        _ = text.removeLast()
    }

    mutating func clear() {
        text = ""
    }
}
