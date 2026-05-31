//
//  BeancountLedgerParser.swift
//  BeancountDriverPlugin
//

import Foundation

struct BeancountLedger: Sendable {
    let transactions: [BeancountTransaction]
    let postings: [BeancountPosting]
    let accounts: [BeancountAccount]
    let prices: [BeancountPrice]
    let balances: [BeancountBalance]
    let commodities: [BeancountCommodity]
    let documents: [BeancountDocument]
    let notes: [BeancountNote]
    let events: [BeancountEvent]
    let pads: [BeancountPad]
    let closes: [BeancountClose]
    let transactionMetadata: [BeancountTransactionMetadata]
    let postingMetadata: [BeancountPostingMetadata]
    let transactionTags: [BeancountTransactionTag]
    let transactionLinks: [BeancountTransactionLink]
    let sourceFiles: [URL]
    let watchedDirectories: [URL]
}

struct BeancountTransaction: Sendable {
    let id: Int
    let date: String
    let flag: String
    let payee: String?
    let narration: String?
    let sourceFile: URL
    let line: Int

    var sourceLocation: String { "\(sourceFile.path):\(line)" }
}

struct BeancountPosting: Sendable {
    let id: Int
    let transactionId: Int
    let date: String
    let account: String
    let amount: String?
    let commodity: String?
    let sourceFile: URL
    let line: Int

    var sourceLocation: String { "\(sourceFile.path):\(line)" }
}

struct BeancountAccount: Sendable {
    let name: String
    let openDate: String
    let currencies: String?
    let sourceFile: URL
    let line: Int

    var sourceLocation: String { "\(sourceFile.path):\(line)" }
}

struct BeancountPrice: Sendable {
    let id: Int
    let date: String
    let commodity: String
    let amount: String
    let currency: String
    let sourceFile: URL
    let line: Int

    var sourceLocation: String { "\(sourceFile.path):\(line)" }
}

struct BeancountBalance: Sendable {
    let id: Int
    let date: String
    let account: String
    let amount: String
    let commodity: String
    let sourceFile: URL
    let line: Int

    var sourceLocation: String { "\(sourceFile.path):\(line)" }
}

struct BeancountCommodity: Sendable {
    let id: Int
    let date: String
    let commodity: String
    let sourceFile: URL
    let line: Int

    var sourceLocation: String { "\(sourceFile.path):\(line)" }
}

struct BeancountDocument: Sendable {
    let id: Int
    let date: String
    let account: String
    let filename: String
    let sourceFile: URL
    let line: Int

    var sourceLocation: String { "\(sourceFile.path):\(line)" }
}

struct BeancountNote: Sendable {
    let id: Int
    let date: String
    let account: String
    let comment: String
    let sourceFile: URL
    let line: Int

    var sourceLocation: String { "\(sourceFile.path):\(line)" }
}

struct BeancountEvent: Sendable {
    let id: Int
    let date: String
    let name: String
    let value: String
    let sourceFile: URL
    let line: Int

    var sourceLocation: String { "\(sourceFile.path):\(line)" }
}

struct BeancountPad: Sendable {
    let id: Int
    let date: String
    let account: String
    let sourceAccount: String
    let sourceFile: URL
    let line: Int

    var sourceLocation: String { "\(sourceFile.path):\(line)" }
}

struct BeancountClose: Sendable {
    let id: Int
    let date: String
    let account: String
    let sourceFile: URL
    let line: Int

    var sourceLocation: String { "\(sourceFile.path):\(line)" }
}

struct BeancountTransactionMetadata: Sendable {
    let id: Int
    let transactionId: Int
    let key: String
    let value: String?
    let sourceFile: URL
    let line: Int

    var sourceLocation: String { "\(sourceFile.path):\(line)" }
}

struct BeancountPostingMetadata: Sendable {
    let id: Int
    let postingId: Int
    let transactionId: Int
    let key: String
    let value: String?
    let sourceFile: URL
    let line: Int

    var sourceLocation: String { "\(sourceFile.path):\(line)" }
}

struct BeancountTransactionTag: Sendable {
    let id: Int
    let transactionId: Int
    let tag: String
}

struct BeancountTransactionLink: Sendable {
    let id: Int
    let transactionId: Int
    let link: String
}

enum BeancountParserError: LocalizedError {
    case includeCycle(String)
    case unreadable(URL, Error)

    var errorDescription: String? {
        switch self {
        case .includeCycle(let path):
            return "Beancount include cycle detected at \(path)"
        case .unreadable(let url, let error):
            return "Could not read \(url.path): \(error.localizedDescription)"
        }
    }
}

final class BeancountLedgerParser {
    private var visited: Set<URL> = []
    private var activeStack: Set<URL> = []
    private var sourceFiles: [URL] = []
    private var transactions: [BeancountTransaction] = []
    private var postings: [BeancountPosting] = []
    private var accountsByName: [String: BeancountAccount] = [:]
    private var prices: [BeancountPrice] = []
    private var balances: [BeancountBalance] = []
    private var commodities: [BeancountCommodity] = []
    private var documents: [BeancountDocument] = []
    private var notes: [BeancountNote] = []
    private var events: [BeancountEvent] = []
    private var pads: [BeancountPad] = []
    private var closes: [BeancountClose] = []
    private var transactionMetadata: [BeancountTransactionMetadata] = []
    private var postingMetadata: [BeancountPostingMetadata] = []
    private var transactionTags: [BeancountTransactionTag] = []
    private var transactionLinks: [BeancountTransactionLink] = []
    private var watchedDirectories: Set<URL> = []
    private var activeTags: Set<String> = []

    func parse(fileURL: URL) throws -> BeancountLedger {
        visited.removeAll()
        activeStack.removeAll()
        sourceFiles.removeAll()
        transactions.removeAll()
        postings.removeAll()
        accountsByName.removeAll()
        prices.removeAll()
        balances.removeAll()
        commodities.removeAll()
        documents.removeAll()
        notes.removeAll()
        events.removeAll()
        pads.removeAll()
        closes.removeAll()
        transactionMetadata.removeAll()
        postingMetadata.removeAll()
        transactionTags.removeAll()
        transactionLinks.removeAll()
        watchedDirectories.removeAll()
        activeTags.removeAll()

        try parseFile(fileURL.standardizedFileURL)

        return BeancountLedger(
            transactions: transactions,
            postings: postings,
            accounts: accountsByName.values.sorted { $0.name < $1.name },
            prices: prices,
            balances: balances,
            commodities: commodities,
            documents: documents,
            notes: notes,
            events: events,
            pads: pads,
            closes: closes,
            transactionMetadata: transactionMetadata,
            postingMetadata: postingMetadata,
            transactionTags: transactionTags,
            transactionLinks: transactionLinks,
            sourceFiles: sourceFiles,
            watchedDirectories: watchedDirectories.sorted { $0.path < $1.path }
        )
    }

    private func parseFile(_ url: URL) throws {
        let normalized = url.standardizedFileURL
        if activeStack.contains(normalized) {
            throw BeancountParserError.includeCycle(normalized.path)
        }
        guard !visited.contains(normalized) else { return }

        activeStack.insert(normalized)
        defer { activeStack.remove(normalized) }

        let contents: String
        do {
            contents = try String(contentsOf: normalized, encoding: .utf8)
        } catch {
            throw BeancountParserError.unreadable(normalized, error)
        }

        visited.insert(normalized)
        sourceFiles.append(normalized)

        let lines = contents.components(separatedBy: .newlines)
        var index = 0
        while index < lines.count {
            let lineNumber = index + 1
            let rawLine = lines[index]
            let trimmed = stripComment(rawLine).trimmingCharacters(in: .whitespaces)
            defer { index += 1 }

            guard !trimmed.isEmpty else { continue }

            if let tag = parseTagStackDirective(trimmed, keyword: "pushtag") {
                activeTags.insert(tag)
                continue
            }
            if let tag = parseTagStackDirective(trimmed, keyword: "poptag") {
                activeTags.remove(tag)
                continue
            }

            if let includePath = parseInclude(trimmed) {
                let includeURLs = try resolveIncludeURLs(
                    includePath,
                    relativeTo: normalized.deletingLastPathComponent()
                )
                for includeURL in includeURLs {
                    try parseFile(includeURL)
                }
                continue
            }

            guard let date = parseDatePrefix(trimmed) else { continue }
            let remainder = String(trimmed.dropFirst(11))

            if remainder.hasPrefix("open ") {
                parseOpen(remainder: remainder, date: date, sourceFile: normalized, line: lineNumber)
            } else if remainder.hasPrefix("price ") {
                parsePrice(remainder: remainder, date: date, sourceFile: normalized, line: lineNumber)
            } else if remainder.hasPrefix("balance ") {
                parseBalance(remainder: remainder, date: date, sourceFile: normalized, line: lineNumber)
            } else if remainder.hasPrefix("commodity ") {
                parseCommodity(remainder: remainder, date: date, sourceFile: normalized, line: lineNumber)
            } else if remainder.hasPrefix("document ") {
                parseDocument(remainder: remainder, date: date, sourceFile: normalized, line: lineNumber)
            } else if remainder.hasPrefix("note ") {
                parseNote(remainder: remainder, date: date, sourceFile: normalized, line: lineNumber)
            } else if remainder.hasPrefix("event ") {
                parseEvent(remainder: remainder, date: date, sourceFile: normalized, line: lineNumber)
            } else if remainder.hasPrefix("pad ") {
                parsePad(remainder: remainder, date: date, sourceFile: normalized, line: lineNumber)
            } else if remainder.hasPrefix("close ") {
                parseClose(remainder: remainder, date: date, sourceFile: normalized, line: lineNumber)
            } else if let flag = remainder.first, flag == "*" || flag == "!" {
                let transactionId = transactions.count + 1
                let transaction = parseTransaction(
                    id: transactionId,
                    remainder: remainder,
                    date: date,
                    sourceFile: normalized,
                    line: lineNumber
                )
                transactions.append(transaction)
                for tag in activeTags.union(parseMarkers(in: remainder, prefix: "#")).sorted() {
                    transactionTags.append(BeancountTransactionTag(
                        id: transactionTags.count + 1,
                        transactionId: transactionId,
                        tag: tag
                    ))
                }
                for link in parseMarkers(in: remainder, prefix: "^") {
                    transactionLinks.append(BeancountTransactionLink(
                        id: transactionLinks.count + 1,
                        transactionId: transactionId,
                        link: link
                    ))
                }

                var postingIndex = index + 1
                var currentPostingId: Int?
                var currentPostingIndent = 0
                while postingIndex < lines.count {
                    let postingLine = lines[postingIndex]
                    guard postingLine.first?.isWhitespace == true else { break }
                    let postingLineNumber = postingIndex + 1
                    let postingIndent = leadingWhitespaceCount(postingLine)
                    let postingTrimmed = stripComment(postingLine).trimmingCharacters(in: .whitespaces)
                    if let metadata = parseMetadata(postingTrimmed) {
                        if let postingId = currentPostingId, postingIndent > currentPostingIndent {
                            postingMetadata.append(BeancountPostingMetadata(
                                id: postingMetadata.count + 1,
                                postingId: postingId,
                                transactionId: transactionId,
                                key: metadata.key,
                                value: metadata.value,
                                sourceFile: normalized,
                                line: postingLineNumber
                            ))
                        } else {
                            transactionMetadata.append(BeancountTransactionMetadata(
                                id: transactionMetadata.count + 1,
                                transactionId: transactionId,
                                key: metadata.key,
                                value: metadata.value,
                                sourceFile: normalized,
                                line: postingLineNumber
                            ))
                            currentPostingId = nil
                            currentPostingIndent = 0
                        }
                    } else if let posting = parsePosting(
                        postingLine,
                        id: postings.count + 1,
                        transactionId: transactionId,
                        date: date,
                        sourceFile: normalized,
                        line: postingLineNumber
                    ) {
                        postings.append(posting)
                        currentPostingId = posting.id
                        currentPostingIndent = postingIndent
                    }
                    postingIndex += 1
                }
                index = postingIndex - 1
            }
        }
    }

    private func parseInclude(_ line: String) -> String? {
        guard line.hasPrefix("include ") else { return nil }
        return quotedStrings(in: line).first
    }

    private func resolveIncludeURLs(_ includePath: String, relativeTo directory: URL) throws -> [URL] {
        guard containsGlobPattern(includePath) else {
            return [resolveIncludeURL(includePath, relativeTo: directory)]
        }

        let patternURL = resolveIncludeURL(includePath, relativeTo: directory)
        let patternPath = patternURL.path
        let searchRoot = globSearchRoot(for: patternPath)
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: searchRoot.path) else {
            watchedDirectories.insert(existingWatchDirectory(for: searchRoot))
            return []
        }
        watchedDirectories.insert(searchRoot)

        let regex = try NSRegularExpression(pattern: globRegex(for: patternPath))
        let enumerator = fileManager.enumerator(
            at: searchRoot,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        var matches: [URL] = []
        while let candidate = enumerator?.nextObject() as? URL {
            let values = try? candidate.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            if values?.isDirectory == true {
                watchedDirectories.insert(candidate.standardizedFileURL)
                continue
            }
            guard values?.isRegularFile == true else { continue }

            let path = candidate.standardizedFileURL.path
            let range = NSRange(location: 0, length: (path as NSString).length)
            if regex.firstMatch(in: path, range: range) != nil {
                matches.append(candidate.standardizedFileURL)
            }
        }

        return matches.sorted { $0.path < $1.path }
    }

    private func resolveIncludeURL(_ includePath: String, relativeTo directory: URL) -> URL {
        if includePath.hasPrefix("/") {
            return URL(fileURLWithPath: includePath).standardizedFileURL
        }
        return directory.appendingPathComponent(includePath).standardizedFileURL
    }

    private func containsGlobPattern(_ path: String) -> Bool {
        path.contains("*") || path.contains("?") || path.contains("[")
    }

    private func globSearchRoot(for patternPath: String) -> URL {
        let components = (patternPath as NSString).pathComponents
        let prefix = components.prefix { !containsGlobPattern($0) }
        let rootPath = NSString.path(withComponents: Array(prefix))
        return URL(fileURLWithPath: rootPath.isEmpty ? "/" : rootPath).standardizedFileURL
    }

    private func existingWatchDirectory(for missingDirectory: URL) -> URL {
        var candidate = missingDirectory.standardizedFileURL
        let fileManager = FileManager.default
        while candidate.path != "/" {
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: candidate.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                return candidate
            }
            candidate.deleteLastPathComponent()
        }
        return URL(fileURLWithPath: "/")
    }

    private func globRegex(for patternPath: String) -> String {
        let characters = Array(patternPath)
        var regex = "^"
        var index = 0

        while index < characters.count {
            let character = characters[index]
            if character == "*" {
                let nextIndex = index + 1
                if nextIndex < characters.count, characters[nextIndex] == "*" {
                    let slashIndex = index + 2
                    if slashIndex < characters.count, characters[slashIndex] == "/" {
                        regex += "(?:.*/)?"
                        index += 3
                    } else {
                        regex += ".*"
                        index += 2
                    }
                } else {
                    regex += "[^/]*"
                    index += 1
                }
            } else if character == "?" {
                regex += "[^/]"
                index += 1
            } else if character == "[" {
                let start = index
                index += 1
                while index < characters.count, characters[index] != "]" {
                    index += 1
                }
                if index < characters.count {
                    regex += String(characters[start...index])
                    index += 1
                } else {
                    regex += NSRegularExpression.escapedPattern(for: String(character))
                }
            } else {
                regex += NSRegularExpression.escapedPattern(for: String(character))
                index += 1
            }
        }

        return regex + "$"
    }

    private func parseOpen(remainder: String, date: String, sourceFile: URL, line: Int) {
        let parts = remainder.split(whereSeparator: \.isWhitespace).map(String.init)
        guard parts.count >= 2 else { return }
        let account = parts[1]
        let currencies = parts.dropFirst(2).joined(separator: " ")
        accountsByName[account] = BeancountAccount(
            name: account,
            openDate: date,
            currencies: currencies.isEmpty ? nil : currencies,
            sourceFile: sourceFile,
            line: line
        )
    }

    private func parsePrice(remainder: String, date: String, sourceFile: URL, line: Int) {
        let parts = remainder.split(whereSeparator: \.isWhitespace).map(String.init)
        guard parts.count >= 4 else { return }
        prices.append(BeancountPrice(
            id: prices.count + 1,
            date: date,
            commodity: parts[1],
            amount: parts[2],
            currency: parts[3],
            sourceFile: sourceFile,
            line: line
        ))
    }

    private func parseBalance(remainder: String, date: String, sourceFile: URL, line: Int) {
        let parts = remainder.split(whereSeparator: \.isWhitespace).map(String.init)
        guard parts.count >= 4 else { return }
        balances.append(BeancountBalance(
            id: balances.count + 1,
            date: date,
            account: parts[1],
            amount: parts[2],
            commodity: parts[3],
            sourceFile: sourceFile,
            line: line
        ))
    }

    private func parseCommodity(remainder: String, date: String, sourceFile: URL, line: Int) {
        let parts = remainder.split(whereSeparator: \.isWhitespace).map(String.init)
        guard parts.count >= 2 else { return }
        commodities.append(BeancountCommodity(
            id: commodities.count + 1,
            date: date,
            commodity: parts[1],
            sourceFile: sourceFile,
            line: line
        ))
    }

    private func parseDocument(remainder: String, date: String, sourceFile: URL, line: Int) {
        let parts = remainder.split(whereSeparator: \.isWhitespace).map(String.init)
        guard parts.count >= 3 else { return }
        let filename = quotedStrings(in: remainder).first ?? parts[2]
        documents.append(BeancountDocument(
            id: documents.count + 1,
            date: date,
            account: parts[1],
            filename: filename,
            sourceFile: sourceFile,
            line: line
        ))
    }

    private func parseNote(remainder: String, date: String, sourceFile: URL, line: Int) {
        let parts = remainder.split(whereSeparator: \.isWhitespace).map(String.init)
        guard parts.count >= 3 else { return }
        let comment = quotedStrings(in: remainder).first ?? parts.dropFirst(2).joined(separator: " ")
        notes.append(BeancountNote(
            id: notes.count + 1,
            date: date,
            account: parts[1],
            comment: comment,
            sourceFile: sourceFile,
            line: line
        ))
    }

    private func parseEvent(remainder: String, date: String, sourceFile: URL, line: Int) {
        let quoted = quotedStrings(in: remainder)
        let parts = remainder.split(whereSeparator: \.isWhitespace).map(String.init)
        guard quoted.count >= 2 || parts.count >= 3 else { return }
        events.append(BeancountEvent(
            id: events.count + 1,
            date: date,
            name: quoted.count >= 2 ? quoted[0] : parts[1],
            value: quoted.count >= 2 ? quoted[1] : parts.dropFirst(2).joined(separator: " "),
            sourceFile: sourceFile,
            line: line
        ))
    }

    private func parsePad(remainder: String, date: String, sourceFile: URL, line: Int) {
        let parts = remainder.split(whereSeparator: \.isWhitespace).map(String.init)
        guard parts.count >= 3 else { return }
        pads.append(BeancountPad(
            id: pads.count + 1,
            date: date,
            account: parts[1],
            sourceAccount: parts[2],
            sourceFile: sourceFile,
            line: line
        ))
    }

    private func parseClose(remainder: String, date: String, sourceFile: URL, line: Int) {
        let parts = remainder.split(whereSeparator: \.isWhitespace).map(String.init)
        guard parts.count >= 2 else { return }
        closes.append(BeancountClose(
            id: closes.count + 1,
            date: date,
            account: parts[1],
            sourceFile: sourceFile,
            line: line
        ))
    }

    private func parseTransaction(
        id: Int,
        remainder: String,
        date: String,
        sourceFile: URL,
        line: Int
    ) -> BeancountTransaction {
        let quoted = quotedStrings(in: remainder)
        return BeancountTransaction(
            id: id,
            date: date,
            flag: String(remainder.prefix(1)),
            payee: quoted.count >= 2 ? quoted[0] : nil,
            narration: quoted.count >= 2 ? quoted[1] : quoted.first,
            sourceFile: sourceFile,
            line: line
        )
    }

    private func parsePosting(
        _ rawLine: String,
        id: Int,
        transactionId: Int,
        date: String,
        sourceFile: URL,
        line: Int
    ) -> BeancountPosting? {
        let trimmed = stripComment(rawLine).trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.hasPrefix(";"), !trimmed.hasPrefix("#") else { return nil }

        let parts = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let account = parts.first, isAccountName(account) else { return nil }
        let amount = parts.count >= 2 ? parts[1] : nil
        let commodity = parts.count >= 3 ? parts[2] : nil

        return BeancountPosting(
            id: id,
            transactionId: transactionId,
            date: date,
            account: account,
            amount: amount,
            commodity: commodity,
            sourceFile: sourceFile,
            line: line
        )
    }

    private func isAccountName(_ value: String) -> Bool {
        guard value.contains(":"), !value.hasSuffix(":") else { return false }
        let components = value.split(separator: ":", omittingEmptySubsequences: false)
        guard components.count >= 2 else { return false }

        let allowedSymbols = CharacterSet(charactersIn: "-_")
        return components.allSatisfy { component in
            guard let first = component.unicodeScalars.first,
                  CharacterSet.uppercaseLetters.contains(first) else {
                return false
            }
            return component.unicodeScalars.allSatisfy { scalar in
                CharacterSet.alphanumerics.contains(scalar) || allowedSymbols.contains(scalar)
            }
        }
    }

    private func parseDatePrefix(_ line: String) -> String? {
        guard line.count >= 11 else { return nil }
        let prefix = String(line.prefix(10))
        let pattern = #"^\d{4}-\d{2}-\d{2}$"#
        guard prefix.range(of: pattern, options: .regularExpression) != nil,
              line.dropFirst(10).first?.isWhitespace == true else {
            return nil
        }
        return prefix
    }

    private func parseMetadata(_ line: String) -> (key: String, value: String?)? {
        guard let firstToken = line.split(whereSeparator: \.isWhitespace).first,
              firstToken.hasSuffix(":") else {
            return nil
        }
        let key = String(firstToken.dropLast())
        let pattern = #"^[A-Za-z][A-Za-z0-9_-]*$"#
        guard key.range(of: pattern, options: .regularExpression) != nil else { return nil }

        let valueStart = line.index(line.startIndex, offsetBy: firstToken.count)
        let rawValue = line[valueStart...].trimmingCharacters(in: .whitespaces)
        guard !rawValue.isEmpty else { return (key, nil) }
        return (key, unquoted(rawValue))
    }

    private func parseTagStackDirective(_ line: String, keyword: String) -> String? {
        guard line.hasPrefix("\(keyword) ") else { return nil }
        return parseMarkers(in: line, prefix: "#").first
    }

    private func parseMarkers(in line: String, prefix: Character) -> [String] {
        let scrubbed = removingQuotedSegments(from: line)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_/."))
        var markers: [String] = []
        var index = scrubbed.startIndex

        while index < scrubbed.endIndex {
            guard scrubbed[index] == prefix else {
                index = scrubbed.index(after: index)
                continue
            }

            var markerIndex = scrubbed.index(after: index)
            var value = ""
            while markerIndex < scrubbed.endIndex {
                let character = scrubbed[markerIndex]
                guard character.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { break }
                value.append(character)
                markerIndex = scrubbed.index(after: markerIndex)
            }
            if !value.isEmpty {
                markers.append(value)
            }
            index = markerIndex
        }

        return markers
    }

    private func removingQuotedSegments(from line: String) -> String {
        var result = ""
        var inQuote = false
        var isEscaped = false

        for character in line {
            if isEscaped {
                isEscaped = false
                continue
            }
            if character == "\\" {
                isEscaped = true
                continue
            }
            if character == "\"" {
                inQuote.toggle()
                continue
            }
            if !inQuote {
                result.append(character)
            }
        }

        return result
    }

    private func unquoted(_ value: String) -> String {
        guard value.count >= 2,
              value.first == "\"",
              value.last == "\"" else {
            return value
        }
        let start = value.index(after: value.startIndex)
        let end = value.index(before: value.endIndex)
        return String(value[start..<end])
    }

    private func leadingWhitespaceCount(_ line: String) -> Int {
        line.prefix { $0.isWhitespace }.count
    }

    private func quotedStrings(in line: String) -> [String] {
        var values: [String] = []
        var current = ""
        var inQuote = false
        var isEscaped = false

        for character in line {
            if isEscaped {
                current.append(character)
                isEscaped = false
                continue
            }
            if character == "\\" {
                isEscaped = true
                continue
            }
            if character == "\"" {
                if inQuote {
                    values.append(current)
                    current = ""
                }
                inQuote.toggle()
                continue
            }
            if inQuote {
                current.append(character)
            }
        }

        return values
    }

    private func stripComment(_ line: String) -> String {
        var inQuote = false
        var isEscaped = false
        var result = ""
        for character in line {
            if isEscaped {
                result.append(character)
                isEscaped = false
                continue
            }
            if character == "\\" {
                result.append(character)
                isEscaped = true
                continue
            }
            if character == "\"" {
                inQuote.toggle()
            }
            if character == ";" && !inQuote {
                break
            }
            result.append(character)
        }
        return result
    }
}
