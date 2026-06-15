import Foundation

enum NumericExpressionOperator: String, CaseIterable {
    case add
    case subtract
    case multiply
    case divide

    var symbol: String {
        switch self {
        case .add:
            "+"
        case .subtract:
            "-"
        case .multiply:
            "×"
        case .divide:
            "÷"
        }
    }

}

enum NumericExpressionMutationResult: Equatable {
    case accepted
    case corrected
    case ignored
}

struct NumericExpressionBuffer: Equatable {
    private(set) var operands: [String]
    private(set) var operators: [NumericExpressionOperator]
    let maxFractionDigits: Int

    init(
        initialValue: Decimal = 0,
        maxFractionDigits: Int = 4,
        emptyWhenZero: Bool = true
    ) {
        self.maxFractionDigits = max(0, maxFractionDigits)
        self.operators = []

        if initialValue == 0, emptyWhenZero {
            self.operands = [""]
        } else {
            self.operands = [Self.formatRaw(initialValue, maxFractionDigits: self.maxFractionDigits)]
        }
    }

    var hasExpression: Bool {
        !operators.isEmpty
    }

    var liveDecimalValue: Decimal? {
        guard !hasExpression else { return nil }
        return Self.decimal(from: currentOperand) ?? 0
    }

    var hasContent: Bool {
        operands.contains { !$0.isEmpty }
    }

    func displayText(locale: Locale) -> String {
        guard hasContent || hasExpression else { return "" }

        var output = ""

        for index in operands.indices {
            if index > 0 {
                output += " " + operators[index - 1].symbol + " "
            }
            output += Self.formatDisplayOperand(operands[index], locale: locale)
        }

        return output
    }

    @discardableResult
    mutating func appendCharacter(_ character: Character) -> NumericExpressionMutationResult {
        if character.isNumber {
            return appendDigit(character)
        }

        if character == "." || character == "," {
            return insertDecimalSeparator()
        }

        return .ignored
    }

    @discardableResult
    mutating func appendDigit(_ digitCharacter: Character) -> NumericExpressionMutationResult {
        guard digitCharacter.isNumber else { return .ignored }

        var operand = currentOperand
        let sign = operand.hasPrefix("-") ? "-" : ""
        let unsignedOperand = sign.isEmpty ? operand : String(operand.dropFirst())

        if let decimalIndex = unsignedOperand.firstIndex(of: ".") {
            let fractionCount = unsignedOperand.distance(
                from: unsignedOperand.index(after: decimalIndex),
                to: unsignedOperand.endIndex
            )
            guard fractionCount < maxFractionDigits else { return .ignored }
        }

        if unsignedOperand == "0", !unsignedOperand.contains(".") {
            guard digitCharacter != "0" else { return .ignored }
            operand = sign + String(digitCharacter)
            updateCurrentOperand(operand)
            return .accepted
        }

        operand.append(digitCharacter)
        updateCurrentOperand(operand)
        return .accepted
    }

    @discardableResult
    mutating func insertDecimalSeparator() -> NumericExpressionMutationResult {
        guard maxFractionDigits > 0 else { return .ignored }

        var operand = currentOperand
        guard !operand.contains(".") else { return .ignored }

        if operand.isEmpty {
            operand = "0."
        } else if operand == "-" {
            operand = "-0."
        } else {
            operand.append(".")
        }

        updateCurrentOperand(operand)
        return .accepted
    }

    @discardableResult
    mutating func insertOperator(_ newOperator: NumericExpressionOperator) -> NumericExpressionMutationResult {
        let current = currentOperand

        if current.isEmpty {
            guard let lastOperatorIndex = operators.indices.last else {
                return .ignored
            }

            operators[lastOperatorIndex] = newOperator
            return .corrected
        }

        operators.append(newOperator)
        operands.append("")
        return .accepted
    }

    @discardableResult
    mutating func backspace() -> NumericExpressionMutationResult {
        guard !operands.isEmpty else { return .ignored }

        var operand = currentOperand
        if !operand.isEmpty {
            _ = operand.removeLast()
            if operand == "-" {
                operand = ""
            }
            updateCurrentOperand(operand)
            return .accepted
        }

        guard !operators.isEmpty else { return .ignored }
        _ = operators.removeLast()
        _ = operands.removeLast()
        return .accepted
    }

    @discardableResult
    mutating func commit() -> Decimal {
        let committed = Self.roundedHalfUp(evaluate(), scale: maxFractionDigits)
        self = NumericExpressionBuffer(
            initialValue: committed,
            maxFractionDigits: maxFractionDigits,
            emptyWhenZero: false
        )
        return committed
    }

    private var currentOperand: String {
        operands.last ?? ""
    }

    private mutating func updateCurrentOperand(_ value: String) {
        guard !operands.isEmpty else {
            operands = [value]
            return
        }

        operands[operands.count - 1] = value
    }

    private func evaluate() -> Decimal {
        var trimmedOperands = operands
        var trimmedOperators = operators

        while trimmedOperands.count > 1, trimmedOperands.last?.isEmpty == true {
            _ = trimmedOperands.removeLast()
            _ = trimmedOperators.removeLast()
        }

        let values = trimmedOperands.map { Self.decimal(from: $0) ?? 0 }
        guard let firstValue = values.first else { return 0 }

        var additiveValues = [firstValue]
        var additiveOperators = [NumericExpressionOperator]()

        for index in trimmedOperators.indices {
            guard index + 1 < values.count else { break }

            let op = trimmedOperators[index]
            let rhs = values[index + 1]

            switch op {
            case .multiply:
                additiveValues[additiveValues.count - 1] *= rhs
            case .divide:
                guard rhs != 0 else { continue }
                additiveValues[additiveValues.count - 1] /= rhs
            case .add, .subtract:
                additiveOperators.append(op)
                additiveValues.append(rhs)
            }
        }

        var result = additiveValues[0]
        for index in additiveOperators.indices {
            let rhs = additiveValues[index + 1]
            switch additiveOperators[index] {
            case .add:
                result += rhs
            case .subtract:
                result -= rhs
            case .multiply, .divide:
                break
            }
        }

        return result
    }

    private static func decimal(from text: String) -> Decimal? {
        guard !text.isEmpty, text != "-" else { return nil }
        return Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func formatRaw(_ value: Decimal, maxFractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maxFractionDigits
        formatter.decimalSeparator = "."
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "0"
    }

    private static func formatDisplayOperand(_ raw: String, locale: Locale) -> String {
        guard !raw.isEmpty else { return "" }

        let formatter = NumberFormatter()
        formatter.locale = locale
        let decimalSeparator = formatter.decimalSeparator ?? "."
        let groupingSeparator = formatter.groupingSeparator ?? ","

        let sign = raw.hasPrefix("-") ? "-" : ""
        let unsigned = sign.isEmpty ? raw : String(raw.dropFirst())
        let parts = unsigned.split(separator: ".", omittingEmptySubsequences: false)
        let integerPart = parts.first.map(String.init) ?? "0"
        let groupedInteger = groupIntegerPart(integerPart, groupingSeparator: groupingSeparator)

        if unsigned.contains(".") {
            let fractionPart = parts.count > 1 ? String(parts[1]) : ""
            return sign + groupedInteger + decimalSeparator + fractionPart
        }

        return sign + groupedInteger
    }

    private static func groupIntegerPart(_ integerPart: String, groupingSeparator: String) -> String {
        let digits = integerPart.isEmpty ? "0" : integerPart
        var grouped = ""

        for (index, character) in digits.reversed().enumerated() {
            if index > 0, index.isMultiple(of: 3) {
                grouped = groupingSeparator + grouped
            }
            grouped = String(character) + grouped
        }

        return grouped
    }

    private static func roundedHalfUp(_ value: Decimal, scale: Int) -> Decimal {
        var working = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &working, scale, .plain)
        return rounded
    }
}
