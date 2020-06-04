//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2020 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import struct NIO.ByteBuffer

/// IMAPv4 `fetch-att`
public enum FetchAttribute: Equatable {
    case envelope
    case flags
    case internalDate
    case rfc822(RFC822?)
    /// `BODY` and `BODYSTRUCTURE` -- the latter will result in the extension parts
    /// of the body structure to be returned as part of the response, whereas the former
    /// will not.
    case bodyStructure(extensions: Bool)
    /// `BODY[<section>]<<partial>>` and `BODY.PEEK[<section>]<<partial>>`
    case bodySection(peek: Bool, _ section: SectionSpecifier?, ClosedRange<Int>?)
    case uid
    case modifierSequenceValue(ModifierSequenceValue)
    case binary(peek: Bool, section: SectionSpecifier.Part, partial: ClosedRange<Int>?)
    case binarySize(section: SectionSpecifier.Part)
}

extension Array where Element == FetchAttribute {
    static let all: [Element] = [.flags, .internalDate, .rfc822(.size), .envelope]

    static let fast: [Element] = [.flags, .internalDate, .rfc822(.size)]

    static let full: [Element] = [.flags, .internalDate, .rfc822(.size), .envelope, .bodyStructure(extensions: false)]
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeFetchAttributeList(_ atts: [FetchAttribute]) -> Int {
        self.writeArray(atts) { (element, self) in
            self.writeFetchAttribute(element)
        }
    }

    @discardableResult mutating func writeFetchAttribute(_ attribute: FetchAttribute) -> Int {
        switch attribute {
        case .envelope:
            return self.writeFetchAttribute_envelope()
        case .flags:
            return self.writeFetchAttribute_flags()
        case .internalDate:
            return self.writeFetchAttribute_internalDate()
        case .rfc822(let rfc):
            return self.writeFetchAttribute_rfc(rfc)
        case .bodyStructure(extensions: let extensions):
            return self.writeFetchAttribute_bodyStructure(extensions: extensions)
        case .bodySection(peek: let peek, let section, let partial):
            return self.writeFetchAttribute_body(peek: peek, section: section, partial: partial)
        case .uid:
            return self.writeFetchAttribute_uid()
        case .modifierSequenceValue(let value):
            return self.writeModifierSequenceValue(value)
        case .binary(let peek, let section, let partial):
            return self.writeFetchAttribute_binary(peek: peek, section: section, partial: partial)
        case .binarySize(let section):
            return self.writeFetchAttribute_binarySize(section)
        }
    }

    @discardableResult mutating func writeFetchAttribute_envelope() -> Int {
        self.writeString("ENVELOPE")
    }

    @discardableResult mutating func writeFetchAttribute_flags() -> Int {
        self.writeString("FLAGS")
    }

    @discardableResult mutating func writeFetchAttribute_internalDate() -> Int {
        self.writeString("INTERNALDATE")
    }

    @discardableResult mutating func writeFetchAttribute_uid() -> Int {
        self.writeString("UID")
    }

    @discardableResult mutating func writeFetchAttribute_rfc(_ rfc: RFC822?) -> Int {
        self.writeString("RFC822") +
            self.writeIfExists(rfc) { (rfc) -> Int in
                self.writeRFC822(rfc)
            }
    }

    @discardableResult mutating func writeFetchAttribute_bodyStructure(extensions: Bool) -> Int {
        self.writeString(extensions ? "BODYSTRUCTURE" : "BODY")
    }

    @discardableResult mutating func writeFetchAttribute_body(peek: Bool, section: SectionSpecifier?, partial: ClosedRange<Int>?) -> Int {
        self.writeString(peek ? "BODY.PEEK" : "BODY") +
            self.writeSection(section) +
            self.writeIfExists(partial) { (partial) -> Int in
                self.writePartial(partial)
            }
    }

    @discardableResult mutating func writeFetchAttribute_binarySize(_ section: SectionSpecifier.Part) -> Int {
        self.preconditionCapability(.binary)
        return self.writeString("BINARY.SIZE") +
            self.writeSectionBinary(section)
    }

    @discardableResult mutating func writeFetchAttribute_binary(peek: Bool, section: SectionSpecifier.Part, partial: ClosedRange<Int>?) -> Int {
        self.preconditionCapability(.binary)
        return self.writeString("BINARY") +
            self.writeIfTrue(peek) {
                self.writeString(".PEEK")
            } +
            self.writeSectionBinary(section) +
            self.writeIfExists(partial) { (partial) -> Int in
                self.writePartial(partial)
            }
    }
}
