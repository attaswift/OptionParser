// Copyright © 2017 Károly Lőrentey.
// This file is part of OptionParser: https://github.com/lorentey/OptionParser
// For licensing information, see the file LICENSE.md in the Git repository above.

import Foundation

public protocol OptionValue {
    init(fromOptionValue string: String) throws
}

extension String: OptionValue {
    public init(fromOptionValue string: String) throws {
        self = string
    }
}

extension Bool: OptionValue {
    public init(fromOptionValue string: String) throws {
        switch string {
        case "1", "true", "yes", "y", "on", "enable":
            self = true
        case "0", "false", "no", "n", "off", "disable":
            self = false
        default:
            throw OptionError("Invalid boolean value: '\(string)'")
        }
    }
}

extension FixedWidthInteger {
    public init(fromOptionValue string: String) throws {
        guard let value = Self(string, radix: 10) else {
            throw OptionError("Invalid integer value: '\(string)'")
        }
        self = value
    }
}

extension Int: OptionValue {}
extension UInt: OptionValue {}
extension Int8: OptionValue {}
extension UInt8: OptionValue {}
extension Int16: OptionValue {}
extension UInt16: OptionValue {}
extension Int32: OptionValue {}
extension UInt32: OptionValue {}
extension Int64: OptionValue {}
extension UInt64: OptionValue {}

extension Float: OptionValue {
    public init(fromOptionValue string: String) throws {
        guard let v = Float(string) else {
            throw OptionError("Invalid floating point value: '\(string)'")
        }
        self = v
    }
}

extension Double: OptionValue {
    public init(fromOptionValue string: String) throws {
        guard let v = Double(string) else {
            throw OptionError("Invalid floating point value: '\(string)'")
        }
        self = v
    }
}

extension RawRepresentable where RawValue == String {
    public init(fromOptionValue string: String) throws {
        guard let v = Self(rawValue: string) else {
            throw OptionError("Invalid value: '\(string)'")
        }
        self = v
    }
}
