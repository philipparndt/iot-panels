import SwiftUI

/// Renders a Flux query string with syntax highlighting.
struct FluxSyntaxView: View {
    let code: String
    let fontSize: CGFloat

    init(_ code: String, fontSize: CGFloat = 12) {
        self.code = code
        self.fontSize = fontSize
    }

    var body: some View {
        highlightedText
            .textSelection(.enabled)
    }

    private var highlightedText: Text {
        let tokens = tokenize(code)
        var result = Text(verbatim: "")
        for token in tokens {
            result = Text("\(result)\(Text(token.text).font(.system(size: fontSize, design: .monospaced)).foregroundColor(token.color))")
        }
        return result
    }

    // MARK: - Tokenizer

    private struct Token {
        let text: String
        let color: Color
    }

    private func tokenize(_ source: String) -> [Token] {
        var tokens: [Token] = []
        var remaining = source[...]

        while !remaining.isEmpty {
            if let token = matchString(&remaining) {
                tokens.append(token)
            } else if let token = matchKeyword(&remaining) {
                tokens.append(token)
            } else if let token = matchFunction(&remaining) {
                tokens.append(token)
            } else if let token = matchOperator(&remaining) {
                tokens.append(token)
            } else if let token = matchNumber(&remaining) {
                tokens.append(token)
            } else if let token = matchPipe(&remaining) {
                tokens.append(token)
            } else if let token = matchArrow(&remaining) {
                tokens.append(token)
            } else if let token = matchParen(&remaining) {
                tokens.append(token)
            } else {
                // Default: consume one character
                let ch = String(remaining.prefix(1))
                remaining = remaining.dropFirst()
                tokens.append(Token(text: ch, color: .primary))
            }
        }

        return tokens
    }

    // String literals: "..."
    private func matchString(_ s: inout Substring) -> Token? {
        guard s.first == "\"" else { return nil }
        var i = s.index(after: s.startIndex)
        while i < s.endIndex {
            if s[i] == "\"" {
                let end = s.index(after: i)
                let text = String(s[s.startIndex..<end])
                s = s[end...]
                return Token(text: text, color: .red)
            }
            i = s.index(after: i)
        }
        let text = String(s)
        s = s[s.endIndex...]
        return Token(text: text, color: .red)
    }

    // Flux keywords
    private let keywords: Set<String> = ["from", "import", "true", "false", "or", "and", "not", "if", "then", "else"]

    private func matchKeyword(_ s: inout Substring) -> Token? {
        for kw in keywords {
            if s.hasPrefix(kw) {
                let end = s.index(s.startIndex, offsetBy: kw.count)
                // Ensure it's a whole word
                if end < s.endIndex && (s[end].isLetter || s[end].isNumber || s[end] == "_") { continue }
                let text = String(s[s.startIndex..<end])
                s = s[end...]
                return Token(text: text, color: .purple)
            }
        }
        return nil
    }

    // Function calls: word followed by (
    private let builtinFunctions: Set<String> = [
        "range", "filter", "aggregateWindow", "yield", "limit", "mean", "last",
        "max", "min", "sum", "count", "first", "sort", "group", "keep", "drop",
        "map", "reduce", "pivot", "schema", "measurements", "measurementFieldKeys",
        "measurementTagKeys", "measurementTagValues", "bucket"
    ]

    private func matchFunction(_ s: inout Substring) -> Token? {
        // Match identifier
        guard let first = s.first, first.isLetter || first == "_" else { return nil }
        var i = s.startIndex
        while i < s.endIndex && (s[i].isLetter || s[i].isNumber || s[i] == "_" || s[i] == ".") {
            i = s.index(after: i)
        }
        let word = String(s[s.startIndex..<i])

        // Check if it's followed by ( or is a known function
        let isCall = i < s.endIndex && s[i] == "("
        if isCall || builtinFunctions.contains(word) {
            s = s[i...]
            return Token(text: word, color: .blue)
        }

        // Check if it's a parameter name (followed by :)
        if i < s.endIndex && s[i] == ":" {
            s = s[i...]
            return Token(text: word, color: .teal)
        }

        // Regular identifier
        s = s[i...]
        return Token(text: word, color: .primary)
    }

    // Operators: ==, !=, =>, >=, <=
    private func matchOperator(_ s: inout Substring) -> Token? {
        let ops = ["==", "!=", "=>", ">=", "<=", "="]
        for op in ops {
            if s.hasPrefix(op) {
                let end = s.index(s.startIndex, offsetBy: op.count)
                s = s[end...]
                return Token(text: op, color: .orange)
            }
        }
        return nil
    }

    // Numbers
    private func matchNumber(_ s: inout Substring) -> Token? {
        guard let first = s.first, first.isNumber || (first == "-" && s.count > 1) else { return nil }
        // Check it's not preceded by a letter (would be part of identifier)
        var i = s.startIndex
        if s[i] == "-" { i = s.index(after: i) }
        guard i < s.endIndex && s[i].isNumber else { return nil }
        while i < s.endIndex && (s[i].isNumber || s[i] == "." || s[i].isLetter) {
            i = s.index(after: i)
        }
        let text = String(s[s.startIndex..<i])
        s = s[i...]
        return Token(text: text, color: Color(hex: "#2ECC71"))
    }

    // Pipe: |>
    private func matchPipe(_ s: inout Substring) -> Token? {
        guard s.hasPrefix("|>") else { return nil }
        let end = s.index(s.startIndex, offsetBy: 2)
        s = s[end...]
        return Token(text: "|>", color: .orange)
    }

    // Arrow: =>
    private func matchArrow(_ s: inout Substring) -> Token? {
        guard s.hasPrefix("=>") else { return nil }
        let end = s.index(s.startIndex, offsetBy: 2)
        s = s[end...]
        return Token(text: "=>", color: .orange)
    }

    // Parentheses/brackets
    private func matchParen(_ s: inout Substring) -> Token? {
        guard let ch = s.first, "()[]{}".contains(ch) else { return nil }
        s = s.dropFirst()
        return Token(text: String(ch), color: .secondary)
    }
}
