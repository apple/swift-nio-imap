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

class BodyStructure_Tests: EncodeTestClass {}

// MARK: - init

extension BodyStructure_Tests {
    func testInit_mediaSubtype() {
        let type = BodyStructure.MediaSubtype("TYPE")
        XCTAssertEqual(type.stringValue, "type")
    }
}

// MARK: - Encoding

extension BodyStructure_Tests {
    func testEncode_mediaSubtype() {
        let inputs: [(BodyStructure.MediaSubtype, String, UInt)] = [
            (.related, "related", #line),
            (.mixed, "mixed", #line),
            (.alternative, "alternative", #line),
            (.init("other"), "other", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeMediaSubtype($0) })
    }
}

// MARK: - RandomAccessCollection

extension BodyStructure_Tests {
    func testRandomAccessCollection_indexBeforeAfter() {
        // This checks that
        //  * startIndex
        //  * endIndex
        //  * index(before:)
        //  * index(after:)
        // are all correct.
        let inputs: [(BodyStructure, [SectionSpecifier.Part], UInt)] = [
            (
                .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 0))),
                [
                    [],
                    [1],
                ],
                #line
            ),
            (
                .singlepart(
                    .init(
                        kind: .message(
                            .init(
                                message: .rfc822,
                                envelope: Envelope(date: nil, subject: nil, from: [], sender: [], reply: [], to: [], cc: [], bcc: [], inReplyTo: nil, messageID: nil),
                                body: .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 0))
                                ),
                                lineCount: 1
                            )
                        ),
                        fields: BodyStructure.Fields(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 99)
                    )
                ),
                [
                    [],
                    [1],
                ],
                #line
            ),
            (
                .multipart(.init(parts: [
                    .singlepart(.init(kind: .basic(.init(kind: .application, subtype: .mixed)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .base64, octetCount: 1))),
                ], mediaSubtype: .mixed)),
                [
                    [],
                    [1],
                    [2],
                ],
                #line
            ),
            (
                .multipart(.init(parts: [
                    .multipart(.init(parts: [
                        .singlepart(.init(kind: .basic(.init(kind: .application, subtype: .mixed)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .base64, octetCount: 1))),
                    ], mediaSubtype: .mixed)),
                ], mediaSubtype: .mixed)),
                [
                    [],
                    [1],
                    [1, 1],
                    [2],
                ],
                #line
            ),
            (
                .multipart(BodyStructure.Multipart(parts: [
                    .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .mixed)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .base64, octetCount: 0))),
                    .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .mixed)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .base64, octetCount: 0))),
                    .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .mixed)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .base64, octetCount: 0))),
                ], mediaSubtype: .mixed)),
                [
                    [],
                    [1],
                    [2],
                    [3],
                    [4],
                ],
                #line
            ),
            (
                .multipart(.init(parts: [
                    .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 0))),
                    .multipart(.init(parts: [
                        .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 0))),
                        .multipart(.init(parts: [
                            .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 3))),
                            .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 4))),
                            .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 5))),
                        ], mediaSubtype: .init("subtype"))),
                    ], mediaSubtype: .init("subtype"))),
                ], mediaSubtype: .init("subtype"))),
                [
                    [],
                    [1],
                    [2],
                    [2, 1],
                    [2, 2],
                    [2, 2, 1],
                    [2, 2, 2],
                    [2, 2, 3],
                    [3],
                ],
                #line
            ),
            (
                .multipart(.init(parts: [
                    .multipart(.init(parts: [
                        .multipart(.init(parts: [
                            .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 3))),
                            .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 4))),
                            .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 5))),
                        ], mediaSubtype: .init("subtype"))),
                        .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 0))),
                    ], mediaSubtype: .init("subtype"))),
                    .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 0))),
                ], mediaSubtype: .init("subtype"))),
                [
                    [],
                    [1],
                    [1, 1],
                    [1, 1, 1],
                    [1, 1, 2],
                    [1, 1, 3],
                    [1, 2],
                    [2],
                    [3],
                ],
                #line
            ),
        ]
        for input in inputs {
            let line = input.2
            XCTAssertEqual(input.0.startIndex, input.1.first!, "startIndex should be \(String(reflecting: input.1.first))", line: line)
            XCTAssertEqual(input.0.endIndex, input.1.last!, "endIndex should be \(String(reflecting: input.1.last))", line: line)
            guard
                input.0.startIndex == input.1.first!,
                input.0.endIndex == input.1.last!
            else { XCTFail(line: line); continue }
            // Check index(after:)
            do {
                var index = input.0.startIndex
                var result = [index]
                while index != input.0.endIndex {
                    let next = input.0.index(after: index)
                    result.append(next)
                    index = next
                }
                XCTAssertEqual(result, input.1, "index(after:)", line: line)
            }
            // Check index(before:)
            do {
                var index = input.0.endIndex
                var result = [index]
                while index != input.0.startIndex {
                    let next = input.0.index(before: index)
                    result.insert(next, at: 0)
                    index = next
                }
                XCTAssertEqual(result, input.1, "index(before:)", line: line)
            }
        }
    }

    func testRandomAccessCollection_position() {
        let inputs: [(BodyStructure, SectionSpecifier.Part, BodyStructure, UInt)] = [
            (
                .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 0))),
                [],
                .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 0))),
                #line
            ),
            (
                .singlepart(.init(kind: .text(.init(mediaText: "media", lineCount: 3)), fields: BodyStructure.Fields(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 123))),
                [],
                .singlepart(.init(kind: .text(.init(mediaText: "media", lineCount: 3)), fields: BodyStructure.Fields(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 123))),
                #line
            ),
            (
                .singlepart(
                    .init(
                        kind: .message(
                            .init(
                                message: .rfc822,
                                envelope: Envelope(date: nil, subject: nil, from: [], sender: [], reply: [], to: [], cc: [], bcc: [], inReplyTo: nil, messageID: nil),
                                body: .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 0))
                                ),
                                lineCount: 1
                            )
                        ),
                        fields: BodyStructure.Fields(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 99)
                    )
                ),
                [1],
                .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 0))),
                #line
            ),
            (
                .multipart(.init(parts: [
                    .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 0))),
                    .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 1))),
                    .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 2))),
                ], mediaSubtype: .init("subtype"))),
                [3],
                .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 2))),
                #line
            ),
            (
                .multipart(.init(parts: [
                    .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 0))),
                    .multipart(.init(parts: [
                        .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 0))),
                        .multipart(.init(parts: [
                            .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 3))),
                            .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 4))),
                            .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 5))),
                        ], mediaSubtype: .init("subtype"))),
                    ], mediaSubtype: .init("subtype"))),
                ], mediaSubtype: .init("subtype"))),
                [2, 2, 1],
                .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 3))),
                #line
            ),
            (
                .multipart(.init(parts: [
                    .singlepart(.init(
                        kind: .message(BodyStructure.Singlepart.Message(
                            message: .rfc822,
                            envelope: Envelope(date: nil, subject: "A", from: [], sender: [], reply: [], to: [], cc: [], bcc: [], inReplyTo: nil, messageID: nil),
                            body: .multipart(.init(parts: [
                                .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 1))),
                                .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 2))),
                            ], mediaSubtype: .init("mixed"))),
                            lineCount: 321
                        )),
                        fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 0)
                    )),
                    .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 0))),
                ], mediaSubtype: .init("mixed"))),
                [1, 1],
                .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 1))),
                #line
            ),
            (
                .multipart(.init(parts: [
                    .singlepart(.init(
                        kind: .message(BodyStructure.Singlepart.Message(
                            message: .rfc822,
                            envelope: Envelope(date: nil, subject: "A", from: [], sender: [], reply: [], to: [], cc: [], bcc: [], inReplyTo: nil, messageID: nil),
                            body: .multipart(.init(parts: [
                                .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 1))),
                                .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 2))),
                            ], mediaSubtype: .init("mixed"))),
                            lineCount: 321
                        )),
                        fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 0)
                    )),
                    .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 0))),
                ], mediaSubtype: .init("mixed"))),
                [1, 1],
                .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 1))),
                #line
            ),
        ]
        inputs.forEach { (input, index, expected, line) in
            guard
                let sub = input.find(index)
            else { XCTFail("Invalid part '\(index)'.", line: line); return }
            XCTAssertEqual(sub, expected, line: line)
            XCTAssertEqual(input[index], expected, line: line)
        }
    }

    func testEnueratingParts() {
        let inputs: [(BodyStructure, [(SectionSpecifier.Part, BodyStructure)], UInt)] = [
            (
                .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 0))),
                [
                    (
                        [],
                        .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 0)))
                    ),
                ],
                #line
            ),
            (
                .multipart(.init(parts: [
                    .singlepart(.init(
                        kind: .message(BodyStructure.Singlepart.Message(
                            message: .rfc822,
                            envelope: Envelope(date: nil, subject: "A", from: [], sender: [], reply: [], to: [], cc: [], bcc: [], inReplyTo: nil, messageID: nil),
                            body: .multipart(.init(parts: [
                                .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 1))),
                                .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 2))),
                            ], mediaSubtype: .init("mixed"))),
                            lineCount: 321
                        )),
                        fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 0)
                    )),
                    .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 0))),
                ], mediaSubtype: .init("mixed"))),
                [
                    (
                        [],
                        .multipart(.init(parts: [
                            .singlepart(.init(
                                kind: .message(BodyStructure.Singlepart.Message(
                                    message: .rfc822,
                                    envelope: Envelope(date: nil, subject: "A", from: [], sender: [], reply: [], to: [], cc: [], bcc: [], inReplyTo: nil, messageID: nil),
                                    body: .multipart(.init(parts: [
                                        .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 1))),
                                        .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 2))),
                                    ], mediaSubtype: .init("mixed"))),
                                    lineCount: 321
                                )),
                                fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 0)
                            )),
                            .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 0))),
                        ], mediaSubtype: .init("mixed")))
                    ),
                    (
                        [1],
                        .singlepart(.init(
                            kind: .message(BodyStructure.Singlepart.Message(
                                message: .rfc822,
                                envelope: Envelope(date: nil, subject: "A", from: [], sender: [], reply: [], to: [], cc: [], bcc: [], inReplyTo: nil, messageID: nil),
                                body: .multipart(.init(parts: [
                                    .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 1))),
                                    .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 2))),
                                ], mediaSubtype: .init("mixed"))),
                                lineCount: 321
                            )),
                            fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 0)
                        ))
                    ),
                    (
                        [1, 1],
                        .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 1)))
                    ),
                    (
                        [1, 2],
                        .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 2)))
                    ),
                    (
                        [2],
                        .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 0)))
                    ),
                ],
                #line
            ),
            (
                .multipart(.init(parts: [
                    .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 0))),
                    .multipart(.init(parts: [
                        .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 0))),
                        .multipart(.init(parts: [
                            .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 3))),
                            .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 4))),
                            .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 5))),
                        ], mediaSubtype: .init("subtype"))),
                    ], mediaSubtype: .init("subtype"))),
                ], mediaSubtype: .init("subtype"))),
                [
                    (
                        [],
                        .multipart(.init(parts: [
                            .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 0))),
                            .multipart(.init(parts: [
                                .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 0))),
                                .multipart(.init(parts: [
                                    .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 3))),
                                    .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 4))),
                                    .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 5))),
                                ], mediaSubtype: .init("subtype"))),
                            ], mediaSubtype: .init("subtype"))),
                        ], mediaSubtype: .init("subtype")))
                    ),
                    (
                        [1],
                        .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 0)))
                    ),
                    (
                        [2],
                        .multipart(.init(parts: [
                            .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 0))),
                            .multipart(.init(parts: [
                                .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 3))),
                                .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 4))),
                                .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 5))),
                            ], mediaSubtype: .init("subtype"))),
                        ], mediaSubtype: .init("subtype")))
                    ),
                    (
                        [2, 1],
                        .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 0)))
                    ),
                    (
                        [2, 2],
                        .multipart(.init(parts: [
                            .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 3))),
                            .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 4))),
                            .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 5))),
                        ], mediaSubtype: .init("subtype")))
                    ),
                    (
                        [2, 2, 1],
                        .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 3)))
                    ),
                    (
                        [2, 2, 2],
                        .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 4)))
                    ),
                    (
                        [2, 2, 3],
                        .singlepart(.init(kind: .basic(.init(kind: .audio, subtype: .alternative)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 5)))
                    ),
                ],
                #line
            ),
        ]
        inputs.forEach { (input, expected, line) in
            var result: [(SectionSpecifier.Part, BodyStructure)] = []
            input.enumerateParts {
                result.append(($0, $1))
            }
            XCTAssertEqual(result.map(\.0), expected.map(\.0), line: line)
            XCTAssertEqual(result.map(\.1), expected.map(\.1), line: line)
        }
    }
}
