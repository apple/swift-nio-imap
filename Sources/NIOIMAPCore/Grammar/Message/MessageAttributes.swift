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
public enum MessageAttribute: Hashable {
    /// `FLAGS` -- A list of flags that are set for this message.
    case flags([Flag])
    /// `ENVELOPE` -- A list that describes the envelope structure of a message.
    case envelope(Envelope)
    /// The internal date of the message.
    case internalDate(ServerMessageDate)
    /// The unique identifier of the message.
    case uid(UID)
    /// `RFC822.SIZE` -- A number expressing the RFC 2822 size of the message.
    case rfc822Size(Int)

    /// `BODYSTRUCTURE` or `BODY` -- A list that describes the MIME body structure of a message.
    ///
    /// A `BODYSTRUCTURE` response will have `hasExtensionData` set to `true`.
    case body(BodyStructure, hasExtensionData: Bool)

    /// `BINARY<section-binary>[<<number>>]` -- The content of the
    /// specified section after removing any content-transfer-encoding related encoding.
    /// - SeeAlso: RFC 3516 “IMAP4 Binary Content Extension”
    case binary(section: SectionSpecifier.Part, data: ByteBuffer?)
    /// `BINARY.SIZE<section-binary>` -- The size of the section after
    /// removing any content-transfer-encoding related encoding.
    /// - SeeAlso: RFC 3516 “IMAP4 Binary Content Extension”
    case binarySize(section: SectionSpecifier.Part, size: Int)

    /// A `NIL` response to a `StreamingKind`.
    ///
    /// This corresponds to e.g. `BODY[4.TEXT] NIL`, i.e. when there’s no data
    /// for a particular body section. Note that this is different than a
    /// `.streamingBegin` with a `byteCount` of `0`. The former indicates
    /// that the section does not exist, the latter than it has zero length.
    case nilBody(StreamingKind)

    /// The modification time of the message.
    case fetchModificationResponse(FetchModificationResponse)

    /// `X-GM-MSGID`: provides a unique ID for each email stable across multiple folders.
    case gmailMessageID(UInt64)

    /// `X-GM-THRID`: provides an ID that associates mail with a given gmail thread.
    case gmailThreadID(UInt64)

    /// `X-GM-LABELS`: provides the labels for a given message
    case gmailLabels([GmailLabel])
}

extension MessageAttribute: CustomDebugStringConvertible {
    public var debugDescription: String {
        EncodeBuffer.makeDescription {
            $0.writeMessageAttribute(self)
        }
    }
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
        case .rfc822Size(let size):
            return self.writeString("RFC822.SIZE \(size)")
        case .body(let body, hasExtensionData: let hasExtensionData):
            return self.writeMessageAttribute_body(body, hasExtensionData: hasExtensionData)
        case .uid(let uid):
            return self.writeString("UID \(uid.rawValue)")
        case .binary(section: let section, data: let string):
            return self.writeMessageAttribute_binaryString(section: section, string: string)
        case .binarySize(section: let section, size: let number):
            return self.writeMessageAttribute_binarySize(section: section, number: number)
        case .flags(let flags):
            return self.writeMessageAttributeFlags(flags)
        case .nilBody(let kind):
            return self.writeMessageAttributeNilBody(kind)
        case .fetchModificationResponse(let resp):
            return self.writeFetchModificationResponse(resp)
        case .gmailMessageID(let id):
            return self.writeMessageAttribute_gmailMessageID(id)
        case .gmailThreadID(let id):
            return self.writeMessageAttribute_gmailThreadID(id)
        case .gmailLabels(let labels):
            return self.writeMessageAttribute_gmailLabels(labels)
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

    @discardableResult mutating func writeMessageAttributeNilBody(_ kind: StreamingKind) -> Int {
        self.writeStreamingKind(kind) +
            self.writeSpace() +
            self.writeNil()
    }

    @discardableResult mutating func writeMessageAttribute_envelope(_ env: Envelope) -> Int {
        self.writeString("ENVELOPE ") +
            self.writeEnvelope(env)
    }

    @discardableResult mutating func writeMessageAttribute_internalDate(_ date: ServerMessageDate) -> Int {
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
            self.write(if: hasExtensionData) { () -> Int in
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

    @discardableResult mutating func writeMessageAttribute_gmailMessageID(_ id: UInt64) -> Int {
        self.writeString("X-GM-MSGID \(id)")
    }

    @discardableResult mutating func writeMessageAttribute_gmailThreadID(_ id: UInt64) -> Int {
        self.writeString("X-GM-THRID \(id)")
    }

    @discardableResult mutating func writeMessageAttribute_gmailLabels(_ labels: [GmailLabel]) -> Int {
        self.writeString("X-GM-LABELS") +
            self.writeSpace() +
            self.writeArray(labels) { label, buffer in
                buffer.writeGmailLabel(label)
            }
    }
}
