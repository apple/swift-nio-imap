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

/// Attributes of a message that can be retrieved as part of a `.fetch` command.
public enum FetchAttribute: Hashable {
    /// The message's envelope including the sender(s), bcc list, cc list, etc.
    case envelope

    /// The message's flags.
    case flags

    /// The message's internal date - the date the message was received.
    case internalDate

    /// Functionally equivalent to `.body`, but the format of the data is different and conforms to the RFC 822 syntax.
    case rfc822

    /// Functionally equivalent to `.body(peek: true, section: .header)`, but the format of the data is different and conforms to the RFC 822 syntax.
    case rfc822Header

    /// The RFC 822 size of the message in bytes.
    case rfc822Size

    /// Functionally equivalent to `.body(peek: false, section: .text)`, but the format of the data is different and conforms to the RFC 822 syntax.
    case rfc822Text

    /// `BODY` and `BODYSTRUCTURE` -- the latter will result in the extension parts
    /// of the body structure to be returned as part of the response, whereas the former
    /// will not.
    case bodyStructure(extensions: Bool)

    /// `BODY[<section>]<<partial>>` and `BODY.PEEK[<section>]<<partial>>`
    case bodySection(peek: Bool, _ section: SectionSpecifier, ClosedRange<UInt32>?)

    /// The unique identifier of the message.
    case uid

    /// The modification sequence of the message.
    case modificationSequence

    /// The modification sequence value.
    case modificationSequenceValue(ModificationSequenceValue)

    /// The binary data of the specified message section.
    case binary(peek: Bool, section: SectionSpecifier.Part, partial: ClosedRange<UInt32>?)

    /// The size of the specified message section.
    case binarySize(section: SectionSpecifier.Part)

    /// The message's GMail ID.
    case gmailMessageID

    /// The messages GMail Thread Id - the group of messages that this message belongs to.
    case gmailThreadID

    /// The message's GMail labels.
    case gmailLabels
    
    /// The RFC 8970 Server-generated abbreviated text representation of message
    /// data that is useful as a contextual preview of the entire message.
    case preview(lazy: Bool)
}

extension Array where Element == FetchAttribute {
    /// Macro equivalent to `[.flags, .internalDate, .rfc822Size, envelope]`
    public static let all: [Element] = [.flags, .internalDate, .rfc822Size, .envelope]

    /// Macro equivalent to `[.flags, .internalDate, .rfc822Size]`
    public static let fast: [Element] = [.flags, .internalDate, .rfc822Size]

    /// Macro equivalent to `[.flags, .internalDate, .rfc822Size, envelope, body]`
    public static let full: [Element] = [.flags, .internalDate, .rfc822Size, .envelope, .bodyStructure(extensions: false)]
}

// MARK: - Encoding

extension FetchAttribute: CustomDebugStringConvertible {
    public var debugDescription: String {
        EncodeBuffer.makeDescription {
            $0.writeFetchAttribute(self)
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeFetchAttributeList(_ atts: [FetchAttribute]) -> Int {
        // FAST -> (FLAGS INTERNALDATE RFC822.SIZE)
        // ALL -> (FLAGS INTERNALDATE RFC822.SIZE ENVELOPE)
        // FULL -> (FLAGS INTERNALDATE RFC822.SIZE ENVELOPE BODY)
        if atts.contains(.flags), atts.contains(.internalDate) {
            if atts.count == 3, atts.contains(.rfc822Size) {
                return self.writeString("FAST")
            }
            if atts.count == 4, atts.contains(.rfc822Size), atts.contains(.envelope) {
                return self.writeString("ALL")
            }
            if atts.count == 5, atts.contains(.rfc822Size), atts.contains(.envelope), atts.contains(.bodyStructure(extensions: false)) {
                return self.writeString("FULL")
            }
        }

        return self.writeArray(atts) { (element, self) in
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
        case .rfc822:
            return self.writeFetchAttribute_rfc822()
        case .rfc822Size:
            return self.writeFetchAttribute_rfc822Size()
        case .rfc822Header:
            return self.writeFetchAttribute_rfc822Header()
        case .rfc822Text:
            return self.writeFetchAttribute_rfc822Text()
        case .bodyStructure(extensions: let extensions):
            return self.writeFetchAttribute_bodyStructure(extensions: extensions)
        case .bodySection(peek: let peek, let section, let partial):
            return self.writeFetchAttribute_body(peek: peek, section: section, partial: partial)
        case .uid:
            return self.writeFetchAttribute_uid()
        case .modificationSequenceValue(let value):
            return self.writeModificationSequenceValue(value)
        case .binary(let peek, let section, let partial):
            return self.writeFetchAttribute_binary(peek: peek, section: section, partial: partial)
        case .binarySize(let section):
            return self.writeFetchAttribute_binarySize(section)
        case .modificationSequence:
            return self.writeString("MODSEQ")
        case .gmailMessageID:
            return self.writeFetchAttribute_gmailMessageID()
        case .gmailThreadID:
            return self.writeFetchAttribute_gmailThreadID()
        case .gmailLabels:
            return self.writeFetchAttribute_gmailLabels()
        case .preview(let lazy):
            return self.writeFetchAttribute_preview(lazy)
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

    @discardableResult mutating func writeFetchAttribute_rfc822() -> Int {
        self.writeString("RFC822")
    }

    @discardableResult mutating func writeFetchAttribute_rfc822Size() -> Int {
        self.writeString("RFC822.SIZE")
    }

    @discardableResult mutating func writeFetchAttribute_rfc822Header() -> Int {
        self.writeString("RFC822.HEADER")
    }

    @discardableResult mutating func writeFetchAttribute_rfc822Text() -> Int {
        self.writeString("RFC822.TEXT")
    }
    
    @discardableResult mutating func writeFetchAttribute_preview(_ lazy: Bool) -> Int {
        self.writeString(lazy ? "PREVIEW (LAZY)" : "PREVIEW")
    }

    @discardableResult mutating func writeFetchAttribute_bodyStructure(extensions: Bool) -> Int {
        self.writeString(extensions ? "BODYSTRUCTURE" : "BODY")
    }

    @discardableResult mutating func writeFetchAttribute_body(peek: Bool, section: SectionSpecifier?, partial: ClosedRange<UInt32>?) -> Int {
        self.writeString(peek ? "BODY.PEEK" : "BODY") +
            self.writeSection(section) +
            self.writeIfExists(partial) { (partial) -> Int in
                self.writeByteRange(partial)
            }
    }

    @discardableResult mutating func writeFetchAttribute_binarySize(_ section: SectionSpecifier.Part) -> Int {
        self.writeString("BINARY.SIZE") +
            self.writeSectionBinary(section)
    }

    @discardableResult mutating func writeFetchAttribute_binary(peek: Bool, section: SectionSpecifier.Part, partial: ClosedRange<UInt32>?) -> Int {
        self.writeString("BINARY") +
            self.write(if: peek) {
                self.writeString(".PEEK")
            } +
            self.writeSectionBinary(section) +
            self.writeIfExists(partial) { (partial) -> Int in
                self.writeByteRange(partial)
            }
    }

    @discardableResult mutating func writeFetchAttribute_gmailMessageID() -> Int {
        self.writeString("X-GM-MSGID")
    }

    @discardableResult mutating func writeFetchAttribute_gmailThreadID() -> Int {
        self.writeString("X-GM-THRID")
    }

    @discardableResult mutating func writeFetchAttribute_gmailLabels() -> Int {
        self.writeString("X-GM-LABELS")
    }
}
