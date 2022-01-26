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
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore
import XCTest

class FetchAttributeTests: EncodeTestClass {}

// MARK: - IMAP

extension FetchAttributeTests {
    func testEncode() {
        let inputs: [(FetchAttribute, CommandEncodingOptions, String, UInt)] = [
            (.envelope, .rfc3501, "ENVELOPE", #line),
            (.flags, .rfc3501, "FLAGS", #line),
            (.uid, .rfc3501, "UID", #line),
            (.internalDate, .rfc3501, "INTERNALDATE", #line),
            (.rfc822Header, .rfc3501, "RFC822.HEADER", #line),
            (.rfc822Size, .rfc3501, "RFC822.SIZE", #line),
            (.rfc822Text, .rfc3501, "RFC822.TEXT", #line),
            (.rfc822, .rfc3501, "RFC822", #line),
            (.bodyStructure(extensions: false), .rfc3501, "BODY", #line),
            (.bodyStructure(extensions: true), .rfc3501, "BODYSTRUCTURE", #line),
            (.bodySection(peek: false, .init(kind: .header), nil), .rfc3501, "BODY[HEADER]", #line),
            (.bodySection(peek: true, .init(kind: .header), nil), .rfc3501, "BODY.PEEK[HEADER]", #line),
            (.binarySize(section: [1]), .rfc3501, "BINARY.SIZE[1]", #line),
            (.binary(peek: true, section: [1, 2, 3], partial: nil), .rfc3501, "BINARY.PEEK[1.2.3]", #line),
            (.binary(peek: false, section: [3, 4, 5], partial: nil), .rfc3501, "BINARY[3.4.5]", #line),
            (.modificationSequenceValue(.zero), .rfc3501, "0", #line),
            (.modificationSequenceValue(3), .rfc3501, "3", #line),
            (.modificationSequence, .rfc3501, "MODSEQ", #line),
            (.gmailMessageID, .rfc3501, "X-GM-MSGID", #line),
            (.gmailThreadID, .rfc3501, "X-GM-THRID", #line),
            (.gmailLabels, .rfc3501, "X-GM-LABELS", #line),
        ]
        self.iterateInputs(inputs: inputs.map { ($0, $1, [$2], $3) }, encoder: { self.testBuffer.writeFetchAttribute($0) })
    }

    // Some tests may have empty fields as debug strings should use
    // the logging mode.
    func testCustomDebugStringConvertible() {
        let inputs: [(FetchAttribute, String, UInt)] = [
            (.envelope, "ENVELOPE", #line),
            (.flags, "FLAGS", #line),
            (.uid, "UID", #line),
            (.internalDate, "INTERNALDATE", #line),
            (.rfc822Header, "RFC822.HEADER", #line),
            (.rfc822Size, "RFC822.SIZE", #line),
            (.rfc822Text, "RFC822.TEXT", #line),
            (.rfc822, "RFC822", #line),
            (.bodyStructure(extensions: false), "BODY", #line),
            (.bodyStructure(extensions: true), "BODYSTRUCTURE", #line),
            (.bodySection(peek: false, .init(kind: .header), nil), "BODY[HEADER]", #line),
            (.bodySection(peek: false, .init(kind: .header), nil), "BODY[HEADER]", #line),
            (.bodySection(peek: true, .init(kind: .headerFields(["message-id", "in-reply-to"])), nil), #"BODY.PEEK[HEADER.FIELDS ("∅" "∅")]"#, #line),
            (.binarySize(section: [1]), "BINARY.SIZE[1]", #line),
            (.binary(peek: true, section: [1, 2, 3], partial: nil), "BINARY.PEEK[1.2.3]", #line),
            (.binary(peek: false, section: [3, 4, 5], partial: nil), "BINARY[3.4.5]", #line),
            (.modificationSequenceValue(.zero), "0", #line),
            (.modificationSequenceValue(3), "3", #line),
            (.modificationSequence, "MODSEQ", #line),
            (.gmailMessageID, "X-GM-MSGID", #line),
            (.gmailThreadID, "X-GM-THRID", #line),
            (.gmailLabels, "X-GM-LABELS", #line),
        ]
        for (attr, expected, line) in inputs {
            XCTAssertEqual(String(reflecting: attr), expected, line: line)
        }
    }

    func testEncodeList() {
        let inputs: [([FetchAttribute], CommandEncodingOptions, String, UInt)] = [
            ([.envelope], .rfc3501, "(ENVELOPE)", #line),
            ([.flags, .internalDate, .rfc822Size], .rfc3501, "FAST", #line),
            ([.internalDate, .rfc822Size, .flags], .rfc3501, "FAST", #line),
            ([.flags, .internalDate, .rfc822Size, .envelope], .rfc3501, "ALL", #line),
            ([.rfc822Size, .flags, .envelope, .internalDate], .rfc3501, "ALL", #line),
            ([.flags, .internalDate, .rfc822Size, .envelope, .bodyStructure(extensions: false)], .rfc3501, "FULL", #line),
            ([.flags, .bodyStructure(extensions: false), .rfc822Size, .internalDate, .envelope], .rfc3501, "FULL", #line),
            ([.flags, .bodyStructure(extensions: true), .rfc822Size, .internalDate, .envelope], .rfc3501, "(FLAGS BODYSTRUCTURE RFC822.SIZE INTERNALDATE ENVELOPE)", #line),
            ([.flags, .bodyStructure(extensions: false), .rfc822Size, .internalDate, .envelope, .uid], .rfc3501, "(FLAGS BODY RFC822.SIZE INTERNALDATE ENVELOPE UID)", #line),
            ([.gmailLabels, .gmailMessageID, .gmailThreadID], .rfc3501, "(X-GM-LABELS X-GM-MSGID X-GM-THRID)", #line),
        ]
        self.iterateInputs(inputs: inputs.map { ($0, $1, [$2], $3) }, encoder: { self.testBuffer.writeFetchAttributeList($0) })
    }
}
