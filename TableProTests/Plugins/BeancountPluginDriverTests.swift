//
//  BeancountPluginDriverTests.swift
//  TableProTests
//

import Foundation
import TableProPluginKit
import Testing

@Suite("Beancount plugin driver", .serialized)
struct BeancountPluginDriverTests {
    @Test("reloads the SQL projection when an included ledger file changes")
    func reloadsWhenIncludedFileChanges() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("beancount-driver-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        let included = tempDirectory.appendingPathComponent("accounts.beancount")
        try """
        2024-01-01 open Assets:Bank:Checking USD
        """.write(to: included, atomically: true, encoding: .utf8)

        let ledger = tempDirectory.appendingPathComponent("main.beancount")
        try """
        include "accounts.beancount"
        """.write(to: ledger, atomically: true, encoding: .utf8)

        let driver = BeancountPluginDriver(config: DriverConnectionConfig(
            host: "",
            port: 0,
            username: "",
            password: "",
            database: ledger.path
        ))
        try await driver.connect()
        defer {
            driver.disconnect()
        }

        var result = try await driver.execute(query: "SELECT name FROM accounts ORDER BY name")
        #expect(result.rows.map { $0[0].asText } == ["Assets:Bank:Checking"])

        try """
        2024-01-01 open Assets:Bank:Checking USD
        2024-01-02 open Expenses:Food USD
        """.write(to: included, atomically: true, encoding: .utf8)

        result = try await driver.execute(query: "SELECT name FROM accounts ORDER BY name")
        #expect(result.rows.map { $0[0].asText } == ["Assets:Bank:Checking", "Expenses:Food"])
    }

    @Test("reloads the SQL projection when a glob include matches a new file")
    func reloadsWhenGlobIncludeMatchesNewFile() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("beancount-driver-glob-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        let imports = tempDirectory.appendingPathComponent("imports", isDirectory: true)
        try FileManager.default.createDirectory(at: imports, withIntermediateDirectories: true)
        try """
        2024-01-01 open Assets:Bank:Checking USD
        """.write(to: imports.appendingPathComponent("accounts.beancount"), atomically: true, encoding: .utf8)

        let ledger = tempDirectory.appendingPathComponent("main.beancount")
        try """
        include "imports/*.beancount"
        """.write(to: ledger, atomically: true, encoding: .utf8)

        let driver = BeancountPluginDriver(config: DriverConnectionConfig(
            host: "",
            port: 0,
            username: "",
            password: "",
            database: ledger.path
        ))
        try await driver.connect()
        defer {
            driver.disconnect()
        }

        var result = try await driver.execute(query: "SELECT name FROM accounts ORDER BY name")
        #expect(result.rows.map { $0[0].asText } == ["Assets:Bank:Checking"])

        try """
        2024-01-02 open Expenses:Food USD
        """.write(to: imports.appendingPathComponent("expenses.beancount"), atomically: true, encoding: .utf8)

        result = try await driver.execute(query: "SELECT name FROM accounts ORDER BY name")
        #expect(result.rows.map { $0[0].asText } == ["Assets:Bank:Checking", "Expenses:Food"])
    }

    @Test("rejects write queries")
    func rejectsWriteQueries() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("beancount-driver-read-only-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        let ledger = tempDirectory.appendingPathComponent("main.beancount")
        try """
        2024-01-01 open Assets:Bank:Checking USD
        """.write(to: ledger, atomically: true, encoding: .utf8)

        let driver = BeancountPluginDriver(config: DriverConnectionConfig(
            host: "",
            port: 0,
            username: "",
            password: "",
            database: ledger.path
        ))
        try await driver.connect()
        defer {
            driver.disconnect()
        }

        await #expect(throws: BeancountDriverError.self) {
            _ = try await driver.execute(query: "DELETE FROM accounts")
        }
    }

    @Test("projects rich directives and source locations into SQL tables")
    func projectsRichDirectiveTablesAndSourceLocations() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("beancount-driver-rich-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        let ledger = tempDirectory.appendingPathComponent("main.beancount")
        try """
        2024-01-01 commodity USD
        2024-01-02 open Assets:Bank:Checking USD
        2024-01-03 close Liabilities:CreditCard
        2024-01-04 pad Assets:Bank:Checking Equity:Opening-Balances
        2024-01-05 document Assets:Bank:Checking "receipts/january.pdf"
        2024-01-06 note Assets:Bank:Checking "Opened checking account"
        2024-01-07 event "location" "Vancouver"

        2024-01-15 * "Grocery Store" "Weekly shop" #tax ^invoice-123
          receipt: "receipt-123.pdf"
          Assets:Bank:Checking  -100.00 USD
            statement_line: "42"
          Expenses:Food          100.00 USD
        """.write(to: ledger, atomically: true, encoding: .utf8)

        let driver = BeancountPluginDriver(config: DriverConnectionConfig(
            host: "",
            port: 0,
            username: "",
            password: "",
            database: ledger.path
        ))
        try await driver.connect()
        defer {
            driver.disconnect()
        }

        let tables = try await driver.fetchTables(schema: nil)
        #expect(tables.map(\.name).contains("commodities"))
        #expect(tables.map(\.name).contains("documents"))
        #expect(tables.map(\.name).contains("notes"))
        #expect(tables.map(\.name).contains("events"))
        #expect(tables.map(\.name).contains("pads"))
        #expect(tables.map(\.name).contains("closes"))
        #expect(tables.map(\.name).contains("transaction_metadata"))
        #expect(tables.map(\.name).contains("posting_metadata"))
        #expect(tables.map(\.name).contains("transaction_tags"))
        #expect(tables.map(\.name).contains("transaction_links"))
        #expect(tables.map(\.name).contains("diagnostics"))

        var result = try await driver.execute(query: "SELECT commodity, source_location FROM commodities")
        #expect(result.rows.first?[0].asText == "USD")
        #expect(result.rows.first?[1].asText?.hasSuffix("main.beancount:1") == true)

        result = try await driver.execute(query: "SELECT account, filename FROM documents")
        #expect(result.rows.first?.map(\.asText) == ["Assets:Bank:Checking", "receipts/january.pdf"])

        result = try await driver.execute(query: "SELECT key, value FROM transaction_metadata")
        #expect(result.rows.first?.map(\.asText) == ["receipt", "receipt-123.pdf"])

        result = try await driver.execute(query: "SELECT tag FROM transaction_tags")
        #expect(result.rows.map { $0[0].asText } == ["tax"])

        result = try await driver.execute(query: "SELECT link FROM transaction_links")
        #expect(result.rows.map { $0[0].asText } == ["invoice-123"])

        result = try await driver.execute(query: "SELECT key, value FROM posting_metadata")
        #expect(result.rows.first?.map(\.asText) == ["statement_line", "42"])
    }

    @Test("projects rustledger validation diagnostics")
    func projectsRustledgerValidationDiagnostics() async throws {
        let rustledger = try #require(Self.bundledRustledgerPath() ?? Self.installedRustledgerPath())
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("beancount-driver-diagnostics-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer {
            unsetenv("TABLEPRO_RUSTLEDGER_BINARY")
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        let ledger = tempDirectory.appendingPathComponent("main.beancount")
        try """
        2024-01-01 open Assets:Bank:Checking USD

        2024-01-02 * "Broken" "Unbalanced"
          Assets:Bank:Checking  -10.00 USD
          Expenses:Food          15.00 USD
        """.write(to: ledger, atomically: true, encoding: .utf8)

        setenv("TABLEPRO_RUSTLEDGER_BINARY", rustledger, 1)

        let driver = BeancountPluginDriver(config: DriverConnectionConfig(
            host: "",
            port: 0,
            username: "",
            password: "",
            database: ledger.path
        ))
        try await driver.connect()
        defer {
            driver.disconnect()
        }

        let result = try await driver.execute(query: """
            SELECT code, severity, line, source_location, message
            FROM diagnostics
            ORDER BY code
            """)

        #expect(result.rows.map { $0[0].asText } == ["E1001", "E3001"])
        #expect(result.rows.allSatisfy { $0[1].asText == "error" })
        #expect(result.rows.allSatisfy { $0[2].asText == "3" })
        #expect(result.rows.allSatisfy { $0[3].asText?.hasSuffix("main.beancount:3") == true })
        #expect(result.rows.map { $0[4].asText ?? "" }.contains { $0.contains("never opened") })
        #expect(result.rows.map { $0[4].asText ?? "" }.contains { $0.contains("does not balance") })
    }

    @Test("executes BQL queries through the rustledger helper")
    func executesBQLQueriesThroughRustledgerHelper() async throws {
        let rustledger = try #require(Self.bundledRustledgerPath() ?? Self.installedRustledgerPath())
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("beancount-driver-bql-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer {
            unsetenv("TABLEPRO_RUSTLEDGER_BINARY")
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        let ledger = tempDirectory.appendingPathComponent("main.beancount")
        try """
        2024-01-01 open Assets:Bank:Checking USD
        2024-01-01 open Expenses:Food USD
        2024-01-01 open Income:Salary USD
        """.write(to: ledger, atomically: true, encoding: .utf8)

        setenv("TABLEPRO_RUSTLEDGER_BINARY", rustledger, 1)

        let driver = BeancountPluginDriver(config: DriverConnectionConfig(
            host: "",
            port: 0,
            username: "",
            password: "",
            database: ledger.path
        ))
        try await driver.connect()
        defer {
            driver.disconnect()
        }

        let result = try await driver.execute(query: "BQL: SELECT account FROM accounts ORDER BY account")

        #expect(result.columns == ["account"])
        #expect(result.rows.map { $0.first?.asText } == [
            "Assets:Bank:Checking",
            "Expenses:Food",
            "Income:Salary"
        ])

        let count = try await driver.fetchRowCount(query: "BQL: SELECT account FROM accounts ORDER BY account")
        #expect(count == 3)

        let page = try await driver.fetchRows(
            query: "BQL: SELECT account FROM accounts ORDER BY account",
            offset: 1,
            limit: 1
        )
        #expect(page.rows.map { $0.first?.asText } == ["Expenses:Food"])
    }

    private static func installedRustledgerPath() -> String? {
        let candidates = [
            ProcessInfo.processInfo.environment["TABLEPRO_RUSTLEDGER_BINARY"],
            "/opt/homebrew/bin/rledger",
            "/usr/local/bin/rledger"
        ].compactMap { $0 }

        return candidates.first { path in
            FileManager.default.isExecutableFile(atPath: path)
        }
    }

    private static func bundledRustledgerPath() -> String? {
        guard let path = Bundle.main.builtInPlugInsURL?
            .appendingPathComponent("BeancountDriver.tableplugin")
            .appendingPathComponent("Contents/Resources/rledger")
            .path else {
            return nil
        }

        return FileManager.default.isExecutableFile(atPath: path) ? path : nil
    }
}
