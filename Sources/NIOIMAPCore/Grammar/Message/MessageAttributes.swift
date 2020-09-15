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

/// These are the individual parts of a `FETCH` response.
///
/// - SeeAlso: RFC 3501 section 7.4.2
public enum MessageAttribute: Equatable {
    /// `FLAGS` -- A list of flags that are set for this message.
    case flags([Flag])
    /// `ENVELOPE` -- A list that describes the envelope structure of a message.
    case envelope(Envelope)
    /// The internal date of the message.
    case internalDate(InternalDate)
    /// The unique identifier of the message.
    case uid(UID)
    /// `RFC822` -- Equivalent to `BODY[]`.
    case rfc822(ByteBuffer?)
    /// `RFC822.HEADER` -- Equivalent to `BODY[HEADER]`.
    case rfc822Header(ByteBuffer?)
    case rfc822Text(ByteBuffer?)
    /// `RFC822.SIZE` -- A number expressing the RFC 2822 size of the message.
    case rfc822Size(Int)

    /// `BODYSTRUCTURE` or `BODY` -- A list that describes the MIME body structure of a message.
    ///
    /// A `BODYSTRUCTURE` response will have `hasExtensionData` set to `true`.
    case body(BodyStructure, hasExtensionData: Bool)

    /// `BODY[<section>]<<origin octet>>` -- The body contents of the specified section.
    case bodySection(SectionSpecifier, offset: Int?, data: ByteBuffer?)

    /// `BINARY<section-binary>[<<number>>]` -- The content of the
    /// specified section after removing any content-transfer-encoding related encoding.
    /// - SeeAlso: RFC 3516 “IMAP4 Binary Content Extension”
    case binary(section: SectionSpecifier.Part, data: ByteBuffer?)
    /// `BINARY.SIZE<section-binary>` -- The size of the section after
    /// removing any content-transfer-encoding related encoding.
    /// - SeeAlso: RFC 3516 “IMAP4 Binary Content Extension”
    case binarySize(section: SectionSpecifier.Part, size: Int)

    case fetchModifierResponse(FetchModifierResponse)
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
        case .body(let body, hasExtensionData: let hasExtensionData):
            return self.writeMessageAttribute_body(body, hasExtensionData: hasExtensionData)
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
        case .fetchModifierResponse(let resp):
            return self.writeFetchModifierResponse(resp)
        }
    }

    @discardableResult mutating func writeMessageAttribute_binaryString(section: SectionSpecifier.Part, string: ByteBuffer?) -> Int {
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

    @discardableResult mutating func writeMessageAttribute_rfc822(_ string: ByteBuffer?) -> Int {
        self.writeString("RFC822") +
            self.writeSpace() +
            self.writeNString(string)
    }

    @discardableResult mutating func writeMessageAttribute_rfc822Text(_ string: ByteBuffer?) -> Int {
        self.writeString("RFC822.TEXT") +
            self.writeSpace() +
            self.writeNString(string)
    }

    @discardableResult mutating func writeMessageAttribute_rfc822Header(_ string: ByteBuffer?) -> Int {
        self.writeString("RFC822.HEADER") +
            self.writeSpace() +
            self.writeNString(string)
    }

    @discardableResult mutating func writeMessageAttribute_body(_ body: BodyStructure, hasExtensionData: Bool) -> Int {
        self.writeString("BODY") +
            self.writeIfTrue(hasExtensionData) { () -> Int in
                self.writeString("STRUCTURE")
            } +
            self.writeSpace() +
            self.writeBody(body)
    }

    @discardableResult mutating func writeMessageAttribute_bodySection(_ section: SectionSpecifier?, number: Int?, string: ByteBuffer?) -> Int {
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
