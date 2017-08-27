// Copyright © 2017 Károly Lőrentey.
// This file is part of OptionParser: https://github.com/lorentey/OptionParser
// For licensing information, see the file LICENSE.md in the Git repository above.

import Foundation

private struct HelpCommandOptions {
    var command: String?
}

extension OptionParser {
    public class AnyCommand {
        let name: String
        let docs: String

        init(name: String, docs: String) {
            self.name = name
            self.docs = docs
        }

        func parse(from context: inout ParseContext, _ parentRecord: Record) throws {
            fatalError("Unimplemented abstract method")
        }

        func printHelp(toolName: String, printer: (String) throws -> Void) throws {
            fatalError("Unimplemented abstract method")
        }

        public static func command<Subrecord>(for type: Subrecord.Type = Subrecord.self,
                                           name: String, docs: String,
                                           initial: @escaping (Record) throws -> Subrecord,
                                           options: [OptionParser<Subrecord>.Option] = [],
                                           parameters: [OptionParser<Subrecord>.Parameter] = [],
                                           action: @escaping (Subrecord) throws -> Void) -> AnyCommand {
            return Command<Subrecord>(name: name, docs: docs,
                                            initial: initial, options: options, parameters: parameters, action: action)
        }
    }

    class Command<Subrecord>: AnyCommand {
        public typealias Option = OptionParser<Subrecord>.Option
        public typealias Parameter = OptionParser<Subrecord>.Parameter

        let syntax: Syntax<Record, Subrecord>
        let action: (Subrecord) throws -> Void

        init(name: String, docs: String, syntax: Syntax<Record, Subrecord>, action: @escaping (Subrecord) throws -> Void) {
            self.syntax = syntax
            self.action = action
            super.init(name: name, docs: docs)
        }

        public convenience init(name: String, docs: String,
                                initial: @escaping (Record) throws -> Subrecord,
                                options: [Option] = [],
                                parameters: [Parameter] = [],
                                action: @escaping (Subrecord) throws -> Void) {
            let syntax = Syntax<Record, Subrecord>(
                name: name,
                docs: docs,
                initial: initial,
                options: options,
                parameters: parameters)
            self.init(name: name, docs: docs, syntax: syntax, action: action)
        }

        override func parse(from context: inout ParseContext, _ parentRecord: Record) throws {
            try syntax.parse(from: &context, parentRecord: parentRecord, action: action)
        }

        override func printHelp(toolName: String, printer: (String) throws -> Void) throws {
            try syntax.printHelp(toolName: toolName, printer: printer)
        }
    }

    class HelpCommand: AnyCommand {
        private let syntax: Syntax<Record, HelpCommandOptions>
        weak var parentSyntax: Syntax<Void, Record>?

        init() {
            let docs = "Print help about a particular command."
            self.syntax = Syntax<Record, HelpCommandOptions>(
                name: "help",
                docs: docs,
                initial: { _ in HelpCommandOptions() },
                parameters: [
                    .optional(for: \.command, metavariable: "<command>",
                              docs: "The command to describe. If not given, prints general usage information."),
                    ])
            super.init(name: "help", docs: docs)
        }

        override func parse(from context: inout ParseContext, _ parentRecord: Record) throws {
            let toolName = context.toolName
            let printer = context.printer
            try syntax.parse(from: &context, parentRecord: parentRecord) { record in
                if let commandName = record.command {
                    guard let command = self.parentSyntax!.commandsByName[commandName] else {
                        throw OptionError("Unknown command '\(commandName)'")
                    }
                    try command.printHelp(toolName: toolName, printer: printer)
                }
                else {
                    try self.parentSyntax!.printHelp(toolName: toolName, printer: printer)
                }
            }
        }

        override func printHelp(toolName: String, printer: (String) throws -> Void) throws {
            try syntax.printHelp(toolName: toolName, printer: printer)
        }
    }
}
