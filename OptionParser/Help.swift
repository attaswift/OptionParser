// Copyright © 2017 Károly Lőrentey.
// This file is part of OptionParser: https://github.com/lorentey/OptionParser
// For licensing information, see the file LICENSE.md in the Git repository above.

import Foundation

extension Sequence where Element == String {
    func indented(by spaces: Int) -> [String] {
        let indent = String(repeating: " ", count: spaces)
        return self.map { indent + $0 }
    }
}

func helpEntry(usage: String, docs: String,
              indent: String = "  ",
              columnSeparator: String = " ",
              usageColumnWidth: Int = 10) -> [String] {
    var help: [String] = []
    let docLines = docs.components(separatedBy: .newlines)
    let docIndent: Int = indent.count + usageColumnWidth + columnSeparator.count
    let c = usage.count
    if c <= usageColumnWidth {
        help.append(indent + usage.padding(toLength: usageColumnWidth, withPad: " ", startingAt: 0) + columnSeparator + docLines[0])
        help += docLines.dropFirst().indented(by: docIndent)
    }
    else {
        help.append(indent + usage)
        help += docLines.indented(by: docIndent)
    }
    return help
}
