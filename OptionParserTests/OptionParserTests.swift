// Copyright © 2017 Károly Lőrentey.
// This file is part of OptionParser: https://github.com/lorentey/OptionParser
// For licensing information, see the file LICENSE.md in the Git repository above.

import XCTest
@testable import OptionParser

class OptionParserTests: XCTestCase {
    func checkParser<Record: Equatable>(_ generator: (@escaping (Record) throws -> Void) -> OptionParser<Record>,
                                        _ arguments: [String],
                                        expected: Record,
                                        file: StaticString = #file,
                                        line: UInt = #line) {
        XCTAssertNoThrow(
            try _checkParser(generator,
                             arguments,
                             output: "",
                             file: file,
                             line: line,
                             action: { record in XCTAssertEqual(record, expected, file: file, line: line) }),
            file: file, line: line)
    }

    func checkParser<Record: Equatable>(_ generator: (@escaping (Record) throws -> Void) -> OptionParser<Record>,
                                        _ arguments: [String],
                                        errorMessage: String,
                                        file: StaticString = #file,
                                        line: UInt = #line) {
        XCTAssertThrowsError(
            try _checkParser(generator,
                             arguments,
                             output: "",
                             file: file,
                             line: line,
                             action: { _ in }),
            file: file, line: line) { error in
                switch error {
                case let error as OptionError:
                    XCTAssertEqual(error.message, errorMessage, file: file, line: line)
                default:
                    XCTFail("Unexpected error: \(error)", file: file, line: line)
                }
        }
    }

    func checkParser<Record: Equatable>(_ generator: (@escaping (Record) throws -> Void) -> OptionParser<Record>,
                                        _ arguments: [String],
                                        output: String,
                                        file: StaticString = #file,
                                        line: UInt = #line) {
        XCTAssertNoThrow(
            try _checkParser(generator,
                             arguments,
                             output: output,
                             file: file,
                             line: line,
                             expectedCalls: 0,
                             action: { XCTFail("Unexpected action call with value \($0)", file: file, line: line) }),
            file: file, line: line)
    }


    func _checkParser<Record: Equatable>(_ generator: (@escaping (Record) throws -> Void) -> OptionParser<Record>,
                                         _ arguments: [String],
                                         output: String,
                                         file: StaticString = #file,
                                         line: UInt = #line,
                                         expectedCalls: Int = 1,
                                         action: @escaping (Record) throws -> Void) throws {
        var actionCallCount = 0
        let parser = generator { record in
            actionCallCount += 1
            try action(record)
        }
        var printout = ""
        try parser.parse(arguments: arguments, printer: { string in printout += string + "\n" })
        XCTAssertEqual(printout, output, "Help message mismatch", file: file, line: line)
        XCTAssertEqual(
            actionCallCount, expectedCalls,
            "Action was called \(actionCallCount) times; expected \(expectedCalls) calls",
            file: file, line: line)
    }


    struct TestRecord: Equatable {
        var a: Int
        var b: Bool
        var c: String
        var d: Int?
        var r: [Int]
        var float: Float
        var double: Double

        init(a: Int = 0, b: Bool = false, c: String = "", d: Int? = nil, r: [Int] = [], float: Float = .nan, double: Double = .nan) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
            self.r = r
            self.float = float
            self.double = double
        }

        static func ==(left: TestRecord, right: TestRecord) -> Bool {
            return left.a == right.a
                && left.b == right.b
                && left.c == right.c
                && left.d == right.d
                && left.r == right.r
                && left.float.isTotallyOrdered(belowOrEqualTo: right.float) && right.float.isTotallyOrdered(belowOrEqualTo: left.float)
                && left.double.isTotallyOrdered(belowOrEqualTo: right.double) && right.double.isTotallyOrdered(belowOrEqualTo: left.double)
        }
    }

    func testOptions_Flags() throws {
        let generator: (@escaping (TestRecord) throws -> Void) -> OptionParser<TestRecord> = { action in
            return OptionParser<TestRecord>(
                docs: "Do something with some options.",
                initial: TestRecord(),
                options: [
                    .flag(for: \.a, value: 42, name: "a", docs: "A test flag."),
                    .flag(for: \.b, value: true, name: "b", docs: "Another test flag."),
                    .flag(for: \.b, value: true, name: "a-flag-with-a-really-really-really-extremely-long-name", docs: "Another test flag."),
                    .flag(for: \.c, value: "YES", name: "c", docs: "Yet another test flag.\nThis one is special because its documentation has multiple lines."),
                    ],
                action: action)
        }
        checkParser(generator, ["tool"], expected: TestRecord())
        checkParser(generator, ["tool", "-a"], expected: TestRecord(a: 42))
        checkParser(generator, ["tool", "-b"], expected: TestRecord(b: true))
        checkParser(generator, ["tool", "-c"], expected: TestRecord(c: "YES"))
        checkParser(generator, ["tool", "-c", "-a", "-b"], expected: TestRecord(a: 42, b: true, c: "YES"))
        checkParser(generator, ["tool", "-a", "-a", "-b", "-a"], expected: TestRecord(a: 42, b: true))
        checkParser(generator, ["tool", "-d"], errorMessage: "Unknown option -d")
        checkParser(generator, ["tool", "-a=42"], errorMessage: "Unexpected value '42' for option -a")

        checkParser(generator, ["tool", "--a"], expected: TestRecord(a: 42))
        checkParser(generator, ["tool", "--b"], expected: TestRecord(b: true))
        checkParser(generator, ["tool", "--c"], expected: TestRecord(c: "YES"))

        checkParser(generator, ["tool", "-help"], output: """
            Usage: tool [<option>]...
            Do something with some options.

            Options:
              -a         A test flag.
              -b         Another test flag.
              -a-flag-with-a-really-really-really-extremely-long-name
                         Another test flag.
              -c         Yet another test flag.
                         This one is special because its documentation has multiple lines.
              -help      Print usage information and exit.

            """)
        checkParser(generator, ["tool", "help"], errorMessage: "Unexpected argument 'help'")
    }

    func testOptions_Values() throws {
        let generator: (@escaping (TestRecord) throws -> Void) -> OptionParser<TestRecord> = { action in
            return OptionParser<TestRecord>(
                docs: "Do something with some options.",
                initial: TestRecord(),
                options: [
                    .value(for: \.a, name: "a", metavariable: "<int>", docs: "Integer value."),
                    .value(for: \.b, name: "b", metavariable: "on|off", docs: "Boolean value."),
                    .value(for: \.c, name: "c", metavariable: "<string>", docs: "String value."),
                    .value(for: \.d, name: "d", metavariable: "<int>", docs: "Integer value."),
                    .value(for: \.float, name: "float", metavariable: "<value>", docs: "Float value."),
                    .value(for: \.double, name: "double", metavariable: "<value>", docs: "Double value."),
                    ],
                action: action)
        }
        checkParser(generator, ["tool", "-a"], errorMessage: "Option -a requires a value")
        checkParser(generator, ["tool", "-a=foo"], errorMessage: "Invalid integer value: 'foo'")
        checkParser(generator, ["tool", "-a=1"], expected: TestRecord(a: 1))
        checkParser(generator, ["tool", "-a=1", "-a=2", "-a=3"], expected: TestRecord(a: 3))

        checkParser(generator, ["tool", "--a"], errorMessage: "Option -a requires a value")
        checkParser(generator, ["tool", "--a=1"], expected: TestRecord(a: 1))

        checkParser(generator, ["tool", "-b=on"], expected: TestRecord(b: true))
        checkParser(generator, ["tool", "-b=yes"], expected: TestRecord(b: true))
        checkParser(generator, ["tool", "-b=true"], expected: TestRecord(b: true))
        checkParser(generator, ["tool", "-b=y"], expected: TestRecord(b: true))
        checkParser(generator, ["tool", "-b=1"], expected: TestRecord(b: true))
        checkParser(generator, ["tool", "-b=foo"], errorMessage: "Invalid boolean value: 'foo'")
        checkParser(generator, ["tool", "-b=on", "-b=off"], expected: TestRecord())

        checkParser(generator, ["tool", "-c=1"], expected: TestRecord(c: "1"))
        checkParser(generator, ["tool", "-c=Value"], expected: TestRecord(c: "Value"))
        checkParser(generator, ["tool", "-c= "], expected: TestRecord(c: " "))
        checkParser(generator, ["tool", "-c=-c"], expected: TestRecord(c: "-c"))

        checkParser(generator, ["tool", "-d"], errorMessage: "Option -d requires a value")
        checkParser(generator, ["tool", "-d=34"], expected: TestRecord(d: 34))

        checkParser(generator, ["tool", "-float=0"], expected: TestRecord(float: 0))
        checkParser(generator, ["tool", "-float=-3.25"], expected: TestRecord(float: -3.25))
        checkParser(generator, ["tool", "-float=+4"], expected: TestRecord(float: +4))
        checkParser(generator, ["tool", "-float=+infinity"], expected: TestRecord(float: .infinity))
        checkParser(generator, ["tool", "-float=-infinity"], expected: TestRecord(float: -.infinity))
        checkParser(generator, ["tool", "-float=foo"], errorMessage: "Invalid floating point value: 'foo'")

        checkParser(generator, ["tool", "-double=0"], expected: TestRecord(double: 0))
        checkParser(generator, ["tool", "-double=-3.25"], expected: TestRecord(double: -3.25))
        checkParser(generator, ["tool", "-double=+4"], expected: TestRecord(double: +4))
        checkParser(generator, ["tool", "-double=+infinity"], expected: TestRecord(double: .infinity))
        checkParser(generator, ["tool", "-double=-infinity"], expected: TestRecord(double: -.infinity))
        checkParser(generator, ["tool", "-double=foo"], errorMessage: "Invalid floating point value: 'foo'")


        checkParser(generator, ["tool", "-help"], output: """
            Usage: tool [<option>]...
            Do something with some options.

            Options:
              -a=<int>   Integer value.
              -b=on|off  Boolean value.
              -c=<string>
                         String value.
              -d=<int>   Integer value.
              -float=<value>
                         Float value.
              -double=<value>
                         Double value.
              -help      Print usage information and exit.

            """)
    }

    func testOptions_ValuesWithDefault() throws {
        let generator: (@escaping (TestRecord) throws -> Void) -> OptionParser<TestRecord> = { action in
            return OptionParser<TestRecord>(
                docs: "Do something with some options.",
                initial: TestRecord(),
                options: [
                    .value(for: \.a, default: 100, name: "a", metavariable: "<int>", docs: "Integer value."),
                    .value(for: \.b, default: true, name: "b", metavariable: "on|off", docs: "Boolean value."),
                    .value(for: \.c, default: "default", name: "c", metavariable: "<string>", docs: "String value."),
                    ],
                action: action)
        }
        checkParser(generator, ["tool", "-a"], expected: TestRecord(a: 100))
        checkParser(generator, ["tool", "-a=42"], expected: TestRecord(a: 42))
        checkParser(generator, ["tool", "-a=42", "-a"], expected: TestRecord(a: 100))
        checkParser(generator, ["tool", "-b"], expected: TestRecord(b: true))
        checkParser(generator, ["tool", "-c"], expected: TestRecord(c: "default"))

        checkParser(generator, ["tool", "-a", "-b", "-c"], expected: TestRecord(a: 100, b: true, c: "default"))

        checkParser(generator, ["tool", "--a=42"], expected: TestRecord(a: 42))
        checkParser(generator, ["tool", "--a", "--b", "--c"], expected: TestRecord(a: 100, b: true, c: "default"))

        checkParser(generator, ["tool", "-help"], output: """
            Usage: tool [<option>]...
            Do something with some options.

            Options:
              -a[=<int>] Integer value.
              -b[=on|off]
                         Boolean value.
              -c[=<string>]
                         String value.
              -help      Print usage information and exit.

            """)
    }


    struct TestRecord2: Equatable {
        var a: [Int]
        var b: [Bool]
        var c: [String]
        var d: [Double]

        init(a: [Int] = [], b: [Bool] = [], c: [String] = [], d: [Double] = []) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
        }

        static func ==(left: TestRecord2, right: TestRecord2) -> Bool {
            return left.a == right.a && left.b == right.b && left.c == right.c && left.d == right.d
        }
    }

    func testOptions_Arrays() throws {
        let generator: (@escaping (TestRecord2) throws -> Void) -> OptionParser<TestRecord2> = { action in
            return OptionParser<TestRecord2>(
                docs: "Do something with some options.",
                initial: TestRecord2(),
                options: [
                    .array(for: \.a, syntax: .commaSeparated, name: "a", metavariable: "<int>", docs: "Integer values."),
                    .array(for: \.b, syntax: .upToNextOption, name: "b", metavariable: "on|off", docs: "Boolean values."),
                    .array(for: \.d, syntax: .repeated, name: "d", metavariable: "<int>", docs: "Integer values.")
                    ],
                action: action)
        }
        checkParser(generator, ["tool", "-a"], errorMessage: "Option -a requires a value")
        checkParser(generator, ["tool", "-a", "1"], errorMessage: "Option -a requires a value")
        checkParser(generator, ["tool", "-a="], expected: TestRecord2())
        checkParser(generator, ["tool", "-a=1"], expected: TestRecord2(a: [1]))
        checkParser(generator, ["tool", "-a=1,4,2"], expected: TestRecord2(a: [1, 4, 2]))
        checkParser(generator, ["tool", "-a=1", "-a=4,2"], expected: TestRecord2(a: [1, 4, 2]))

        checkParser(generator, ["tool", "-b=1"], expected: TestRecord2(b: [true]))
        checkParser(generator, ["tool", "-b=1", "-b=off", "-b=yes"],
                    expected: TestRecord2(b: [true, false, true]))
        checkParser(generator, ["tool", "-b", "on", "off", "yes", "1", "0"],
                    expected: TestRecord2(b: [true, false, true, true, false]))
        checkParser(generator, ["tool", "-b", "on", "off", "-a=23,42"],
                    expected: TestRecord2(a: [23, 42], b: [true, false]))
        checkParser(generator, ["tool", "-b", "on", "off", "-b", "off"],
                    expected: TestRecord2(b: [true, false, false]))

        checkParser(generator, ["tool", "-d"], errorMessage: "Option -d requires a value")
        checkParser(generator, ["tool", "-d=1.0"], expected: TestRecord2(d: [1.0]))
        checkParser(generator, ["tool", "-d=1.0", "-d=2"], expected: TestRecord2(d: [1.0, 2.0]))

        checkParser(generator, ["tool", "-help"], output: """
            Usage: tool [<option>]...
            Do something with some options.

            Options:
              -a=<int>,<int>...
                         Integer values.
              -b on|off...
                         Boolean values.
              -d=<int>   Integer values.
              -help      Print usage information and exit.

            """)
    }

    func testOptions_Action() throws {
        let expectation = self.expectation(description: "Action option was called")
        let parser = OptionParser<TestRecord>(
            docs: "Do something with some options.",
            initial: TestRecord(),
            options: [
                .action(name: "action", docs: "Perform an action.") { expectation.fulfill() }
            ],
            action: { record in XCTFail("Default action called with record \(record)") })

        try parser.parse(arguments: ["tool", "-action"])
        waitForExpectations(timeout: 0)

        var printed = ""
        try parser.parse(arguments: ["tool", "-help"], printer: { printed += $0 + "\n" })
        let expected = """
            Usage: tool [<option>]...
            Do something with some options.

            Options:
              -action    Perform an action.
              -help      Print usage information and exit.

            """
        XCTAssertEqual(printed, expected)
    }

    func testParameters_Required() throws {
        let generator: (@escaping (TestRecord) throws -> Void) -> OptionParser<TestRecord> = { action in
            return OptionParser<TestRecord>(
                docs: "Do something with some options.",
                initial: TestRecord(),
                parameters: [
                    .required(for: \.a, metavariable: "A", docs: "First parameter."),
                    .required(for: \.b, metavariable: "B", docs: "Second parameter."),
                    .required(for: \.c, metavariable: "C", docs: "Third parameter."),
                ],
                action: action)
        }
        checkParser(generator, ["tool"], errorMessage: "Missing argument for A")
        checkParser(generator, ["tool", "42"], errorMessage: "Missing argument for B")
        checkParser(generator, ["tool", "42", "on"], errorMessage: "Missing argument for C")
        checkParser(generator, ["tool", "42", "on", "string"], expected: TestRecord(a: 42, b: true, c: "string"))
        checkParser(generator, ["tool", "42", "on", "string", "extra"], errorMessage: "Unexpected argument 'extra'")

        checkParser(generator, ["tool", "-help"], output: """
            Usage: tool [<option>]... A B C
            Do something with some options.

            Options:
              -help      Print usage information and exit.

            Positional parameters:
              A          First parameter.
              B          Second parameter.
              C          Third parameter.

            """)
    }

    func testParameters_Optional() throws {
        let generator: (@escaping (TestRecord) throws -> Void) -> OptionParser<TestRecord> = { action in
            return OptionParser<TestRecord>(
                docs: "Do something with some options.",
                initial: TestRecord(),
                parameters: [
                    .required(for: \.a, metavariable: "A", docs: "First parameter."),
                    .optional(for: \.b, metavariable: "B", docs: "Second parameter."),
                    .required(for: \.c, metavariable: "C", docs: "Third parameter."),
                    .optional(for: \.d, metavariable: "D", docs: "Fourth parameter."),
                    ],
                action: action)
        }
        checkParser(generator, ["tool"], errorMessage: "Missing argument for A")
        checkParser(generator, ["tool", "42"], errorMessage: "Missing argument for C")
        checkParser(generator, ["tool", "42", "string"], expected: TestRecord(a: 42, c: "string"))
        checkParser(generator, ["tool", "42", "on", "string"], expected: TestRecord(a: 42, b: true, c: "string"))
        checkParser(generator, ["tool", "42", "on", "string", "23"], expected: TestRecord(a: 42, b: true, c: "string", d: 23))
        checkParser(generator, ["tool", "42", "on", "string", "23", "extra"], errorMessage: "Unexpected argument 'extra'")

        checkParser(generator, ["tool", "-help"], output: """
            Usage: tool [<option>]... A [B] C [D]
            Do something with some options.

            Options:
              -help      Print usage information and exit.

            Positional parameters:
              A          First parameter.
              [B]        Second parameter.
              C          Third parameter.
              [D]        Fourth parameter.

            """)
    }

    func testParameters_Repeating() throws {
        let generator: (@escaping (TestRecord) throws -> Void) -> OptionParser<TestRecord> = { action in
            return OptionParser<TestRecord>(
                docs: "Do something with some options.",
                initial: TestRecord(),
                parameters: [
                    .required(for: \.a, metavariable: "A", docs: "First required parameter."),
                    .optional(for: \.b, metavariable: "B", docs: "First optional parameter."),
                    .repeating(for: \.r, metavariable: "R", docs: "Repeating parameter."),
                    .required(for: \.c, metavariable: "C", docs: "Second required parameter."),
                    .optional(for: \.d, metavariable: "D", docs: "Second optional parameter."),
                    ],
                action: action)
        }
        checkParser(generator, ["tool"], errorMessage: "Missing argument for A")
        checkParser(generator, ["tool", "42"], errorMessage: "Missing argument for C")
        checkParser(generator, ["tool", "42", "string"], expected: TestRecord(a: 42, c: "string"))
        checkParser(generator, ["tool", "42", "on", "string"], expected: TestRecord(a: 42, b: true, c: "string"))
        checkParser(generator, ["tool", "42", "on", "string", "23"], expected: TestRecord(a: 42, b: true, c: "string", d: 23))
        checkParser(generator, ["tool", "42", "on", "1", "string", "23"], expected: TestRecord(a: 42, b: true, c: "string", d: 23, r: [1]))
        checkParser(generator, ["tool", "42", "on", "1", "2", "3", "string", "23"],
                    expected: TestRecord(a: 42, b: true, c: "string", d: 23, r: [1, 2, 3]))

        checkParser(generator, ["tool", "-help"], output: """
            Usage: tool [<option>]... A [B] [R]... C [D]
            Do something with some options.

            Options:
              -help      Print usage information and exit.

            Positional parameters:
              A          First required parameter.
              [B]        First optional parameter.
              [R]...     Repeating parameter.
              C          Second required parameter.
              [D]        Second optional parameter.

            """)
    }

    func testCommands() throws {
        enum Format: String, OptionValue, Equatable {
            case text
            case json
        }

        struct GlobalOptions {
            var format: Format = .text
        }

        struct ListOptions {
            var global: GlobalOptions
            init(_ global: GlobalOptions) { self.global = global }
        }

        struct RunOptions {
            var global: GlobalOptions
            var florbs: [String] = []
            var zarcks: [Int] = []
            init(_ global: GlobalOptions, florbs: [String] = [], zarcks: [Int] = []) {
                self.global = global
                self.florbs = florbs
                self.zarcks = zarcks
            }
        }
        enum Info {
            case defaultAction(GlobalOptions)
            case version
            case list(ListOptions)
            case run(RunOptions)
        }

        var info: Info? = nil

        let parser = OptionParser<GlobalOptions>(
            docs: "Handle florbs, with support for zarcks.",
            initial: GlobalOptions(),
            options: [
                .value(for: \.format, name: "format", metavariable: "text|json", docs: "Output format. (Default: text)"),
                .action(name: "version", docs: "Print version information and exit.", action: { XCTAssertNil(info); info = .version })
            ],
            commands: [
            .command(for: ListOptions.self,
                     name: "list", docs: "List available florbs.",
                     initial: { ListOptions($0) },
                     options: [],
                     parameters: [],
                     action: { record -> Void in
                        XCTAssertNil(info)
                        info = .list(record)
                }),
            .command(for: RunOptions.self,
                     name: "run", docs: "Run selected florbs on some specific zarcks.",
                     initial: { RunOptions($0) },
                     options: [
                        .array(for: \.florbs, syntax: .upToNextOption,
                               name: "florbs", metavariable: "<name>", docs: "The florbs to run (default: all)")
                ],
                     parameters: [
                        .repeating(for: \.zarcks, metavariable: "<zarck>", docs: "The zarks on which to run the selected florbs.")
                ],
                     action: { record -> Void in
                        XCTAssertNil(info)
                        info = .run(record)
            })
            ],
            defaultAction: { record in
                XCTAssertNil(info)
                info = .defaultAction(record)
        })

        func check(_ arguments: [String], _ value: Info, file: StaticString = #file, line: UInt = #line) throws {
            info = nil
            try parser.parse(arguments: arguments)
            guard let i = info else { XCTFail("No action called", file: file, line: line); return }
            switch (i, value) {
            case let (.defaultAction(a), .defaultAction(b)):
                XCTAssertEqual(a.format, b.format, "Expected \(value), got \(i)", file: file, line: line)
            case (.version, .version):
                break
            case let (.list(a), .list(b)):
                XCTAssertEqual(a.global.format, b.global.format, "Expected \(value), got \(i)", file: file, line: line)
            case let (.run(a), .run(b)):
                XCTAssertEqual(a.global.format, b.global.format, "Expected \(value), got \(i)", file: file, line: line)
                XCTAssertEqual(a.florbs, b.florbs, "Expected \(value), got \(i)", file: file, line: line)
                XCTAssertEqual(a.zarcks, b.zarcks, "Expected \(value), got \(i)", file: file, line: line)
            default:
                XCTFail("Expected \(value), got \(i)", file: file, line: line)
            }
        }

        func checkError(_ arguments: [String], _ message: String, file: StaticString = #file, line: UInt = #line) {
            info = nil
            XCTAssertThrowsError(try parser.parse(arguments: arguments)) { error in
                switch error {
                case let error as OptionError:
                    XCTAssertEqual(error.message, message, file: file, line: line)
                default:
                    XCTFail("Unexpected error \(error)", file: file, line: line)
                }
            }
        }

        func checkHelp(_ arguments: [String], _ output: String, file: StaticString = #file, line: UInt = #line) throws {
            info = nil
            var printed = ""
            try parser.parse(arguments: arguments, printer: { printed += $0 + "\n" })
            XCTAssertNil(info, file: file, line: line)
            XCTAssertEqual(printed, output, file: file, line: line)
        }

        try check(["test"], .defaultAction(GlobalOptions()))
        try check(["test", "-version"], .version)
        try check(["test", "-format=json"], .defaultAction(GlobalOptions(format: .json)))
        checkError(["test", "-format=foo"], "Invalid value: 'foo'")
        try check(["test", "list"], .list(ListOptions(GlobalOptions(format: .text))))
        try check(["test", "-format=json", "list"], .list(ListOptions(GlobalOptions(format: .json))))
        try check(["test", "run"], .run(RunOptions(GlobalOptions())))
        try check(["test", "-format=json", "run"], .run(RunOptions(GlobalOptions(format: .json))))
        try check(["test", "run", "--florbs", "aa", "bbb"], .run(RunOptions(GlobalOptions(), florbs: ["aa", "bbb"])))
        try check(["test", "run", "3", "42", "0", "100"], .run(RunOptions(GlobalOptions(), zarcks: [3, 42, 0, 100])))
        try check(["test", "run", "--florbs", "aa", "bbb", "--", "1", "3", "2", "-100"],
                  .run(RunOptions(GlobalOptions(), florbs: ["aa", "bbb"], zarcks: [1, 3, 2, -100])))

        let generalHelp = """
            Usage: test [<option>]... <command> [<arg>]...
            Handle florbs, with support for zarcks.

            Options:
              -format=text|json
                         Output format. (Default: text)
              -version   Print version information and exit.
              -help      Print usage information and exit.

            Commands:
              list       List available florbs.
              run        Run selected florbs on some specific zarcks.
              help       Print help about a particular command.

            """
        try checkHelp(["test", "--help"], generalHelp)
        try checkHelp(["test", "help"], generalHelp)

        let runHelp = """
            Usage: test run [<option>]... [<zarck>]...
            Run selected florbs on some specific zarcks.

            Options:
              -florbs <name>...
                         The florbs to run (default: all)
              -help      Print usage information and exit.

            Positional parameters:
              [<zarck>]...
                         The zarks on which to run the selected florbs.

            """
        try checkHelp(["test", "help", "run"], runHelp)
        try checkHelp(["test", "run", "-help"], runHelp)

        let listHelp = """
            Usage: test list [<option>]...
            List available florbs.

            Options:
              -help      Print usage information and exit.

            """
        try checkHelp(["test", "help", "list"], listHelp)
        try checkHelp(["test", "list", "-help"], listHelp)

        let helpHelp = """
            Usage: test help [<option>]... [<command>]
            Print help about a particular command.

            Options:
              -help      Print usage information and exit.

            Positional parameters:
              [<command>]
                         The command to describe. If not given, prints general usage information.

            """
        try checkHelp(["test", "help", "help"], helpHelp)
        try checkHelp(["test", "help", "-help"], helpHelp)
        XCTAssertThrowsError(try checkHelp(["test", "help", "foo"], helpHelp))
    }

}
