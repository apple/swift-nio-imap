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

@Suite("Media")
struct MediaTests {
    @Test(
        "media type init normalizes case",
        arguments: [
            MediaTypeInitFixture(topLevel: "image", sub: "jpeg", expectedTopLevel: "image", expectedSub: "jpeg"),
            MediaTypeInitFixture(
                topLevel: "APPLICATION",
                sub: "PDF",
                expectedTopLevel: "application",
                expectedSub: "pdf"
            )
        ]
    )
    func mediaTypeInitNormalizesCase(_ fixture: MediaTypeInitFixture) {
        let mediaType = Media.MediaType(topLevel: fixture.topLevel, sub: fixture.sub)
        #expect(String(mediaType.topLevel) == fixture.expectedTopLevel)
        #expect(String(mediaType.sub) == fixture.expectedSub)
    }

    @Test("top level type init normalizes case")
    func topLevelTypeInitNormalizesCase() {
        #expect(String(Media.TopLevelType("APPLICATION")) == "application")
        #expect(String(Media.TopLevelType("IMAGE")) == "image")
    }

    @Test("subtype init normalizes case")
    func subtypeInitNormalizesCase() {
        #expect(String(Media.Subtype("TYPE")) == "type")
        #expect(String(Media.Subtype("HTML")) == "html")
    }

    @Test(
        "encode media type",
        arguments: [
            EncodeFixture.mediaType(.init(topLevel: "text", sub: "html"), #""TEXT" "HTML""#),
            EncodeFixture.mediaType(.init(topLevel: .image, sub: "jpeg"), #""IMAGE" "JPEG""#),
            EncodeFixture.mediaType(.init(topLevel: .application, sub: "pdf"), #""APPLICATION" "PDF""#)
        ]
    )
    func encodeMediaType(_ fixture: EncodeFixture<Media.MediaType>) {
        fixture.checkEncoding()
    }

    @Test(
        "encode top level type",
        arguments: [
            EncodeFixture.topLevelType(.multipart, #""MULTIPART""#),
            EncodeFixture.topLevelType(.application, #""APPLICATION""#),
            EncodeFixture.topLevelType(.video, #""VIDEO""#),
            EncodeFixture.topLevelType(.image, #""IMAGE""#),
            EncodeFixture.topLevelType(.audio, #""AUDIO""#),
            EncodeFixture.topLevelType(.message, #""MESSAGE""#),
            EncodeFixture.topLevelType(.font, #""FONT""#),
            EncodeFixture.topLevelType(.init("other"), #""OTHER""#)
        ]
    )
    func encodeTopLevelType(_ fixture: EncodeFixture<Media.TopLevelType>) {
        fixture.checkEncoding()
    }

    @Test(
        "encode subtype",
        arguments: [
            EncodeFixture.subtype(.related, #""RELATED""#),
            EncodeFixture.subtype(.mixed, #""MIXED""#),
            EncodeFixture.subtype(.alternative, #""ALTERNATIVE""#),
            EncodeFixture.subtype(.init("other"), #""OTHER""#),
            EncodeFixture.subtype(.init("html"), #""HTML""#)
        ]
    )
    func encodeSubtype(_ fixture: EncodeFixture<Media.Subtype>) {
        fixture.checkEncoding()
    }

    @Test(
        "parse media type",
        arguments: [
            ParseFixture.mediaType(
                #""APPLICATION" "mixed""#,
                expected: .success(Media.MediaType(topLevel: .application, sub: .mixed))
            ),
            ParseFixture.mediaType(
                #""STRING" "related""#,
                expected: .success(Media.MediaType(topLevel: .init("STRING"), sub: .related))
            ),
            ParseFixture.mediaType(#"hey "something""#, "\r", expected: .failureIgnoringBufferModifications)
        ]
    )
    func parseMediaType(_ fixture: ParseFixture<Media.MediaType>) {
        fixture.checkParsing()
    }

    @Test(
        "parse media message",
        arguments: [
            ParseFixture.mediaMessage(#""MESSAGE" "RFC822""#, expected: .success(.rfc822)),
            ParseFixture.mediaMessage(#""messAGE" "RfC822""#, expected: .success(.rfc822)),
            ParseFixture.mediaMessage(
                "abcdefghijklmnopqrstuvwxyz\n",
                "\n",
                expected: .failureIgnoringBufferModifications
            ),
            ParseFixture.mediaMessage(#""messAGE""#, "", expected: .incompleteMessageIgnoringBufferModifications)
        ]
    )
    func parseMediaMessage(_ fixture: ParseFixture<Media.Subtype>) {
        fixture.checkParsing()
    }

    @Test(
        "parse media text",
        arguments: [
            ParseFixture.mediaText(#""TEXT" "something""#, "\n", expected: .success("something")),
            ParseFixture.mediaText(#""TExt" "something""#, "\n", expected: .success("something")),
            ParseFixture.mediaText(#"TEXT "something"\n"#, "\n", expected: .failureIgnoringBufferModifications),
            ParseFixture.mediaText(#""TEXT""#, "", expected: .incompleteMessageIgnoringBufferModifications)
        ]
    )
    func parseMediaText(_ fixture: ParseFixture<Media.Subtype>) {
        fixture.checkParsing()
    }
}

// MARK: -

struct MediaTypeInitFixture: Sendable, CustomTestStringConvertible {
    let topLevel: String
    let sub: String
    let expectedTopLevel: String
    let expectedSub: String

    var testDescription: String { "\(topLevel)/\(sub) → \(expectedTopLevel)/\(expectedSub)" }
}

extension EncodeFixture<Media.MediaType> {
    fileprivate static func mediaType(
        _ input: Media.MediaType,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeMediaType($1) }
        )
    }
}

extension EncodeFixture<Media.TopLevelType> {
    fileprivate static func topLevelType(
        _ input: Media.TopLevelType,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeMediaTopLevelType($1) }
        )
    }
}

extension EncodeFixture<Media.Subtype> {
    fileprivate static func subtype(
        _ input: Media.Subtype,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeMediaSubtype($1) }
        )
    }
}

extension ParseFixture<Media.MediaType> {
    fileprivate static func mediaType(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseMediaType
        )
    }
}

extension ParseFixture<Media.Subtype> {
    fileprivate static func mediaMessage(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseMediaMessage
        )
    }

    fileprivate static func mediaText(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseMediaText
        )
    }
}
