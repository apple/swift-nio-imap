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

extension NIOIMAP {
    /// Extracted from IMAPv4 `msg-att-static`
    public enum RFC822Reduced: String, Equatable {
        case header
        case text
    }

    /// IMAPv4 `msg-att-static`
    public enum MessageAttributesStatic: Equatable {
        case envelope(Envelope)
        case internalDate(Date.DateTime)
        case uid(Int)

        case rfc822(RFC822Reduced?, NIOIMAP.NString)
        case rfc822Size(Int)

        case body(BodyStructure, structure: Bool)
        case bodySection(SectionSpec?, Int?, NString)

        case binaryString(section: [Int], string: NString)
        case binarySize(section: [Int], number: Int)
    }
}

// MARK: - Encoding

extension ByteBuffer {
    @discardableResult mutating func writeMessageAttributeStatic(_ att: NIOIMAP.MessageAttributesStatic) -> Int {
        switch att {
        case .envelope(let env):
            return self.writeMessageAttributeStatic_envelope(env)
        case .internalDate(let date):
            return self.writeMessageAttributeStatic_internalDate(date)
        case .rfc822(let type, let string):
            return self.writeMessageAttributeStatic_rfc(type, string: string)
        case .rfc822Size(let size):
            return self.writeString("RFC822.SIZE \(size)")
        case .body(let body, structure: let structure):
            return self.writeMessageAttributeStatic_body(body, structure: structure)
        case .bodySection(let section, let number, let string):
            return self.writeMessageAttributeStatic_bodySection(section, number: number, string: string)
        case .uid(let uid):
            return self.writeString("UID \(uid)")
        case .binaryString(section: let section, string: let string):
            return
                self.writeString("BINARY") +
                self.writeSectionBinary(section) +
                self.writeSpace() +
                self.writeNString(string)
        case .binarySize(section: let section, number: let number):
            return
                self.writeString("BINARY.SIZE") +
                self.writeSectionBinary(section) +
                self.writeString(" \(number)")
        }
    }

    @discardableResult mutating func writeMessageAttributeStatic_envelope(_ env: NIOIMAP.Envelope) -> Int {
        self.writeString("ENVELOPE ") +
            self.writeEnvelope(env)
    }

    @discardableResult mutating func writeMessageAttributeStatic_internalDate(_ date: NIOIMAP.Date.DateTime) -> Int {
        self.writeString("INTERNALDATE ") +
            self.writeDateTime(date)
    }

    @discardableResult mutating func writeMessageAttributeStatic_rfc(_ type: NIOIMAP.RFC822Reduced?, string: NIOIMAP.NString) -> Int {
        self.writeString("RFC822") +
            self.writeIfExists(type) { (type) -> Int in
                self.writeString(".\(type.rawValue.uppercased())")
            } +
            self.writeSpace() +
            self.writeNString(string)
    }

    @discardableResult mutating func writeMessageAttributeStatic_body(_ body: NIOIMAP.BodyStructure, structure: Bool) -> Int {
        self.writeString("BODY") +
            self.writeIfTrue(structure) { () -> Int in
                self.writeString("STRUCTURE")
            } +
            self.writeSpace() +
            self.writeBody(body)
    }

    @discardableResult mutating func writeMessageAttributeStatic_bodySection(_ section: NIOIMAP.SectionSpec?, number: Int?, string: NIOIMAP.NString) -> Int {
        self.writeString("BODY") +
            self.writeSection(section) +
            self.writeIfExists(number) { (number) -> Int in
                self.writeString("<\(number)>")
            } +
            self.writeSpace() +
            self.writeNString(string)
    }

    @discardableResult mutating func writeMessageAttributeStatic_bodySectionText(number: Int?, size: Int) -> Int {
        self.writeString("BODY[TEXT]") +
            self.writeIfExists(number) { (number) -> Int in
                self.writeString("<\(number)>")
            } +
            self.writeString(" {\(size)}\r\n")
    }
}
