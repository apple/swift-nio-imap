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
@testable import NIOIMAPCore
import XCTest

class BodyStructure_Tests: EncodeTestClass {}

// MARK: - init

extension BodyStructure_Tests {
    func testInit_mediaSubtype() {
        let type = BodyStructure.MediaSubtype("TYPE")
        XCTAssertEqual(type._backing, "type")
    }
}

// MARK: - Encoding

extension BodyStructure_Tests {
    func testEncode_mediaSubtype() {
        let inputs: [(BodyStructure.MediaSubtype, String, UInt)] = [
            (.related, #""multipart/related""#, #line),
            (.mixed, #""multipart/mixed""#, #line),
            (.alternative, #""multipart/alternative""#, #line),
            (.init("other"), #""other""#, #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeMediaSubtype($0) })
    }
}

// MARK: - RandomAccessCollection

extension BodyStructure_Tests {
    func testRandomeAccessCollection_startIndex() {
        let inputs: [(BodyStructure, SectionSpecifier.Part, UInt)] = [
            (
                .singlepart(.init(type: .basic(.init(type: .audio, subtype: .alternative)), fields: .init(parameter: [], id: nil, description: nil, encoding: .binary, octetCount: 0))),
                [1],
                #line
            ),
            (
                .multipart(.init(parts: [
                    .singlepart(.init(type: .basic(.init(type: .application, subtype: .mixed)), fields: .init(parameter: [], id: nil, description: nil, encoding: .base64, octetCount: 1))),
                ], mediaSubtype: .mixed)),
                [1],
                #line
            ),
        ]
        inputs.forEach { (input, expected, line) in
            XCTAssertEqual(input.startIndex, expected, line: line)
        }
    }

    func testRandomeAccessCollection_endIndex() {
        let inputs: [(BodyStructure, SectionSpecifier.Part, UInt)] = [
            (
                .singlepart(.init(type: .basic(.init(type: .audio, subtype: .alternative)), fields: .init(parameter: [], id: nil, description: nil, encoding: .binary, octetCount: 0))),
                [2],
                #line
            ),
            (
                .singlepart(.init(type: .message(.init(
                    message: .rfc822,
                    envelope: .init(date: nil, subject: nil, from: [], sender: [], reply: [], to: [], cc: [], bcc: [], inReplyTo: nil, messageID: nil),
                    body: .singlepart(.init(
                        type: .basic(.init(type: .application, subtype: .mixed)),
                        fields: .init(parameter: [], id: nil, description: nil, encoding: .base64, octetCount: 0)
                    )
                    ),
                    fieldLines: 3
                )), fields: .init(parameter: [], id: nil, description: nil, encoding: .binary, octetCount: 0))),
                [2],
                #line
            ),
            (
                .multipart(BodyStructure.Multipart(parts: [
                    .singlepart(.init(type: .basic(.init(type: .audio, subtype: .mixed)), fields: .init(parameter: [], id: nil, description: nil, encoding: .base64, octetCount: 0))),
                ], mediaSubtype: .mixed)),
                [2],
                #line
            ),
            (
                .multipart(BodyStructure.Multipart(parts: [
                    .singlepart(.init(type: .basic(.init(type: .audio, subtype: .mixed)), fields: .init(parameter: [], id: nil, description: nil, encoding: .base64, octetCount: 0))),
                    .singlepart(.init(type: .basic(.init(type: .audio, subtype: .mixed)), fields: .init(parameter: [], id: nil, description: nil, encoding: .base64, octetCount: 0))),
                    .singlepart(.init(type: .basic(.init(type: .audio, subtype: .mixed)), fields: .init(parameter: [], id: nil, description: nil, encoding: .base64, octetCount: 0))),
                ], mediaSubtype: .mixed)),
                [4],
                #line
            ),
        ]
        inputs.forEach { (input, expected, line) in
            XCTAssertEqual(input.endIndex, expected, line: line)
        }
    }

    func testRandomeAccessCollection_indexBefore() {
        let inputs: [(BodyStructure, SectionSpecifier.Part, SectionSpecifier.Part, UInt)] = [
            (
                .singlepart(.init(type: .basic(.init(type: .audio, subtype: .alternative)), fields: .init(parameter: [], id: nil, description: nil, encoding: .binary, octetCount: 0))),
                [2],
                [1],
                #line
            ),
            (
                .multipart(BodyStructure.Multipart(parts: [
                    .singlepart(.init(type: .basic(.init(type: .audio, subtype: .mixed)), fields: .init(parameter: [], id: nil, description: nil, encoding: .base64, octetCount: 0))),
                    .singlepart(.init(type: .basic(.init(type: .audio, subtype: .mixed)), fields: .init(parameter: [], id: nil, description: nil, encoding: .base64, octetCount: 0))),
                    .singlepart(.init(type: .basic(.init(type: .audio, subtype: .mixed)), fields: .init(parameter: [], id: nil, description: nil, encoding: .base64, octetCount: 0))),
                ], mediaSubtype: .mixed)),
                [3],
                [2],
                #line
            ),
        ]
        inputs.forEach { (body, before, expected, line) in
            XCTAssertEqual(body.index(before: before), expected, line: line)
        }
    }

    func testRandomeAccessCollection_indexAfter() {
        let inputs: [(BodyStructure, SectionSpecifier.Part, SectionSpecifier.Part, UInt)] = [
            (
                .singlepart(.init(type: .basic(.init(type: .audio, subtype: .alternative)), fields: .init(parameter: [], id: nil, description: nil, encoding: .binary, octetCount: 0))),
                [1],
                [2],
                #line
            ),
            (
                .multipart(BodyStructure.Multipart(parts: [
                    .singlepart(.init(type: .basic(.init(type: .audio, subtype: .mixed)), fields: .init(parameter: [], id: nil, description: nil, encoding: .base64, octetCount: 0))),
                    .singlepart(.init(type: .basic(.init(type: .audio, subtype: .mixed)), fields: .init(parameter: [], id: nil, description: nil, encoding: .base64, octetCount: 0))),
                    .singlepart(.init(type: .basic(.init(type: .audio, subtype: .mixed)), fields: .init(parameter: [], id: nil, description: nil, encoding: .base64, octetCount: 0))),
                ], mediaSubtype: .mixed)),
                [2],
                [3],
                #line
            ),
        ]
        inputs.forEach { (body, after, expected, line) in
            XCTAssertEqual(body.index(after: after), expected, line: line)
        }
    }

    func testRandomeAccessCollection_position() {
        let inputs: [(BodyStructure, SectionSpecifier.Part, BodyStructure, UInt)] = [
            (
                .singlepart(.init(type: .basic(.init(type: .audio, subtype: .alternative)), fields: .init(parameter: [], id: nil, description: nil, encoding: .binary, octetCount: 0))),
                [1],
                .singlepart(.init(type: .basic(.init(type: .audio, subtype: .alternative)), fields: .init(parameter: [], id: nil, description: nil, encoding: .binary, octetCount: 0))),
                #line
            ),
            (
                .singlepart(.init(type: .text(.init(mediaText: "media", lineCount: 3)), fields: BodyStructure.Fields(parameter: [], id: nil, description: nil, encoding: .binary, octetCount: 123))),
                [1],
                .singlepart(.init(type: .text(.init(mediaText: "media", lineCount: 3)), fields: BodyStructure.Fields(parameter: [], id: nil, description: nil, encoding: .binary, octetCount: 123))),
                #line
            ),
            (
                .singlepart(
                    .init(
                        type: .message(
                            .init(
                                message: .rfc822,
                                envelope: Envelope(date: nil, subject: nil, from: [], sender: [], reply: [], to: [], cc: [], bcc: [], inReplyTo: nil, messageID: nil),
                                body: .singlepart(.init(type: .basic(.init(type: .audio, subtype: .alternative)), fields: .init(parameter: [], id: nil, description: nil, encoding: .binary, octetCount: 0))
                                ),
                                fieldLines: 1
                            )
                        ),
                        fields: BodyStructure.Fields(parameter: [], id: nil, description: nil, encoding: .binary, octetCount: 99)
                    )
                ),
                [1],
                .singlepart(.init(type: .basic(.init(type: .audio, subtype: .alternative)), fields: .init(parameter: [], id: nil, description: nil, encoding: .binary, octetCount: 0))),
                #line
            ),
            (
                .multipart(.init(parts: [
                    .singlepart(.init(type: .basic(.init(type: .audio, subtype: .alternative)), fields: .init(parameter: [], id: nil, description: nil, encoding: .binary, octetCount: 0))),
                    .singlepart(.init(type: .basic(.init(type: .audio, subtype: .alternative)), fields: .init(parameter: [], id: nil, description: nil, encoding: .binary, octetCount: 1))),
                    .singlepart(.init(type: .basic(.init(type: .audio, subtype: .alternative)), fields: .init(parameter: [], id: nil, description: nil, encoding: .binary, octetCount: 2))),
                ], mediaSubtype: .init("subtype"))),
                [3],
                .singlepart(.init(type: .basic(.init(type: .audio, subtype: .alternative)), fields: .init(parameter: [], id: nil, description: nil, encoding: .binary, octetCount: 2))),
                #line
            ),
            (
                .multipart(.init(parts: [
                    .singlepart(.init(type: .basic(.init(type: .audio, subtype: .alternative)), fields: .init(parameter: [], id: nil, description: nil, encoding: .binary, octetCount: 0))),
                    .multipart(.init(parts: [
                        .singlepart(.init(type: .basic(.init(type: .audio, subtype: .alternative)), fields: .init(parameter: [], id: nil, description: nil, encoding: .binary, octetCount: 0))),
                        .multipart(.init(parts: [
                            .singlepart(.init(type: .basic(.init(type: .audio, subtype: .alternative)), fields: .init(parameter: [], id: nil, description: nil, encoding: .binary, octetCount: 3))),
                            .singlepart(.init(type: .basic(.init(type: .audio, subtype: .alternative)), fields: .init(parameter: [], id: nil, description: nil, encoding: .binary, octetCount: 4))),
                            .singlepart(.init(type: .basic(.init(type: .audio, subtype: .alternative)), fields: .init(parameter: [], id: nil, description: nil, encoding: .binary, octetCount: 5))),
                        ], mediaSubtype: .init("subtype"))),
                    ], mediaSubtype: .init("subtype"))),
                ], mediaSubtype: .init("subtype"))),
                [2, 2, 1],
                .singlepart(.init(type: .basic(.init(type: .audio, subtype: .alternative)), fields: .init(parameter: [], id: nil, description: nil, encoding: .binary, octetCount: 3))),
                #line
            ),
        ]
        inputs.forEach { (input, index, expected, line) in
            XCTAssertEqual(input[index], expected, line: line)
        }
    }
}
