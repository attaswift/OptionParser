// Copyright © 2017 Károly Lőrentey.
// This file is part of OptionParser: https://github.com/lorentey/OptionParser
// For licensing information, see the file LICENSE.md in the Git repository above.

final class Syntax<Record, Subrecord> {
    public typealias Option = OptionParser<Subrecord>.Option
    public typealias Parameter = OptionParser<Subrecord>.Parameter
    public typealias AnyCommand = OptionParser<Subrecord>.AnyCommand
    public typealias Command<R> = OptionParser<Record>.Command<R>

    let name: String?
    let docs: String

    let initial: (Record) throws -> Subrecord

    let options: [Option]
    let optionsByName: [String: Option]

    let commands: [AnyCommand]
    let commandsByName: [String: AnyCommand]

    let parameters: [Parameter]

    fileprivate init(
        name: String?,
        docs: String,
        initial: @escaping (Record) throws -> Subrecord,
        options: [Option],
        parameters: [Parameter],
        commands: [AnyCommand]) {
        precondition(parameters.isEmpty || commands.isEmpty)

        self.name = name
        self.docs = docs

        self.initial = initial

        var options = options
        if options.index(where: { $0.name == "help" }) == nil {
            options.append(.help())
        }
        self.options = options
        self.optionsByName = [String: Option](uniqueKeysWithValues: options.map { ($0.name, $0) })

        self.commands = commands
        self.commandsByName = [String: AnyCommand](uniqueKeysWithValues: commands.map { ($0.name, $0) })

        self.parameters = parameters
    }

    convenience init(name: String?,
                     docs: String,
                     initial: @escaping (Record) throws -> Subrecord,
                     options: [Option] = [],
                     parameters: [Parameter] = []) {
        self.init(name: name, docs: docs, initial: initial, options: options, parameters: parameters, commands: [])
    }

    func parse(from context: inout ParseContext, parentRecord: Record, action: ((Subrecord) throws -> Void)?) throws {
        var record = try initial(parentRecord)
        var arguments: [String] = []
        var parametersOnly = false
        while !context.isAtEnd {
            let argument = context.accept()
            switch argument.kind {
            case let .option(name, value) where !parametersOnly:
                guard name != "-" else {
                    parametersOnly = true
                    continue
                }
                guard let option = optionsByName[name] else {
                    throw OptionError("Unknown option \(argument.value)")
                }
                switch option.kind {
                case .option(let parse):
                    try parse(value, &context, &record)
                case .action(let action):
                    try action()
                    return
                case .help:
                    try self.printHelp(toolName: context.toolName, printer: context.printer)
                    return
                }
            default:
                if arguments.isEmpty, let command = commandsByName[argument.value] {
                    try command.parse(from: &context, record)
                    return
                }
                else {
                    arguments.append(argument.value)
                }
            }
        }
        try parsePositionalArguments(arguments, record: &record)
        if let action = action {
            try action(record)
        }
        else {
            try self.printHelp(toolName: context.toolName, printer: context.printer)
        }
    }

    private func parsePositionalArguments(_ arguments: [String], record: inout Subrecord) throws {
        let minimumCount = parameters.reduce(0, { $0 + ($1.kind == .required ? 1 : 0) })
        if arguments.count < minimumCount {
            let requireds = parameters.filter { $0.kind == .required }
            throw OptionError("Missing argument for \(requireds[arguments.count].metavariable)")
        }
        var counts = [Int](repeating: 0, count: parameters.count)
        var remaining = arguments.count
        var optionals: [Int] = []
        var repeating: Int? = nil
        // Assign counts for required parameters, collect optionals and repeating parameters.
        for i in 0 ..< parameters.count {
            switch parameters[i].kind {
            case .required:
                counts[i] = 1
                remaining -= 1
            case .optional:
                optionals.append(i)
            case .repeating:
                precondition(repeating == nil, "Can't have more than one repeating positional")
                repeating = i
            }
        }
        // Assign counts for optional parameters.
        for i in optionals.prefix(remaining) {
            counts[i] = 1
            remaining -= 1
        }
        // Assign remaining arguments to repeating parameter (if any)
        if let repeating = repeating {
            counts[repeating] = remaining
        }
        else {
            guard remaining == 0 else {
                throw OptionError("Unexpected argument '\(arguments[parameters.count])'")
            }
        }
        // Apply arguments to parameters.
        var i = 0
        for p in 0 ..< parameters.count {
            for _ in 0 ..< counts[p] {
                try parameters[p].apply(&record, arguments[i])
                i += 1
            }
        }
    }

    func printHelp(toolName: String, printer: (String) throws -> Void) throws {
        var usage = "Usage: \(toolName)"
        if let name = name {
            usage += " \(name)"
        }

        if !options.isEmpty {
            usage += " [<option>]..."
        }
        if !commands.isEmpty {
            usage += " <command> [<arg>]..."
        }
        if !parameters.isEmpty {
            if !commands.isEmpty { usage += " |" }
            usage += parameters.map { " \($0.usage)" }.joined()
        }
        var lines: [String] = []
        lines += [usage]

        if !docs.isEmpty {
            lines += docs.components(separatedBy: .newlines)
        }

        if !options.isEmpty {
            lines += ["", "Options:"]
            for option in options {
                lines += helpEntry(usage: option.usage, docs: option.docs)
            }
        }
        if !parameters.isEmpty {
            lines += ["", "Positional parameters:"]
            for parameter in parameters {
                lines += helpEntry(usage: parameter.usage, docs: parameter.docs)
            }
        }
        if !commands.isEmpty {
            lines += ["", "Commands:"]
            for command in commands {
                lines += helpEntry(usage: command.name, docs: command.docs)
            }
        }

        try printer(lines.joined(separator: "\n"))
    }
}

extension Syntax where Record == Void {
    convenience init(docs: String,
                     initial: Subrecord,
                     options: [Option],
                     parameters: [Parameter],
                     commands: [AnyCommand]) {
        var commands = commands
        var helpCommand: OptionParser<Subrecord>.HelpCommand? = nil
        if !commands.isEmpty, commands.index(where: { $0.name == "help" }) == nil {
            let help = OptionParser<Subrecord>.HelpCommand()
            commands.append(help)
            helpCommand = help
        }

        self.init(name: nil,
                  docs: docs,
                  initial: { _ in initial },
                  options: options,
                  parameters: parameters,
                  commands: commands)

        helpCommand?.parentSyntax = self
    }
}
