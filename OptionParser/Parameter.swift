// Copyright © 2017 Károly Lőrentey.
// This file is part of OptionParser: https://github.com/lorentey/OptionParser
// For licensing information, see the file LICENSE.md in the Git repository above.

import Foundation

extension OptionParser {
    public struct Parameter {
        public enum Kind {
            case required
            case optional
            case repeating
        }
        let metavariable: String
        let docs: String
        let kind: Kind
        let apply: (inout Record, String) throws -> Void

        var usage: String {
            switch kind {
            case .required: return metavariable
            case .optional: return "[\(metavariable)]"
            case .repeating: return "[\(metavariable)]..."
            }
        }

        private init(metavariable: String, docs: String, kind: Kind = .required, apply: @escaping (inout Record, String) throws -> Void) {
            self.metavariable = metavariable
            self.docs = docs
            self.kind = kind
            self.apply = apply
        }

        public static func required<V: OptionValue>(for keyPath: WritableKeyPath<Record, V>, metavariable: String, docs: String) -> Parameter {
            return Parameter(metavariable: metavariable, docs: docs, kind: .required) { record, string in
                record[keyPath: keyPath] = try V(fromOptionValue: string)
                return
            }
        }

        public static func optional<V: OptionValue>(for keyPath: WritableKeyPath<Record, V>, metavariable: String, docs: String) -> Parameter {
            return Parameter(metavariable: metavariable, docs: docs, kind: .optional) { record, string in
                record[keyPath: keyPath] = try V(fromOptionValue: string)
                return
            }
        }

        public static func optional<V: OptionValue>(for keyPath: WritableKeyPath<Record, V?>, metavariable: String, docs: String) -> Parameter {
            return Parameter(metavariable: metavariable, docs: docs, kind: .optional) { record, string in
                record[keyPath: keyPath] = try V(fromOptionValue: string)
                return
            }
        }

        public static func repeating<V: OptionValue>(for keyPath: WritableKeyPath<Record, [V]>, metavariable: String, docs: String) -> Parameter {
            return Parameter(metavariable: metavariable, docs: docs, kind: .repeating) { record, string in
                record[keyPath: keyPath].append(try V(fromOptionValue: string))
            }
        }
    }
}

