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

public enum MessageAttribute: Equatable {
    case flags([Flag])
    case envelope(Envelope)
    case internalDate(InternalDate)
    case uid(UID)
    case rfc822(NString)
    case rfc822Header(NString)
    case rfc822Text(NString)
    case rfc822Size(Int)
    case body(BodyStructure, structure: Bool)
    case bodySection(SectionSpecifier, offset: Int?, data: NString)
    case binary(section: SectionSpecifier.Part, data: NString)
    case binarySize(section: SectionSpecifier.Part, size: Int)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeMessageAttributes(_ atts: [MessageAttribute]) -> Int {
        self.writeArray(atts) { (element, self) in
            self.writeMessageAttribute(element)
        }
    }

    @discardableResult mutating func writeMessageAttribute(_ type: MessageAttribute) -> Int {
        switch type {
        case .envelope(let env):
            return self.writeMessageAttribute_envelope(env)
        case .internalDate(let date):
            return self.writeMessageAttribute_internalDate(date)
        case .rfc822(let string):
            return self.writeMessageAttribute_rfc822(string)
        case .rfc822Header(let string):
            return self.writeMessageAttribute_rfc822Header(string)
        case .rfc822Text(let string):
            return self.writeMessageAttribute_rfc822Text(string)
        case .rfc822Size(let size):
            return self.writeString("RFC822.SIZE \(size)")
        case .body(let body, structure: let structure):
            return self.writeMessageAttribute_body(body, structure: structure)
        case .bodySection(let section, let number, let string):
            return self.writeMessageAttribute_bodySection(section, number: number, string: string)
        case .uid(let uid):
            return self.writeString("UID \(uid.rawValue)")
        case .binary(section: let section, data: let string):
            return self.writeMessageAttribute_binaryString(section: section, string: string)
        case .binarySize(section: let section, size: let number):
            return self.writeMessageAttribute_binarySize(section: section, number: number)
        case .flags(let flags):
            return self.writeMessageAttributeFlags(flags)
        }
    }

    @discardableResult mutating func writeMessageAttribute_binaryString(section: SectionSpecifier.Part, string: NString) -> Int {
        self.writeString("BINARY") +
            self.writeSectionBinary(section) +
            self.writeSpace() +
            self.writeNString(string)
    }

    @discardableResult mutating func writeMessageAttribute_binarySize(section: SectionSpecifier.Part, number: Int) -> Int {
        self.writeString("BINARY.SIZE") +
            self.writeSectionBinary(section) +
            self.writeString(" \(number)")
    }

    @discardableResult mutating func writeMessageAttributeFlags(_ atts: [Flag]) -> Int {
        self.writeString("FLAGS ") +
            self.writeArray(atts) { (element, self) in
                self.writeFlag(element)
            }
    }

    @discardableResult mutating func writeMessageAttribute_envelope(_ env: Envelope) -> Int {
        self.writeString("ENVELOPE ") +
            self.writeEnvelope(env)
    }

    @discardableResult mutating func writeMessageAttribute_internalDate(_ date: InternalDate) -> Int {
        self.writeString("INTERNALDATE ") +
            self.writeInternalDate(date)
    }

    @discardableResult mutating func writeMessageAttribute_rfc822(_ string: NString) -> Int {
        self.writeString("RFC822") +
            self.writeSpace() +
            self.writeNString(string)
    }

    @discardableResult mutating func writeMessageAttribute_rfc822Text(_ string: NString) -> Int {
        self.writeString("RFC822.TEXT") +
            self.writeSpace() +
            self.writeNString(string)
    }

    @discardableResult mutating func writeMessageAttribute_rfc822Header(_ string: NString) -> Int {
        self.writeString("RFC822.HEADER") +
            self.writeSpace() +
            self.writeNString(string)
    }

    @discardableResult mutating func writeMessageAttribute_body(_ body: BodyStructure, structure: Bool) -> Int {
        self.writeString("BODY") +
            self.writeIfTrue(structure) { () -> Int in
                self.writeString("STRUCTURE")
            } +
            self.writeSpace() +
            self.writeBody(body)
    }

    @discardableResult mutating func writeMessageAttribute_bodySection(_ section: SectionSpecifier?, number: Int?, string: NString) -> Int {
        self.writeString("BODY") +
            self.writeSection(section) +
            self.writeIfExists(number) { (number) -> Int in
                self.writeString("<\(number)>")
            } +
            self.writeSpace() +
            self.writeNString(string)
    }

    @discardableResult mutating func writeMessageAttribute_bodySectionText(number: Int?, size: Int) -> Int {
        self.writeString("BODY[TEXT]") +
            self.writeIfExists(number) { (number) -> Int in
                self.writeString("<\(number)>")
            } +
            self.writeString(" {\(size)}\r\n")
    }
}
