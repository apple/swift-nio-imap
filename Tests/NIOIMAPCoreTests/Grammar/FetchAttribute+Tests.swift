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
        EncodeFixture.fetchAttribute(.binary(peek: false, section: [1], partial: 3...6), "BINARY[1]<3.4>"),
        EncodeFixture.fetchAttribute(.binary(peek: true, section: [2], partial: 4...8), "BINARY.PEEK[2]<4.5>"),
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

    @Test(
        "custom debug string convertible",
        arguments: [
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
            ReflectionFixture<FetchAttribute>(
                sut: .bodySection(peek: false, .init(kind: .header), nil),
                expected: "BODY[HEADER]"
            ),
            ReflectionFixture<FetchAttribute>(
                sut: .bodySection(peek: false, .init(kind: .header), nil),
                expected: "BODY[HEADER]"
            ),
            ReflectionFixture<FetchAttribute>(
                sut: .bodySection(peek: true, .init(kind: .headerFields(["message-id", "in-reply-to"])), nil),
                expected: #"BODY.PEEK[HEADER.FIELDS ("message-id" "in-reply-to")]"#
            ),
            ReflectionFixture<FetchAttribute>(sut: .binarySize(section: [1]), expected: "BINARY.SIZE[1]"),
            ReflectionFixture<FetchAttribute>(
                sut: .binary(peek: true, section: [1, 2, 3], partial: nil),
                expected: "BINARY.PEEK[1.2.3]"
            ),
            ReflectionFixture<FetchAttribute>(
                sut: .binary(peek: false, section: [3, 4, 5], partial: nil),
                expected: "BINARY[3.4.5]"
            ),
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
        ]
    )
    func customDebugStringConvertible(_ fixture: ReflectionFixture<FetchAttribute>) {
        fixture.check()
    }

    @Test(
        "encode list",
        arguments: [
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
            EncodeFixture.fetchAttributeList(
                [.gmailLabels, .gmailMessageID, .gmailThreadID],
                "(X-GM-LABELS X-GM-MSGID X-GM-THRID)"
            ),
            EncodeFixture.fetchAttributeList([.preview(lazy: false)], "(PREVIEW)"),
            EncodeFixture.fetchAttributeList([.preview(lazy: true)], "(PREVIEW (LAZY))"),
        ]
    )
    func encodeList(_ fixture: EncodeFixture<[FetchAttribute]>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.fetchAttribute("ENVELOPE", " ", expected: .success(.envelope)),
        ParseFixture.fetchAttribute("FLAGS", " ", expected: .success(.flags)),
        ParseFixture.fetchAttribute("INTERNALDATE", " ", expected: .success(.internalDate)),
        ParseFixture.fetchAttribute("RFC822.HEADER", " ", expected: .success(.rfc822Header)),
        ParseFixture.fetchAttribute("RFC822.SIZE", " ", expected: .success(.rfc822Size)),
        ParseFixture.fetchAttribute("RFC822.TEXT", " ", expected: .success(.rfc822Text)),
        ParseFixture.fetchAttribute("RFC822", " ", expected: .success(.rfc822)),
        ParseFixture.fetchAttribute("BODY", " ", expected: .success(.bodyStructure(extensions: false))),
        ParseFixture.fetchAttribute("BODYSTRUCTURE", " ", expected: .success(.bodyStructure(extensions: true))),
        ParseFixture.fetchAttribute("UID", " ", expected: .success(.uid)),
        ParseFixture.fetchAttribute(
            "BODY[1]<1.2>",
            " ",
            expected: .success(.bodySection(peek: false, .init(part: [1], kind: .complete), 1...2 as ClosedRange))
        ),
        ParseFixture.fetchAttribute(
            "BODY[1.TEXT]",
            " ",
            expected: .success(.bodySection(peek: false, .init(part: [1], kind: .text), nil))
        ),
        ParseFixture.fetchAttribute(
            "BODY[4.2.TEXT]",
            " ",
            expected: .success(.bodySection(peek: false, .init(part: [4, 2], kind: .text), nil))
        ),
        ParseFixture.fetchAttribute(
            "BODY[HEADER]",
            " ",
            expected: .success(.bodySection(peek: false, .init(kind: .header), nil))
        ),
        ParseFixture.fetchAttribute(
            "BODY.PEEK[HEADER]<3.4>",
            " ",
            expected: .success(.bodySection(peek: true, .init(kind: .header), 3...6 as ClosedRange))
        ),
        ParseFixture.fetchAttribute(
            "BODY.PEEK[HEADER]",
            " ",
            expected: .success(.bodySection(peek: true, .init(kind: .header), nil))
        ),
        ParseFixture.fetchAttribute(
            "BINARY.PEEK[1]",
            " ",
            expected: .success(.binary(peek: true, section: [1], partial: nil))
        ),
        ParseFixture.fetchAttribute(
            "BINARY.PEEK[1]<3.4>",
            " ",
            expected: .success(.binary(peek: true, section: [1], partial: 3...6 as ClosedRange))
        ),
        ParseFixture.fetchAttribute(
            "BINARY[2]<4.5>",
            " ",
            expected: .success(.binary(peek: false, section: [2], partial: 4...8 as ClosedRange))
        ),
        ParseFixture.fetchAttribute("BINARY.SIZE[5]", " ", expected: .success(.binarySize(section: [5]))),
        ParseFixture.fetchAttribute("X-GM-MSGID", " ", expected: .success(.gmailMessageID)),
        ParseFixture.fetchAttribute("X-GM-THRID", " ", expected: .success(.gmailThreadID)),
        ParseFixture.fetchAttribute("X-GM-LABELS", " ", expected: .success(.gmailLabels)),
        ParseFixture.fetchAttribute("MODSEQ", " ", expected: .success(.modificationSequence)),
        ParseFixture.fetchAttribute("PREVIEW", " ", expected: .success(.preview(lazy: false))),
        ParseFixture.fetchAttribute("PREVIEW (LAZY)", " ", expected: .success(.preview(lazy: true))),
        ParseFixture.fetchAttribute("EMAILID", " ", expected: .success(.emailID)),
        ParseFixture.fetchAttribute("THREADID", " ", expected: .success(.threadID)),
    ])
    func parse(_ fixture: ParseFixture<FetchAttribute>) {
        fixture.checkParsing()
    }

    @Test(
        "parse partial",
        arguments: [
            ParseFixture.partial("<0.1000000000>", expected: .success(ClosedRange(uncheckedBounds: (0, 999_999_999)))),
            ParseFixture.partial(
                "<0.4294967290>",
                expected: .success(ClosedRange(uncheckedBounds: (0, 4_294_967_289)))
            ),
            ParseFixture.partial("<1.2>", expected: .success(ClosedRange(uncheckedBounds: (1, 2)))),
            ParseFixture.partial(
                "<4294967290.2>",
                expected: .success(ClosedRange(uncheckedBounds: (4_294_967_290, 4_294_967_291)))
            ),
            ParseFixture.partial("<0.0>", expected: .failure),
            ParseFixture.partial("<654.0>", expected: .failure),
            ParseFixture.partial("<4294967296.2>", expected: .failure),
            ParseFixture.partial("<4294967294.2>", expected: .failure),
            ParseFixture.partial("<2.4294967294>", expected: .failure),
            ParseFixture.partial("<4294967000.4294967000>", expected: .failure),
            ParseFixture.partial("<2200000000.2200000000>", expected: .failure),
            ParseFixture.partial("<", "", expected: .incompleteMessage),
            ParseFixture.partial("<111111111", "", expected: .incompleteMessage),
            ParseFixture.partial("<1.", "", expected: .incompleteMessage),
            ParseFixture.partial("<1.22222222", "", expected: .incompleteMessage),
        ]
    )
    func parsePartial(_ fixture: ParseFixture<ClosedRange<UInt32>>) {
        fixture.checkParsing()
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

extension ParseFixture<FetchAttribute> {
    fileprivate static func fetchAttribute(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseFetchAttribute
        )
    }
}

extension ParseFixture<ClosedRange<UInt32>> {
    fileprivate static func partial(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parsePartial
        )
    }
}
