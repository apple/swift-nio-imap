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
import Testing

@Suite("FetchAttribute")
struct FetchAttributeTests {
    @Test(arguments: [
        EncodeFixture.fetchAttribute(.envelope, "ENVELOPE"),
        EncodeFixture.fetchAttribute(.flags, "FLAGS"),
        EncodeFixture.fetchAttribute(.uid, "UID"),
        EncodeFixture.fetchAttribute(.internalDate, "INTERNALDATE"),
        EncodeFixture.fetchAttribute(.rfc822Header, "RFC822.HEADER"),
        EncodeFixture.fetchAttribute(.rfc822Size, "RFC822.SIZE"),
        EncodeFixture.fetchAttribute(.rfc822Text, "RFC822.TEXT"),
        EncodeFixture.fetchAttribute(.rfc822, "RFC822"),
        EncodeFixture.fetchAttribute(.bodyStructure(extensions: false), "BODY"),
        EncodeFixture.fetchAttribute(.bodyStructure(extensions: true), "BODYSTRUCTURE"),
        EncodeFixture.fetchAttribute(.bodySection(peek: false, .init(kind: .header), nil), "BODY[HEADER]"),
        EncodeFixture.fetchAttribute(.bodySection(peek: true, .init(kind: .header), nil), "BODY.PEEK[HEADER]"),
        EncodeFixture.fetchAttribute(.binarySize(section: [1]), "BINARY.SIZE[1]"),
        EncodeFixture.fetchAttribute(.binary(peek: true, section: [1, 2, 3], partial: nil), "BINARY.PEEK[1.2.3]"),
        EncodeFixture.fetchAttribute(.binary(peek: false, section: [3, 4, 5], partial: nil), "BINARY[3.4.5]"),
        EncodeFixture.fetchAttribute(.modificationSequenceValue(.zero), "0"),
        EncodeFixture.fetchAttribute(.modificationSequenceValue(3), "3"),
        EncodeFixture.fetchAttribute(.modificationSequence, "MODSEQ"),
        EncodeFixture.fetchAttribute(.gmailMessageID, "X-GM-MSGID"),
        EncodeFixture.fetchAttribute(.gmailThreadID, "X-GM-THRID"),
        EncodeFixture.fetchAttribute(.gmailLabels, "X-GM-LABELS"),
        EncodeFixture.fetchAttribute(.preview(lazy: false), "PREVIEW"),
        EncodeFixture.fetchAttribute(.preview(lazy: true), "PREVIEW (LAZY)"),
        EncodeFixture.fetchAttribute(.emailID, "EMAILID"),
        EncodeFixture.fetchAttribute(.threadID, "THREADID"),
    ])
    func encode(_ fixture: EncodeFixture<FetchAttribute>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ReflectionFixture<FetchAttribute>(sut: .envelope, expected: "ENVELOPE"),
        ReflectionFixture<FetchAttribute>(sut: .flags, expected: "FLAGS"),
        ReflectionFixture<FetchAttribute>(sut: .uid, expected: "UID"),
        ReflectionFixture<FetchAttribute>(sut: .internalDate, expected: "INTERNALDATE"),
        ReflectionFixture<FetchAttribute>(sut: .rfc822Header, expected: "RFC822.HEADER"),
        ReflectionFixture<FetchAttribute>(sut: .rfc822Size, expected: "RFC822.SIZE"),
        ReflectionFixture<FetchAttribute>(sut: .rfc822Text, expected: "RFC822.TEXT"),
        ReflectionFixture<FetchAttribute>(sut: .rfc822, expected: "RFC822"),
        ReflectionFixture<FetchAttribute>(sut: .bodyStructure(extensions: false), expected: "BODY"),
        ReflectionFixture<FetchAttribute>(sut: .bodyStructure(extensions: true), expected: "BODYSTRUCTURE"),
        ReflectionFixture<FetchAttribute>(sut: .bodySection(peek: false, .init(kind: .header), nil), expected: "BODY[HEADER]"),
        ReflectionFixture<FetchAttribute>(sut: .bodySection(peek: false, .init(kind: .header), nil), expected: "BODY[HEADER]"),
        ReflectionFixture<FetchAttribute>(
            sut: .bodySection(peek: true, .init(kind: .headerFields(["message-id", "in-reply-to"])), nil),
            expected: #"BODY.PEEK[HEADER.FIELDS ("message-id" "in-reply-to")]"#
        ),
        ReflectionFixture<FetchAttribute>(sut: .binarySize(section: [1]), expected: "BINARY.SIZE[1]"),
        ReflectionFixture<FetchAttribute>(sut: .binary(peek: true, section: [1, 2, 3], partial: nil), expected: "BINARY.PEEK[1.2.3]"),
        ReflectionFixture<FetchAttribute>(sut: .binary(peek: false, section: [3, 4, 5], partial: nil), expected: "BINARY[3.4.5]"),
        ReflectionFixture<FetchAttribute>(sut: .modificationSequenceValue(.zero), expected: "0"),
        ReflectionFixture<FetchAttribute>(sut: .modificationSequenceValue(3), expected: "3"),
        ReflectionFixture<FetchAttribute>(sut: .modificationSequence, expected: "MODSEQ"),
        ReflectionFixture<FetchAttribute>(sut: .gmailMessageID, expected: "X-GM-MSGID"),
        ReflectionFixture<FetchAttribute>(sut: .gmailThreadID, expected: "X-GM-THRID"),
        ReflectionFixture<FetchAttribute>(sut: .gmailLabels, expected: "X-GM-LABELS"),
        ReflectionFixture<FetchAttribute>(sut: .preview(lazy: false), expected: "PREVIEW"),
        ReflectionFixture<FetchAttribute>(sut: .preview(lazy: true), expected: "PREVIEW (LAZY)"),
        ReflectionFixture<FetchAttribute>(sut: .emailID, expected: "EMAILID"),
        ReflectionFixture<FetchAttribute>(sut: .threadID, expected: "THREADID"),
    ])
    func `custom debug string convertible`(_ fixture: ReflectionFixture<FetchAttribute>) {
        fixture.check()
    }

    @Test(arguments: [
        EncodeFixture.fetchAttributeList([.envelope], "(ENVELOPE)"),
        EncodeFixture.fetchAttributeList([.flags, .internalDate, .rfc822Size], "FAST"),
        EncodeFixture.fetchAttributeList([.internalDate, .rfc822Size, .flags], "FAST"),
        EncodeFixture.fetchAttributeList([.flags, .internalDate, .rfc822Size, .envelope], "ALL"),
        EncodeFixture.fetchAttributeList([.rfc822Size, .flags, .envelope, .internalDate], "ALL"),
        EncodeFixture.fetchAttributeList(
            [.flags, .internalDate, .rfc822Size, .envelope, .bodyStructure(extensions: false)],
            "FULL"
        ),
        EncodeFixture.fetchAttributeList(
            [.flags, .bodyStructure(extensions: false), .rfc822Size, .internalDate, .envelope],
            "FULL"
        ),
        EncodeFixture.fetchAttributeList(
            [.flags, .bodyStructure(extensions: true), .rfc822Size, .internalDate, .envelope],
            "(FLAGS BODYSTRUCTURE RFC822.SIZE INTERNALDATE ENVELOPE)"
        ),
        EncodeFixture.fetchAttributeList(
            [.flags, .bodyStructure(extensions: false), .rfc822Size, .internalDate, .envelope, .uid],
            "(FLAGS BODY RFC822.SIZE INTERNALDATE ENVELOPE UID)"
        ),
        EncodeFixture.fetchAttributeList([.gmailLabels, .gmailMessageID, .gmailThreadID], "(X-GM-LABELS X-GM-MSGID X-GM-THRID)"),
        EncodeFixture.fetchAttributeList([.preview(lazy: false)], "(PREVIEW)"),
        EncodeFixture.fetchAttributeList([.preview(lazy: true)], "(PREVIEW (LAZY))"),
    ])
    func `encode list`(_ fixture: EncodeFixture<[FetchAttribute]>) {
        fixture.checkEncoding()
    }
}

// MARK: -

struct ReflectionFixture<T: Sendable>: Sendable, CustomTestStringConvertible {
    let sut: T
    let expected: String

    var testDescription: String { expected }

    func check() {
        #expect(String(reflecting: sut) == expected)
    }
}

extension EncodeFixture<FetchAttribute> {
    fileprivate static func fetchAttribute(
        _ input: FetchAttribute,
        _ expectedString: String,
        options: CommandEncodingOptions = CommandEncodingOptions()
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .client(options),
            expectedString: expectedString,
            encoder: { $0.writeFetchAttribute($1) }
        )
    }
}

extension EncodeFixture<[FetchAttribute]> {
    fileprivate static func fetchAttributeList(
        _ input: [FetchAttribute],
        _ expectedString: String,
        options: CommandEncodingOptions = CommandEncodingOptions()
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .client(options),
            expectedString: expectedString,
            encoder: { $0.writeFetchAttributeList($1) }
        )
    }
}
