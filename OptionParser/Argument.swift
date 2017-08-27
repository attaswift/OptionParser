// Copyright © 2017 Károly Lőrentey.
// This file is part of OptionParser: https://github.com/lorentey/OptionParser
// For licensing information, see the file LICENSE.md in the Git repository above.

import Foundation

class Argument {
    enum Kind {
        case value(String) // foo
        case option(String, String?) // -foo[=value], --foo[=value]

        init(_ value: String) {
            func split(_ s: Substring) -> (name: String, value: String?) {
                guard let i = s.index(of: "=") else {
                    return (String(s), nil)
                }
                let name = s[..<i]
                let value = s.suffix(from: s.index(after: i))
                return (String(name), String(value))
            }

            let c = value.count
            if value.starts(with: "--"), c > 2 {
                let pair = split(value.dropFirst(2))
                self = .option(pair.name, pair.value)
            }
            else if value.starts(with: "-"), c > 1 {
                let pair = split(value.dropFirst())
                self = .option(pair.name, pair.value)
            }
            else {
                self = .value(value)
            }
        }
    }

    let value: String
    internal private(set) lazy var kind: Kind = Kind(value)

    init(_ value: String) {
        self.value = value
    }
}

