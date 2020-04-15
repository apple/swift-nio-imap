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

import NIO
import IMAPCore

// MARK: - Encoding
extension ByteBuffer {
    
    @discardableResult mutating func writeFetchAttributeList(_ atts: [IMAPCore.FetchAttribute]) -> Int {
        return self.writeArray(atts) { (element, self) in
            self.writeFetchAttribute(element)
        }
    }
    
    @discardableResult mutating func writeFetchAttribute(_ attribute: IMAPCore.FetchAttribute) -> Int {
        switch attribute {
        case .envelope:
            return self.writeFetchAttribute_envelope()
        case .flags:
            return self.writeFetchAttribute_flags()
        case .internaldate:
            return self.writeFetchAttribute_internalDate()
        case .rfc822(let rfc):
            return self.writeFetchAttribute_rfc(rfc)
        case .body(structure: let structure):
            return self.writeFetchAttribute_body(structure: structure)
        case .bodySection(let section, let partial):
            return self.writeFetchAttribute_body(section: section, partial: partial)
        case .bodyPeekSection(let section, let partial):
            return self.writeFetchAttribute_bodyPeek(section: section, partial: partial)
        case .uid:
            return self.writeFetchAttribute_uid()
        case .modSequence(let value):
            return self.writeModifierSequenceValue(value)
        case let .binary(peek: peek, section: section, partial: partial):
            return self.writeFetchAttribute_binary(peek: peek, section: section, partial: partial)
        case let .binarySize(section: section):
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
    
    @discardableResult mutating func writeFetchAttribute_rfc(_ rfc: IMAPCore.RFC822?) -> Int {
        self.writeString("RFC822") +
        self.writeIfExists(rfc) { (rfc) -> Int in
            self.writeRFC822(rfc)
        }
    }
    
    @discardableResult mutating func writeFetchAttribute_body(structure: Bool) -> Int {
        let string = structure ? "BODYSTRUCTURE" : "BODY"
        return self.writeString(string)
    }
    
    @discardableResult mutating func writeFetchAttribute_body(section: IMAPCore.SectionSpec?, partial: IMAPCore.Partial?) -> Int {
        self.writeString("BODY") +
        self.writeSection(section) +
        self.writeIfExists(partial) { (partial) -> Int in
            self.writePartial(partial)
        }
    }
    
    @discardableResult mutating func writeFetchAttribute_bodyPeek(section: IMAPCore.SectionSpec?, partial: IMAPCore.Partial?) -> Int {
        self.writeString("BODY.PEEK") +
        self.writeSection(section) +
        self.writeIfExists(partial) { (partial) -> Int in
            self.writePartial(partial)
        }
    }
    
    @discardableResult mutating func writeFetchAttribute_binarySize(_ section: [Int]) -> Int {
        self.writeString("BINARY.SIZE") +
        self.writeSectionBinary(section)
    }
    
    @discardableResult mutating func writeFetchAttribute_binary(peek: Bool, section: [Int], partial: IMAPCore.Partial?) -> Int {
        self.writeString("BINARY") +
        self.writeIfTrue(peek) {
            self.writeString(".PEEK")
        } +
        self.writeSectionBinary(section) +
        self.writeIfExists(partial) { (partial) -> Int in
            self.writePartial(partial)
        }
    }
    
}
