//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import NIOIMAP
import IMAPCommands
#if canImport(System)
import System
#else
import SystemPackage
#endif

/// A formatted output value that supports custom string interpolations.
public struct Output: Equatable {
    var text: String
}

/// Using `Output`, the tool can use different string interpolations than the default
/// `String` interpolations.
extension Output: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(text: value)
    }
}

extension Output: ExpressibleByStringInterpolation {
    public init(stringInterpolation: StringInterpolation) {
        self.text = stringInterpolation.text
    }

    public struct StringInterpolation: StringInterpolationProtocol {
        var text: String

        public init(literalCapacity: Int, interpolationCount: Int) {
            self.text = ""
            self.text.reserveCapacity(literalCapacity + interpolationCount * 10)
        }
    }
}

extension Output.StringInterpolation {
    public mutating func appendLiteral(_ literal: String) {
        self.text.append(literal)
    }

    public mutating func appendInterpolation(_ value: String) {
        self.text.append(value)
    }

    public mutating func appendInterpolation(_ value: Command) {
        self.text.append(String(reflecting: value))
    }

    public mutating func appendInterpolation(_ duration: TimeInterval) {
        let ms = duration * 1000
        self.text.append(integerFormatter.string(for: ms)! + " ms")
    }

    public mutating func appendInterpolation(_ duration: Duration) {
        self.appendInterpolation(TimeInterval(duration))
    }

    public mutating func appendInterpolation(_ path: MailboxPath) {
        let text =
            path
            .displayStringComponents(omittingEmptySubsequences: false)
            .joined(separator: path.pathSeparator.map { String($0) } ?? "/")
        self.text.append(text)
    }

    public mutating func appendInterpolation(_ name: MailboxName) {
        guard let path = try? MailboxPath(name: name, pathSeparator: nil) else { return }
        self.appendInterpolation(path)
    }

    public mutating func appendInterpolation(_ value: UID) {
        self.text.append("\(UInt32(value))")
    }

    public mutating func appendInterpolation(_ value: SearchKey) {
        self.text.append("\(String(reflecting: value))")
    }

    public mutating func appendInterpolation(_ value: MessageID) {
        self.text.append("\(String(value))")
    }

    public mutating func appendInterpolation(_ value: UIDSet) {
        self.text.append(String(reflecting: value))
    }

    public mutating func appendInterpolation(_ value: UIDValidity) {
        self.text.append("\(UInt32(value))")
    }

    public mutating func appendInterpolation(_ value: UIDSetNonEmpty) {
        self.text.append("\(String(reflecting: value.set))")
    }

    public mutating func appendInterpolation(_ value: IMAPConnection.Tag) {
        self.text.append(String(value))
    }

    public mutating func appendInterpolation(_ value: ResponseText) {
        if let code = value.code {
            self.appendInterpolation(code)
            self.appendLiteral(" ")
        }
        self.text.append(value.text)
    }

    public mutating func appendInterpolation(_ range: NIOIMAP.PartialRange) {
        switch range {
        case .first(let r):
            self.appendLiteral("first-")
            self.appendInterpolation(r)
        case .last(let r):
            self.appendLiteral("last-")
            self.appendInterpolation(r)
        }
    }

    public mutating func appendInterpolation<ID: MessageIdentifier>(_ range: MessageIdentifierRange<ID>) {
        self.text.append(String(reflecting: range))
    }

    public mutating func appendInterpolation(_ code: ResponseTextCode) {
        self.text.append(String(reflecting: code))
    }

    public mutating func appendInterpolation(_ state: TaggedResponse.State) {
        self.text.append(String(reflecting: state))
    }

    public mutating func appendInterpolation(_ status: UntaggedStatus) {
        self.text.append(String(reflecting: Response.untagged(.conditionalState(status))))
    }

    public mutating func appendInterpolation(_ status: Bool) {
        self.text.append(status ? "true" : "false")
    }

    public mutating func appendInterpolation(_ value: Int) {
        self.text.append(integerFormatter.string(for: value)!)
    }

    public mutating func appendInterpolation(_ value: CInt) {
        self.text.append(integerFormatter.string(for: value)!)
    }

    public mutating func appendInterpolation(_ value: FilePath) {
        self.text.append(String(decoding: value))
    }

    public mutating func appendInterpolation(_ value: FilePath.Component) {
        self.text.append(String(decoding: value))
    }

    public mutating func appendInterpolation(_ error: some Swift.Error) {
        switch error {
        case let e as LocalizedError:
            self.text.append(e.errorDescription ?? "\(e)")
        default:
            self.text.append("\(error)")
        }
    }
}

extension TimeInterval {
    /// The duration expressed as a number of seconds.
    fileprivate init(_ duration: Duration) {
        let components = duration.components
        self = Double(components.seconds) + Double(components.attoseconds) * 1e-18
    }
}

private let integerFormatter: NumberFormatter = {
    var f = NumberFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.numberStyle = .decimal
    f.groupingSeparator = ","
    f.usesGroupingSeparator = true
    f.groupingSize = 3
    f.maximumFractionDigits = 0
    f.roundingMode = .halfUp
    return f
}()

extension IMAPConnection.Tag: TextOutputEncodable {
    /// The text representation of the tag.
    public var textOutput: String { String(self) }
    /// Additional output lines (always empty for tags).
    public var textOutputLines: [String] { [] }
}
