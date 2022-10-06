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

class MediaTests: EncodeTestClass {}

// MARK: - init

extension MediaTests {
    func testInit_mediaType() {
        let inputs: [(String, String, String, String, UInt)] = [
            (
                "image", "jpeg", "image", "jpeg", #line
            ),
            (
                "APPLICATION", "PDF", "application", "pdf", #line
            ),
        ]
        for input in inputs {
            let mediaType = Media.MediaType(topLevel: input.0, sub: input.1)
            XCTAssertEqual(String(mediaType.topLevel), input.2, line: input.4)
            XCTAssertEqual(String(mediaType.sub), input.3, line: input.4)
        }
    }

    func testInit_mediaTopLevel() {
        XCTAssertEqual(String(Media.TopLevelType("APPLICATION")), "application")
        XCTAssertEqual(String(Media.TopLevelType("IMAGE")), "image")
    }

    func testInit_mediaSubtype() {
        XCTAssertEqual(String(Media.Subtype("TYPE")), "type")
        XCTAssertEqual(String(Media.Subtype("HTML")), "html")
    }
}

// MARK: - Encoding

extension MediaTests {
    func testEncode_mediaType() {
        let inputs: [(Media.MediaType, String, UInt)] = [
            (.init(topLevel: "text", sub: "html"), #""TEXT" "HTML""#, #line),
            (.init(topLevel: .image, sub: "jpeg"), #""IMAGE" "JPEG""#, #line),
            (.init(topLevel: .application, sub: "pdf"), #""APPLICATION" "PDF""#, #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeMediaType($0) })
    }

    func testEncode_mediaTopLevel() {
        let inputs: [(Media.TopLevelType, String, UInt)] = [
            (.multipart, #""MULTIPART""#, #line),
            (.application, #""APPLICATION""#, #line),
            (.video, #""VIDEO""#, #line),
            (.image, #""IMAGE""#, #line),
            (.audio, #""AUDIO""#, #line),
            (.message, #""MESSAGE""#, #line),
            (.font, #""FONT""#, #line),
            (.init("other"), #""OTHER""#, #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeMediaTopLevelType($0) })
    }

    func testEncode_mediaSubtype() {
        let inputs: [(Media.Subtype, String, UInt)] = [
            (.related, #""RELATED""#, #line),
            (.mixed, #""MIXED""#, #line),
            (.alternative, #""ALTERNATIVE""#, #line),
            (.init("other"), #""OTHER""#, #line),
            (.init("html"), #""HTML""#, #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeMediaSubtype($0) })
    }
}
