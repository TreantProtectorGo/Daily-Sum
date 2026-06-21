import Foundation

enum CSVField: Equatable {
    case raw(String)
    case text(String)
}

enum CSVEncodingError: Error, Equatable {
    case fieldCountMismatch(expected: Int, actual: Int)
}

struct CSVEncoder {
    private static let utf8BOM = Data([0xEF, 0xBB, 0xBF])
    private static let formulaPrefixes: Set<Character> = ["=", "+", "-", "@"]

    func encode(headers: [String], rows: [[CSVField]]) throws -> Data {
        var output = Self.utf8BOM
        let headerLine = headers.map(escape).joined(separator: ",")
        output.append(Data("\(headerLine)\r\n".utf8))

        for row in rows {
            guard row.count == headers.count else {
                throw CSVEncodingError.fieldCountMismatch(
                    expected: headers.count,
                    actual: row.count
                )
            }

            let line = row.map(encodedValue).joined(separator: ",")
            output.append(Data("\(line)\r\n".utf8))
        }

        return output
    }

    private func encodedValue(_ field: CSVField) -> String {
        switch field {
        case let .raw(value):
            return escape(value)
        case let .text(value):
            return escape(protectedText(value))
        }
    }

    private func protectedText(_ value: String) -> String {
        guard let first = value.first, Self.formulaPrefixes.contains(first) else {
            return value
        }
        return "'\(value)"
    }

    private func escape(_ value: String) -> String {
        guard value.contains(",")
                || value.contains("\"")
                || value.contains("\r")
                || value.contains("\n")
        else {
            return value
        }

        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
