// Copyright © 2017 Károly Lőrentey.
// This file is part of OptionParser: https://github.com/lorentey/OptionParser
// For licensing information, see the file LICENSE.md in the Git repository above.

public struct OptionError: Error, CustomStringConvertible {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var description: String { return message }
}

public struct OptionParser<Record> {
    let syntax: Syntax<Void, Record>
    let action: ((Record) throws -> Void)?

    public init(docs: String,
                initial: Record,
                options: [Option] = [],
                commands: [AnyCommand],
                defaultAction: @escaping (Record) throws -> Void) {
        self.init(_docs: docs,
                  initial: initial,
                  options: options,
                  commands: commands,
                  action: defaultAction)
    }

    public init(docs: String,
                initial: Record,
                options: [Option] = [],
                commands: [AnyCommand]) {
        self.init(_docs: docs,
                  initial: initial,
                  options: options,
                  commands: commands,
                  action: nil)
    }

    public init(docs: String,
                initial: Record,
                options: [Option] = [],
                parameters: [Parameter] = [],
                action: @escaping (Record) throws -> Void) {
        self.init(_docs: docs,
                  initial: initial,
                  options: options,
                  parameters: parameters,
                  action: action)
    }

    init(_docs docs: String,
         initial: Record,
         options: [Option] = [],
         parameters: [Parameter] = [],
         commands: [AnyCommand] = [],
         action: ((Record) throws -> Void)?) {

        self.syntax = Syntax<Void, Record>(docs: docs,
                                           initial: initial,
                                           options: options,
                                           parameters: parameters,
                                           commands: commands)
        self.action = action
    }

    func parse(arguments: [String], printer: @escaping (String) throws -> Void) throws {
        var context = ParseContext(arguments, printer: printer)
        try syntax.parse(from: &context, parentRecord: (), action: self.action)
    }

    public func parse(arguments: [String] = CommandLine.arguments) throws {
        try self.parse(arguments: arguments, printer: { Swift.print($0) })
    }
}

