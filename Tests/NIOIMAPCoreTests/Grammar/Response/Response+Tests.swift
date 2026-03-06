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

@Suite("Response")
private struct ResponseTests {
    @Test(
        "encode single response",
        arguments: [
            EncodeFixture.response(
                .idleStarted,
                expectedString: "+ idling\r\n"
            ),
            EncodeFixture.response(
                .authenticationChallenge("hello"),
                expectedString: "+ aGVsbG8=\r\n"
            ),
            EncodeFixture.response(
                .fatal(.init(text: "Oh no you're dead")),
                expectedString: "* BYE Oh no you're dead\r\n"
            ),
            EncodeFixture.response(
                .tagged(.init(tag: "A1", state: .ok(.init(text: "NOOP complete")))),
                expectedString: "A1 OK NOOP complete\r\n"
            ),
            EncodeFixture.response(
                .untagged(.id([:])),
                expectedString: "* ID NIL\r\n"
            ),
            EncodeFixture.response(
                .fetch(.start(1)),
                expectedString: "* 1 FETCH ("
            ),
        ]
    )
    func encodeSingleResponse(_ fixture: EncodeFixture<Response>) {
        fixture.checkEncoding()
    }

    @Test(
        "encode multiple fetch responses",
        arguments: [
            EncodeFixture.fetchResponses(
                [.start(1), .simpleAttribute(.rfc822Size(123)), .finish],
                expectedString: "* 1 FETCH (RFC822.SIZE 123)\r\n"
            ),
            EncodeFixture.fetchResponses(
                [.startUID(1), .simpleAttribute(.rfc822Size(123)), .finish],
                expectedString: "* 1 UIDFETCH (RFC822.SIZE 123)\r\n"
            ),
            EncodeFixture.fetchResponses(
                [.start(2), .simpleAttribute(.uid(123)), .simpleAttribute(.rfc822Size(456)), .finish],
                expectedString: "* 2 FETCH (UID 123 RFC822.SIZE 456)\r\n"
            ),
            EncodeFixture.fetchResponses(
                [
                    .start(3), .simpleAttribute(.uid(123)), .streamingBegin(kind: .rfc822Text, byteCount: 0),
                    .streamingEnd, .simpleAttribute(.uid(456)), .finish,
                ],
                expectedString: "* 3 FETCH (UID 123 RFC822.TEXT {0}\r\n UID 456)\r\n"
            ),
            EncodeFixture.fetchResponses(
                [
                    .start(3), .simpleAttribute(.uid(123)), .streamingBegin(kind: .rfc822Header, byteCount: 0),
                    .streamingEnd, .simpleAttribute(.uid(456)), .finish,
                ],
                expectedString: "* 3 FETCH (UID 123 RFC822.HEADER {0}\r\n UID 456)\r\n"
            ),
            EncodeFixture.fetchResponses(
                [
                    .start(87), .simpleAttribute(.nilBody(.body(section: .init(part: [4], kind: .text), offset: nil))),
                    .simpleAttribute(.uid(123)), .finish,
                ],
                expectedString: "* 87 FETCH (BODY[4.TEXT] NIL UID 123)\r\n"
            ),
            EncodeFixture.fetchResponses(
                [
                    .startUID(87),
                    .simpleAttribute(.nilBody(.body(section: .init(part: [4], kind: .text), offset: nil))),
                    .simpleAttribute(.uid(123)), .finish,
                ],
                expectedString: "* 87 UIDFETCH (BODY[4.TEXT] NIL UID 123)\r\n"
            ),
        ]
    )
    func encodeMultipleFetchResponses(_ fixture: EncodeFixture<[FetchResponse]>) {
        fixture.checkEncoding()
    }

    @Test(
        "StreamingKind custom debug string",
        arguments: [
            DebugStringFixture(sut: StreamingKind.body(section: .init(), offset: nil), expected: "BODY[]"),
            DebugStringFixture(sut: StreamingKind.body(section: .init(), offset: 1234), expected: "BODY[]<1234>"),
            DebugStringFixture(
                sut: StreamingKind.body(section: .init(part: [2, 3], kind: .header), offset: 1234),
                expected: "BODY[2.3.HEADER]<1234>"
            ),
            DebugStringFixture(sut: StreamingKind.rfc822, expected: "RFC822"),
            DebugStringFixture(sut: StreamingKind.rfc822Text, expected: "RFC822.TEXT"),
            DebugStringFixture(sut: StreamingKind.rfc822Header, expected: "RFC822.HEADER"),
        ]
    )
    func streamingKindCustomDebugString(_ fixture: DebugStringFixture<StreamingKind>) {
        fixture.check()
    }

    @Test(
        "Response reflection string",
        arguments: [
            ReflectionFixture(sut: Response.idleStarted, expected: "+ idling\r\n"),
            ReflectionFixture(sut: Response.authenticationChallenge("hello"), expected: "+ aGVsbG8=\r\n"),
            ReflectionFixture(
                sut: Response.fatal(.init(text: "Oh no you're dead")),
                expected: "* BYE Oh no you're dead\r\n"
            ),
            ReflectionFixture(
                sut: Response.tagged(.init(tag: "A1", state: .ok(.init(text: "NOOP complete")))),
                expected: "A1 OK NOOP complete\r\n"
            ),
            ReflectionFixture(sut: Response.untagged(.id([:])), expected: "* ID NIL\r\n"),
            ReflectionFixture(sut: Response.fetch(.start(1)), expected: "* 1 FETCH ("),
            ReflectionFixture(sut: Response.fetch(.simpleAttribute(.uid(123))), expected: "UID 123"),
            ReflectionFixture(
                sut: Response.fetch(.streamingBegin(kind: .rfc822Text, byteCount: 0)),
                expected: "RFC822.TEXT {0}\r\n"
            ),
            ReflectionFixture(sut: Response.fetch(.streamingBytes(ByteBuffer(string: "hello"))), expected: "hello"),
            ReflectionFixture(sut: Response.fetch(.finish), expected: ")\r\n"),
        ]
    )
    func responseReflectionString(_ fixture: ReflectionFixture<Response>) {
        fixture.check()
    }

    @Test(
        "Response PII filtering",
        arguments: [
            PIIFixture(input: .idleStarted, expected: "+ idling\r\n"),
            PIIFixture(input: .authenticationChallenge("hello"), expected: "+ [8 bytes]\r\n"),
            PIIFixture(input: .fatal(.init(text: "Oh no you're dead")), expected: "* BYE Oh no you're dead\r\n"),
            PIIFixture(
                input: .tagged(.init(tag: "A1", state: .ok(.init(text: "NOOP complete")))),
                expected: "A1 OK NOOP complete\r\n"
            ),
            PIIFixture(input: .untagged(.id([:])), expected: "* ID NIL\r\n"),
            PIIFixture(input: .fetch(.start(1)), expected: "* 1 FETCH ("),
            PIIFixture(input: .fetch(.simpleAttribute(.uid(123))), expected: "UID 123"),
            PIIFixture(
                input: .fetch(.streamingBegin(kind: .rfc822Text, byteCount: 0)),
                expected: "RFC822.TEXT {0}\r\n"
            ),
            PIIFixture(input: .fetch(.streamingBytes(ByteBuffer(string: "hello"))), expected: "[5 bytes]"),
            PIIFixture(input: .fetch(.finish), expected: ")\r\n"),
        ]
    )
    func responsePIIFiltering(_ fixture: PIIFixture) {
        #expect(
            Response.descriptionWithoutPII([fixture.input]).mappingControlPictures()
                == fixture.expected.mappingControlPictures()
        )
    }

    @Test(
        "Response tag property",
        arguments: [
            ResponseTagFixture(response: .untagged(.id([:])), expectedTag: nil),
            ResponseTagFixture(response: .fetch(.start(1)), expectedTag: nil),
            ResponseTagFixture(response: .fatal(.init(text: "fatal")), expectedTag: nil),
            ResponseTagFixture(response: .authenticationChallenge("data"), expectedTag: nil),
            ResponseTagFixture(response: .idleStarted, expectedTag: nil),
            ResponseTagFixture(
                response: .tagged(.init(tag: "A1", state: .ok(.init(text: "ok")))),
                expectedTag: "A1"
            ),
        ] as [ResponseTagFixture]
    )
    func responseTag(_ fixture: ResponseTagFixture) {
        #expect(fixture.response.tag == fixture.expectedTag)
    }

    @Test(
        "StreamingKind sectionSpecifier",
        arguments: [
            StreamingKindSectionSpecifierFixture(
                kind: .binary(section: [1, 2], offset: nil),
                expected: SectionSpecifier(part: [1, 2], kind: .text)
            ),
            StreamingKindSectionSpecifierFixture(
                kind: .body(section: SectionSpecifier(part: [3], kind: .header), offset: nil),
                expected: SectionSpecifier(part: [3], kind: .header)
            ),
            StreamingKindSectionSpecifierFixture(
                kind: .rfc822,
                expected: SectionSpecifier()
            ),
            StreamingKindSectionSpecifierFixture(
                kind: .rfc822Text,
                expected: SectionSpecifier(part: [], kind: .text)
            ),
            StreamingKindSectionSpecifierFixture(
                kind: .rfc822Header,
                expected: SectionSpecifier(part: [], kind: .header)
            ),
        ] as [StreamingKindSectionSpecifierFixture]
    )
    func streamingKindSectionSpecifier(_ fixture: StreamingKindSectionSpecifierFixture) {
        #expect(fixture.kind.sectionSpecifier == fixture.expected)
    }

    @Test(
        "StreamingKind offset",
        arguments: [
            StreamingKindOffsetFixture(kind: .binary(section: [1], offset: 42), expected: 42),
            StreamingKindOffsetFixture(kind: .binary(section: [1], offset: nil), expected: nil),
            StreamingKindOffsetFixture(kind: .body(section: SectionSpecifier(), offset: 10), expected: 10),
            StreamingKindOffsetFixture(kind: .body(section: SectionSpecifier(), offset: nil), expected: nil),
            StreamingKindOffsetFixture(kind: .rfc822, expected: nil),
            StreamingKindOffsetFixture(kind: .rfc822Text, expected: nil),
            StreamingKindOffsetFixture(kind: .rfc822Header, expected: nil),
        ] as [StreamingKindOffsetFixture]
    )
    func streamingKindOffset(_ fixture: StreamingKindOffsetFixture) {
        #expect(fixture.kind.offset == fixture.expected)
    }
}

// MARK: -

extension EncodeFixture<Response> {
    fileprivate static func response(
        _ input: Response,
        expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .server(ResponseEncodingOptions()),
            expectedString: expectedString,
            encoder: {
                var encoder = ResponseEncodeBuffer(
                    buffer: $0.buffer,
                    options: ResponseEncodingOptions(),
                    loggingMode: false
                )
                let count = encoder.writeResponse($1)
                $0 = encoder.buffer
                return count
            }
        )
    }
}

extension EncodeFixture<[FetchResponse]> {
    fileprivate static func fetchResponses(
        _ input: [FetchResponse],
        expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .client(.rfc3501),
            expectedString: expectedString,
            encoder: {
                var encoder = ResponseEncodeBuffer(
                    buffer: $0.buffer,
                    options: ResponseEncodingOptions(),
                    loggingMode: false
                )
                let count = $1.reduce(into: 0) { count, response in
                    count += encoder.writeFetchResponse(response)
                }
                $0 = encoder.buffer
                return count
            }
        )
    }
}

private struct PIIFixture: Sendable, CustomTestStringConvertible {
    let input: Response
    let expected: String

    var testDescription: String { expected.mappingControlPictures() }
}

private struct ResponseTagFixture: Sendable, CustomTestStringConvertible {
    let response: Response
    let expectedTag: String?

    var testDescription: String { expectedTag ?? "(nil)" }
}

private struct StreamingKindSectionSpecifierFixture: Sendable, CustomTestStringConvertible {
    let kind: StreamingKind
    let expected: SectionSpecifier

    var testDescription: String { "\(kind)" }
}

private struct StreamingKindOffsetFixture: Sendable, CustomTestStringConvertible {
    let kind: StreamingKind
    let expected: Int?

    var testDescription: String { "\(kind)" }
}
