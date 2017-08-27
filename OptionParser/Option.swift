// Copyright © 2017 Károly Lőrentey.
// This file is part of OptionParser: https://github.com/lorentey/OptionParser
// For licensing information, see the file LICENSE.md in the Git repository above.

import Foundation

public enum OptionArraySyntax {
    case commaSeparated
    case upToNextOption
    case repeated
}

extension OptionParser {
    public struct Option {
        enum Kind {
            case option((String?, inout ParseContext, inout Record) throws -> Void)
            case action(() throws -> Void)
            case help
        }

        let kind: Kind
        let name: String
        let usage: String
        let docs: String

        init(name: String, usage: String, docs: String, kind: Kind) {
            self.kind = kind
            self.name = name
            self.usage = usage
            self.docs = docs
        }

        init(name: String, usage: String, docs: String, parser: @escaping (String?, inout ParseContext, inout Record) throws -> Void) {
            self.init(name: name, usage: usage, docs: docs, kind: .option(parser))
        }

        init(name: String, usage: String, docs: String, action: @escaping () throws -> Void) {
            self.init(name: name, usage: usage, docs: docs, kind: .action(action))
        }

        public static func flag<V>(for keyPath: WritableKeyPath<Record, V>, value: V,
                                   name: String, docs: String) -> Option {
            return Option(name: name, usage: "-\(name)", docs: docs) { v, context, record in
                if let v = v { throw OptionError("Unexpected value '\(v)' for option -\(name)")}
                record[keyPath: keyPath] = value
            }
        }

        private static func _value<V: OptionValue>
            (of type: V.Type = V.self, default defaultValue: V? = nil,
             name: String, metavariable: String, docs: String,
             action: @escaping (inout Record, V) -> Void) -> Option {
            let usage = defaultValue == nil
                ? "-\(name)=\(metavariable)"
                : "-\(name)[=\(metavariable)]"
            return .init(name: name, usage: usage, docs: docs) { value, context, record in
                if let value = value {
                    action(&record, try V(fromOptionValue: value))
                }
                else {
                    guard let value = defaultValue else {
                        throw OptionError("Option -\(name) requires a value")
                    }
                    action(&record, value)
                }
            }
        }

        public static func value<V: OptionValue>
            (of type: V.Type = V.self, for keyPath: WritableKeyPath<Record, V>, default defaultValue: V? = nil,
             name: String, metavariable: String, docs: String) -> Option {
            return _value(of: type, default: defaultValue,
                          name: name, metavariable: metavariable, docs: docs) { record, value in
                record[keyPath: keyPath] = value
            }
        }

        public static func value<V: OptionValue>
            (of type: V.Type = V.self, for keyPath: WritableKeyPath<Record, V?>, default defaultValue: V? = nil,
             name: String, metavariable: String, docs: String) -> Option {
            return _value(of: type, default: defaultValue,
                          name: name, metavariable: metavariable, docs: docs) { record, value in
                record[keyPath: keyPath] = value
            }
        }

        public static func array<Element: OptionValue>
            (of type: Element.Type = Element.self, for keyPath: WritableKeyPath<Record, [Element]>,
             syntax: OptionArraySyntax = .upToNextOption,
             name: String, metavariable: String = "<item>", docs: String) -> Option {
            let usage: String
            switch syntax {
            case .commaSeparated:
                usage = "-\(name)=\(metavariable),\(metavariable)..."
            case .upToNextOption:
                usage = "-\(name) \(metavariable)..."
            case .repeated:
                usage = "-\(name)=\(metavariable)"
            }
            return .init(name: name, usage: usage, docs: docs) { value, context, record in
                switch syntax {
                case .commaSeparated:
                    guard let value = value else { throw OptionError("Option -\(name) requires a value") }
                    guard !value.isEmpty else { return }
                    let values = try value.components(separatedBy: ",")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .map { try Element(fromOptionValue: $0) }
                    record[keyPath: keyPath] += values
                case .upToNextOption:
                    if let value = value {
                        record[keyPath: keyPath].append(try Element(fromOptionValue: value))
                    }
                    else {
                        var values: [Element] = []
                        while case .value(_)? = context.peek()?.kind {
                            let v = context.accept().value
                            values.append(try Element(fromOptionValue: v))
                        }
                        record[keyPath: keyPath] += values
                    }
                case .repeated:
                    guard let value = value else { throw OptionError("Option -\(name) requires a value") }
                    record[keyPath: keyPath].append(try Element(fromOptionValue: value))
                }
            }
        }

        public static func action(name: String, docs: String, action: @escaping () throws -> Void) -> Option {
            return Option(name: name, usage: "-\(name)", docs: docs, action: action)
        }

        static func help() -> Option {
            return Option(name: "help", usage: "-help",
                          docs: "Print usage information and exit.",
                          kind: .help)
        }
    }
}

