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
    @Test(arguments: [
        MediaTypeInitFixture(topLevel: "image", sub: "jpeg", expectedTopLevel: "image", expectedSub: "jpeg"),
        MediaTypeInitFixture(topLevel: "APPLICATION", sub: "PDF", expectedTopLevel: "application", expectedSub: "pdf"),
    ])
    func `media type init normalizes case`(_ fixture: MediaTypeInitFixture) {
        let mediaType = Media.MediaType(topLevel: fixture.topLevel, sub: fixture.sub)
        #expect(String(mediaType.topLevel) == fixture.expectedTopLevel)
        #expect(String(mediaType.sub) == fixture.expectedSub)
    }

    @Test func `top level type init normalizes case`() {
        #expect(String(Media.TopLevelType("APPLICATION")) == "application")
        #expect(String(Media.TopLevelType("IMAGE")) == "image")
    }

    @Test func `subtype init normalizes case`() {
        #expect(String(Media.Subtype("TYPE")) == "type")
        #expect(String(Media.Subtype("HTML")) == "html")
    }

    @Test(arguments: [
        EncodeFixture.mediaType(.init(topLevel: "text", sub: "html"), #""TEXT" "HTML""#),
        EncodeFixture.mediaType(.init(topLevel: .image, sub: "jpeg"), #""IMAGE" "JPEG""#),
        EncodeFixture.mediaType(.init(topLevel: .application, sub: "pdf"), #""APPLICATION" "PDF""#),
    ])
    func `encode media type`(_ fixture: EncodeFixture<Media.MediaType>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        EncodeFixture.topLevelType(.multipart, #""MULTIPART""#),
        EncodeFixture.topLevelType(.application, #""APPLICATION""#),
        EncodeFixture.topLevelType(.video, #""VIDEO""#),
        EncodeFixture.topLevelType(.image, #""IMAGE""#),
        EncodeFixture.topLevelType(.audio, #""AUDIO""#),
        EncodeFixture.topLevelType(.message, #""MESSAGE""#),
        EncodeFixture.topLevelType(.font, #""FONT""#),
        EncodeFixture.topLevelType(.init("other"), #""OTHER""#),
    ])
    func `encode top level type`(_ fixture: EncodeFixture<Media.TopLevelType>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        EncodeFixture.subtype(.related, #""RELATED""#),
        EncodeFixture.subtype(.mixed, #""MIXED""#),
        EncodeFixture.subtype(.alternative, #""ALTERNATIVE""#),
        EncodeFixture.subtype(.init("other"), #""OTHER""#),
        EncodeFixture.subtype(.init("html"), #""HTML""#),
    ])
    func `encode subtype`(_ fixture: EncodeFixture<Media.Subtype>) {
        fixture.checkEncoding()
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
