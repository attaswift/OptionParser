// Copyright © 2017 Károly Lőrentey.
// This file is part of OptionParser: https://github.com/lorentey/OptionParser
// For licensing information, see the file LICENSE.md in the Git repository above.

import Foundation

struct ParseContext {
    let printer: (String) throws -> Void
    let toolName: String
    private let _arguments: [Argument]
    private var _index: Int

    init(_ arguments: [String], printer: @escaping (String) throws -> Void) {
        self.printer = printer
        self.toolName = (arguments[0] as NSString).lastPathComponent
        self._arguments = arguments.dropFirst().map { Argument($0) }
        self._index = 0
    }

    var isAtEnd: Bool {
        return _index == _arguments.count
    }

    func peek() -> Argument? {
        if isAtEnd { return nil }
        return _arguments[_index]
    }

    @discardableResult
    mutating func accept() -> Argument {
        precondition(_index < _arguments.count)
        let result = _arguments[_index]
        _index += 1
        return result
    }
}

