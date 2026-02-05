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

@Suite("BodyStructure")
private struct BodyStructureTests {
    @Test(arguments: [
        IndexNavigationFixture(
            bodyStructure: .singlepart(
                .init(
                    kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                    fields: .init(
                        parameters: [:],
                        id: nil,
                        contentDescription: nil,
                        encoding: .binary,
                        octetCount: 0
                    )
                )
            ),
            expectedIndices: [
                [],
                [1],
            ]
        ),
        IndexNavigationFixture(
            bodyStructure: .singlepart(
                .init(
                    kind: .message(
                        .init(
                            message: .rfc822,
                            envelope: Envelope(
                                date: nil,
                                subject: nil,
                                from: [],
                                sender: [],
                                reply: [],
                                to: [],
                                cc: [],
                                bcc: [],
                                inReplyTo: nil,
                                messageID: nil
                            ),
                            body: .singlepart(
                                .init(
                                    kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                    fields: .init(
                                        parameters: [:],
                                        id: nil,
                                        contentDescription: nil,
                                        encoding: .binary,
                                        octetCount: 0
                                    )
                                )
                            ),
                            lineCount: 1
                        )
                    ),
                    fields: BodyStructure.Fields(
                        parameters: [:],
                        id: nil,
                        contentDescription: nil,
                        encoding: .binary,
                        octetCount: 99
                    )
                )
            ),
            expectedIndices: [
                [],
                [1],
            ]
        ),
        IndexNavigationFixture(
            bodyStructure: .multipart(
                .init(
                    parts: [
                        .singlepart(
                            .init(
                                kind: .basic(.init(topLevel: .application, sub: .mixed)),
                                fields: .init(
                                    parameters: [:],
                                    id: nil,
                                    contentDescription: nil,
                                    encoding: .base64,
                                    octetCount: 1
                                )
                            )
                        )
                    ],
                    mediaSubtype: .mixed
                )
            ),
            expectedIndices: [
                [],
                [1],
                [2],
            ]
        ),
        IndexNavigationFixture(
            bodyStructure: .multipart(
                .init(
                    parts: [
                        .multipart(
                            .init(
                                parts: [
                                    .singlepart(
                                        .init(
                                            kind: .basic(.init(topLevel: .application, sub: .mixed)),
                                            fields: .init(
                                                parameters: [:],
                                                id: nil,
                                                contentDescription: nil,
                                                encoding: .base64,
                                                octetCount: 1
                                            )
                                        )
                                    )
                                ],
                                mediaSubtype: .mixed
                            )
                        )
                    ],
                    mediaSubtype: .mixed
                )
            ),
            expectedIndices: [
                [],
                [1],
                [1, 1],
                [2],
            ]
        ),
        IndexNavigationFixture(
            bodyStructure: .multipart(
                BodyStructure.Multipart(
                    parts: [
                        .singlepart(
                            .init(
                                kind: .basic(.init(topLevel: .audio, sub: .mixed)),
                                fields: .init(
                                    parameters: [:],
                                    id: nil,
                                    contentDescription: nil,
                                    encoding: .base64,
                                    octetCount: 0
                                )
                            )
                        ),
                        .singlepart(
                            .init(
                                kind: .basic(.init(topLevel: .audio, sub: .mixed)),
                                fields: .init(
                                    parameters: [:],
                                    id: nil,
                                    contentDescription: nil,
                                    encoding: .base64,
                                    octetCount: 0
                                )
                            )
                        ),
                        .singlepart(
                            .init(
                                kind: .basic(.init(topLevel: .audio, sub: .mixed)),
                                fields: .init(
                                    parameters: [:],
                                    id: nil,
                                    contentDescription: nil,
                                    encoding: .base64,
                                    octetCount: 0
                                )
                            )
                        ),
                    ],
                    mediaSubtype: .mixed
                )
            ),
            expectedIndices: [
                [],
                [1],
                [2],
                [3],
                [4],
            ]
        ),
        IndexNavigationFixture(
            bodyStructure: .multipart(
                .init(
                    parts: [
                        .singlepart(
                            .init(
                                kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                fields: .init(
                                    parameters: [:],
                                    id: nil,
                                    contentDescription: nil,
                                    encoding: .binary,
                                    octetCount: 0
                                )
                            )
                        ),
                        .multipart(
                            .init(
                                parts: [
                                    .singlepart(
                                        .init(
                                            kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                            fields: .init(
                                                parameters: [:],
                                                id: nil,
                                                contentDescription: nil,
                                                encoding: .binary,
                                                octetCount: 0
                                            )
                                        )
                                    ),
                                    .multipart(
                                        .init(
                                            parts: [
                                                .singlepart(
                                                    .init(
                                                        kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                                        fields: .init(
                                                            parameters: [:],
                                                            id: nil,
                                                            contentDescription: nil,
                                                            encoding: .binary,
                                                            octetCount: 3
                                                        )
                                                    )
                                                ),
                                                .singlepart(
                                                    .init(
                                                        kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                                        fields: .init(
                                                            parameters: [:],
                                                            id: nil,
                                                            contentDescription: nil,
                                                            encoding: .binary,
                                                            octetCount: 4
                                                        )
                                                    )
                                                ),
                                                .singlepart(
                                                    .init(
                                                        kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                                        fields: .init(
                                                            parameters: [:],
                                                            id: nil,
                                                            contentDescription: nil,
                                                            encoding: .binary,
                                                            octetCount: 5
                                                        )
                                                    )
                                                ),
                                            ],
                                            mediaSubtype: .init("subtype")
                                        )
                                    ),
                                ],
                                mediaSubtype: .init("subtype")
                            )
                        ),
                    ],
                    mediaSubtype: .init("subtype")
                )
            ),
            expectedIndices: [
                [],
                [1],
                [2],
                [2, 1],
                [2, 2],
                [2, 2, 1],
                [2, 2, 2],
                [2, 2, 3],
                [3],
            ]
        ),
        IndexNavigationFixture(
            bodyStructure: .multipart(
                .init(
                    parts: [
                        .multipart(
                            .init(
                                parts: [
                                    .multipart(
                                        .init(
                                            parts: [
                                                .singlepart(
                                                    .init(
                                                        kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                                        fields: .init(
                                                            parameters: [:],
                                                            id: nil,
                                                            contentDescription: nil,
                                                            encoding: .binary,
                                                            octetCount: 3
                                                        )
                                                    )
                                                ),
                                                .singlepart(
                                                    .init(
                                                        kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                                        fields: .init(
                                                            parameters: [:],
                                                            id: nil,
                                                            contentDescription: nil,
                                                            encoding: .binary,
                                                            octetCount: 4
                                                        )
                                                    )
                                                ),
                                                .singlepart(
                                                    .init(
                                                        kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                                        fields: .init(
                                                            parameters: [:],
                                                            id: nil,
                                                            contentDescription: nil,
                                                            encoding: .binary,
                                                            octetCount: 5
                                                        )
                                                    )
                                                ),
                                            ],
                                            mediaSubtype: .init("subtype")
                                        )
                                    ),
                                    .singlepart(
                                        .init(
                                            kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                            fields: .init(
                                                parameters: [:],
                                                id: nil,
                                                contentDescription: nil,
                                                encoding: .binary,
                                                octetCount: 0
                                            )
                                        )
                                    ),
                                ],
                                mediaSubtype: .init("subtype")
                            )
                        ),
                        .singlepart(
                            .init(
                                kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                fields: .init(
                                    parameters: [:],
                                    id: nil,
                                    contentDescription: nil,
                                    encoding: .binary,
                                    octetCount: 0
                                )
                            )
                        ),
                    ],
                    mediaSubtype: .init("subtype")
                )
            ),
            expectedIndices: [
                [],
                [1],
                [1, 1],
                [1, 1, 1],
                [1, 1, 2],
                [1, 1, 3],
                [1, 2],
                [2],
                [3],
            ]
        ),
    ])
    func `index navigation`(_ fixture: IndexNavigationFixture) {
        // Check startIndex
        #expect(
            fixture.bodyStructure.startIndex == fixture.expectedIndices.first!,
            "startIndex should be \(String(reflecting: fixture.expectedIndices.first))"
        )

        // Check endIndex
        #expect(
            fixture.bodyStructure.endIndex == fixture.expectedIndices.last!,
            "endIndex should be \(String(reflecting: fixture.expectedIndices.last))"
        )

        guard
            fixture.bodyStructure.startIndex == fixture.expectedIndices.first!,
            fixture.bodyStructure.endIndex == fixture.expectedIndices.last!
        else {
            Issue.record("startIndex or endIndex mismatch")
            return
        }

        // Check index(after:)
        do {
            var index = fixture.bodyStructure.startIndex
            var result = [index]
            while index != fixture.bodyStructure.endIndex {
                let next = fixture.bodyStructure.index(after: index)
                result.append(next)
                index = next
            }
            #expect(result == fixture.expectedIndices, "index(after:)")
        }

        // Check index(before:)
        do {
            var index = fixture.bodyStructure.endIndex
            var result = [index]
            while index != fixture.bodyStructure.startIndex {
                let next = fixture.bodyStructure.index(before: index)
                result.insert(next, at: 0)
                index = next
            }
            #expect(result == fixture.expectedIndices, "index(before:)")
        }
    }

    @Test(arguments: [
        PositionFixture(
            bodyStructure: .singlepart(
                .init(
                    kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                    fields: .init(
                        parameters: [:],
                        id: nil,
                        contentDescription: nil,
                        encoding: .binary,
                        octetCount: 0
                    )
                )
            ),
            index: [],
            expectedSubStructure: .singlepart(
                .init(
                    kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                    fields: .init(
                        parameters: [:],
                        id: nil,
                        contentDescription: nil,
                        encoding: .binary,
                        octetCount: 0
                    )
                )
            )
        ),
        PositionFixture(
            bodyStructure: .singlepart(
                .init(
                    kind: .text(.init(mediaSubtype: "media", lineCount: 3)),
                    fields: BodyStructure.Fields(
                        parameters: [:],
                        id: nil,
                        contentDescription: nil,
                        encoding: .binary,
                        octetCount: 123
                    )
                )
            ),
            index: [],
            expectedSubStructure: .singlepart(
                .init(
                    kind: .text(.init(mediaSubtype: "media", lineCount: 3)),
                    fields: BodyStructure.Fields(
                        parameters: [:],
                        id: nil,
                        contentDescription: nil,
                        encoding: .binary,
                        octetCount: 123
                    )
                )
            )
        ),
        PositionFixture(
            bodyStructure: .singlepart(
                .init(
                    kind: .message(
                        .init(
                            message: .rfc822,
                            envelope: Envelope(
                                date: nil,
                                subject: nil,
                                from: [],
                                sender: [],
                                reply: [],
                                to: [],
                                cc: [],
                                bcc: [],
                                inReplyTo: nil,
                                messageID: nil
                            ),
                            body: .singlepart(
                                .init(
                                    kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                    fields: .init(
                                        parameters: [:],
                                        id: nil,
                                        contentDescription: nil,
                                        encoding: .binary,
                                        octetCount: 0
                                    )
                                )
                            ),
                            lineCount: 1
                        )
                    ),
                    fields: BodyStructure.Fields(
                        parameters: [:],
                        id: nil,
                        contentDescription: nil,
                        encoding: .binary,
                        octetCount: 99
                    )
                )
            ),
            index: [1],
            expectedSubStructure: .singlepart(
                .init(
                    kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                    fields: .init(
                        parameters: [:],
                        id: nil,
                        contentDescription: nil,
                        encoding: .binary,
                        octetCount: 0
                    )
                )
            )
        ),
        PositionFixture(
            bodyStructure: .multipart(
                .init(
                    parts: [
                        .singlepart(
                            .init(
                                kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                fields: .init(
                                    parameters: [:],
                                    id: nil,
                                    contentDescription: nil,
                                    encoding: .binary,
                                    octetCount: 0
                                )
                            )
                        ),
                        .singlepart(
                            .init(
                                kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                fields: .init(
                                    parameters: [:],
                                    id: nil,
                                    contentDescription: nil,
                                    encoding: .binary,
                                    octetCount: 1
                                )
                            )
                        ),
                        .singlepart(
                            .init(
                                kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                fields: .init(
                                    parameters: [:],
                                    id: nil,
                                    contentDescription: nil,
                                    encoding: .binary,
                                    octetCount: 2
                                )
                            )
                        ),
                    ],
                    mediaSubtype: .init("subtype")
                )
            ),
            index: [3],
            expectedSubStructure: .singlepart(
                .init(
                    kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                    fields: .init(
                        parameters: [:],
                        id: nil,
                        contentDescription: nil,
                        encoding: .binary,
                        octetCount: 2
                    )
                )
            )
        ),
        PositionFixture(
            bodyStructure: .multipart(
                .init(
                    parts: [
                        .singlepart(
                            .init(
                                kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                fields: .init(
                                    parameters: [:],
                                    id: nil,
                                    contentDescription: nil,
                                    encoding: .binary,
                                    octetCount: 0
                                )
                            )
                        ),
                        .multipart(
                            .init(
                                parts: [
                                    .singlepart(
                                        .init(
                                            kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                            fields: .init(
                                                parameters: [:],
                                                id: nil,
                                                contentDescription: nil,
                                                encoding: .binary,
                                                octetCount: 0
                                            )
                                        )
                                    ),
                                    .multipart(
                                        .init(
                                            parts: [
                                                .singlepart(
                                                    .init(
                                                        kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                                        fields: .init(
                                                            parameters: [:],
                                                            id: nil,
                                                            contentDescription: nil,
                                                            encoding: .binary,
                                                            octetCount: 3
                                                        )
                                                    )
                                                ),
                                                .singlepart(
                                                    .init(
                                                        kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                                        fields: .init(
                                                            parameters: [:],
                                                            id: nil,
                                                            contentDescription: nil,
                                                            encoding: .binary,
                                                            octetCount: 4
                                                        )
                                                    )
                                                ),
                                                .singlepart(
                                                    .init(
                                                        kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                                        fields: .init(
                                                            parameters: [:],
                                                            id: nil,
                                                            contentDescription: nil,
                                                            encoding: .binary,
                                                            octetCount: 5
                                                        )
                                                    )
                                                ),
                                            ],
                                            mediaSubtype: .init("subtype")
                                        )
                                    ),
                                ],
                                mediaSubtype: .init("subtype")
                            )
                        ),
                    ],
                    mediaSubtype: .init("subtype")
                )
            ),
            index: [2, 2, 1],
            expectedSubStructure: .singlepart(
                .init(
                    kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                    fields: .init(
                        parameters: [:],
                        id: nil,
                        contentDescription: nil,
                        encoding: .binary,
                        octetCount: 3
                    )
                )
            )
        ),
        PositionFixture(
            bodyStructure: .multipart(
                .init(
                    parts: [
                        .singlepart(
                            .init(
                                kind: .message(
                                    BodyStructure.Singlepart.Message(
                                        message: .rfc822,
                                        envelope: Envelope(
                                            date: nil,
                                            subject: "A",
                                            from: [],
                                            sender: [],
                                            reply: [],
                                            to: [],
                                            cc: [],
                                            bcc: [],
                                            inReplyTo: nil,
                                            messageID: nil
                                        ),
                                        body: .multipart(
                                            .init(
                                                parts: [
                                                    .singlepart(
                                                        .init(
                                                            kind: .basic(
                                                                .init(topLevel: .audio, sub: .alternative)
                                                            ),
                                                            fields: .init(
                                                                parameters: [:],
                                                                id: nil,
                                                                contentDescription: nil,
                                                                encoding: .binary,
                                                                octetCount: 1
                                                            )
                                                        )
                                                    ),
                                                    .singlepart(
                                                        .init(
                                                            kind: .basic(
                                                                .init(topLevel: .audio, sub: .alternative)
                                                            ),
                                                            fields: .init(
                                                                parameters: [:],
                                                                id: nil,
                                                                contentDescription: nil,
                                                                encoding: .binary,
                                                                octetCount: 2
                                                            )
                                                        )
                                                    ),
                                                ],
                                                mediaSubtype: .init("mixed")
                                            )
                                        ),
                                        lineCount: 321
                                    )
                                ),
                                fields: .init(
                                    parameters: [:],
                                    id: nil,
                                    contentDescription: nil,
                                    encoding: .binary,
                                    octetCount: 0
                                )
                            )
                        ),
                        .singlepart(
                            .init(
                                kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                fields: .init(
                                    parameters: [:],
                                    id: nil,
                                    contentDescription: nil,
                                    encoding: .binary,
                                    octetCount: 0
                                )
                            )
                        ),
                    ],
                    mediaSubtype: .init("mixed")
                )
            ),
            index: [1, 1],
            expectedSubStructure: .singlepart(
                .init(
                    kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                    fields: .init(
                        parameters: [:],
                        id: nil,
                        contentDescription: nil,
                        encoding: .binary,
                        octetCount: 1
                    )
                )
            )
        ),
        PositionFixture(
            bodyStructure: .multipart(
                .init(
                    parts: [
                        .singlepart(
                            .init(
                                kind: .message(
                                    BodyStructure.Singlepart.Message(
                                        message: .rfc822,
                                        envelope: Envelope(
                                            date: nil,
                                            subject: "A",
                                            from: [],
                                            sender: [],
                                            reply: [],
                                            to: [],
                                            cc: [],
                                            bcc: [],
                                            inReplyTo: nil,
                                            messageID: nil
                                        ),
                                        body: .multipart(
                                            .init(
                                                parts: [
                                                    .singlepart(
                                                        .init(
                                                            kind: .basic(
                                                                .init(topLevel: .audio, sub: .alternative)
                                                            ),
                                                            fields: .init(
                                                                parameters: [:],
                                                                id: nil,
                                                                contentDescription: nil,
                                                                encoding: .binary,
                                                                octetCount: 1
                                                            )
                                                        )
                                                    ),
                                                    .singlepart(
                                                        .init(
                                                            kind: .basic(
                                                                .init(topLevel: .audio, sub: .alternative)
                                                            ),
                                                            fields: .init(
                                                                parameters: [:],
                                                                id: nil,
                                                                contentDescription: nil,
                                                                encoding: .binary,
                                                                octetCount: 2
                                                            )
                                                        )
                                                    ),
                                                ],
                                                mediaSubtype: .init("mixed")
                                            )
                                        ),
                                        lineCount: 321
                                    )
                                ),
                                fields: .init(
                                    parameters: [:],
                                    id: nil,
                                    contentDescription: nil,
                                    encoding: .binary,
                                    octetCount: 0
                                )
                            )
                        ),
                        .singlepart(
                            .init(
                                kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                fields: .init(
                                    parameters: [:],
                                    id: nil,
                                    contentDescription: nil,
                                    encoding: .binary,
                                    octetCount: 0
                                )
                            )
                        ),
                    ],
                    mediaSubtype: .init("mixed")
                )
            ),
            index: [1, 1],
            expectedSubStructure: .singlepart(
                .init(
                    kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                    fields: .init(
                        parameters: [:],
                        id: nil,
                        contentDescription: nil,
                        encoding: .binary,
                        octetCount: 1
                    )
                )
            )
        ),
    ])
    func `find and subscript access`(_ fixture: PositionFixture) {
        guard let sub = fixture.bodyStructure.find(fixture.index) else {
            Issue.record("Invalid part '\(fixture.index)'.")
            return
        }
        #expect(sub == fixture.expectedSubStructure)
        #expect(fixture.bodyStructure[fixture.index] == fixture.expectedSubStructure)
    }

    @Test(arguments: [
        MediaTypeFixture(
            bodyStructure: .singlepart(
                .init(
                    kind: .basic(.init(topLevel: .audio, sub: "amr")),
                    fields: .init(
                        parameters: [:],
                        id: nil,
                        contentDescription: nil,
                        encoding: .binary,
                        octetCount: 0
                    )
                )
            ),
            expectedTopLevel: "audio",
            expectedSubtype: "amr"
        ),
        MediaTypeFixture(
            bodyStructure: .singlepart(
                .init(
                    kind: .basic(.init(topLevel: .image, sub: "jpeg")),
                    fields: .init(
                        parameters: [:],
                        id: nil,
                        contentDescription: nil,
                        encoding: .binary,
                        octetCount: 0
                    )
                )
            ),
            expectedTopLevel: "image",
            expectedSubtype: "jpeg"
        ),
        MediaTypeFixture(
            bodyStructure: .singlepart(
                .init(
                    kind: .text(.init(mediaSubtype: "html", lineCount: 3)),
                    fields: BodyStructure.Fields(
                        parameters: [:],
                        id: nil,
                        contentDescription: nil,
                        encoding: .binary,
                        octetCount: 123
                    )
                )
            ),
            expectedTopLevel: "text",
            expectedSubtype: "html"
        ),
        MediaTypeFixture(
            bodyStructure: .singlepart(
                .init(
                    kind: .message(
                        .init(
                            message: .rfc822,
                            envelope: Envelope(
                                date: nil,
                                subject: nil,
                                from: [],
                                sender: [],
                                reply: [],
                                to: [],
                                cc: [],
                                bcc: [],
                                inReplyTo: nil,
                                messageID: nil
                            ),
                            body: .singlepart(
                                .init(
                                    kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                    fields: .init(
                                        parameters: [:],
                                        id: nil,
                                        contentDescription: nil,
                                        encoding: .binary,
                                        octetCount: 0
                                    )
                                )
                            ),
                            lineCount: 1
                        )
                    ),
                    fields: BodyStructure.Fields(
                        parameters: [:],
                        id: nil,
                        contentDescription: nil,
                        encoding: .binary,
                        octetCount: 99
                    )
                )
            ),
            expectedTopLevel: "message",
            expectedSubtype: "rfc822"
        ),
        MediaTypeFixture(
            bodyStructure: .multipart(
                .init(
                    parts: [
                        .singlepart(
                            .init(
                                kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                fields: .init(
                                    parameters: [:],
                                    id: nil,
                                    contentDescription: nil,
                                    encoding: .binary,
                                    octetCount: 0
                                )
                            )
                        )
                    ],
                    mediaSubtype: .alternative
                )
            ),
            expectedTopLevel: "multipart",
            expectedSubtype: "alternative"
        ),
        MediaTypeFixture(
            bodyStructure: .multipart(
                .init(
                    parts: [
                        .singlepart(
                            .init(
                                kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                fields: .init(
                                    parameters: [:],
                                    id: nil,
                                    contentDescription: nil,
                                    encoding: .binary,
                                    octetCount: 0
                                )
                            )
                        )
                    ],
                    mediaSubtype: .mixed
                )
            ),
            expectedTopLevel: "multipart",
            expectedSubtype: "mixed"
        ),
    ])
    func `media type`(_ fixture: MediaTypeFixture) {
        #expect(fixture.bodyStructure.mediaType.topLevel == fixture.expectedTopLevel)
        #expect(fixture.bodyStructure.mediaType.sub == fixture.expectedSubtype)
    }

    @Test(arguments: [
        EnumeratePartsFixture(
            bodyStructure: .singlepart(
                .init(
                    kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                    fields: .init(
                        parameters: [:],
                        id: nil,
                        contentDescription: nil,
                        encoding: .binary,
                        octetCount: 0
                    )
                )
            ),
            expectedParts: [
                (
                    [],
                    .singlepart(
                        .init(
                            kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                            fields: .init(
                                parameters: [:],
                                id: nil,
                                contentDescription: nil,
                                encoding: .binary,
                                octetCount: 0
                            )
                        )
                    )
                )
            ]
        ),
        EnumeratePartsFixture(
            bodyStructure: .multipart(
                .init(
                    parts: [
                        .singlepart(
                            .init(
                                kind: .message(
                                    BodyStructure.Singlepart.Message(
                                        message: .rfc822,
                                        envelope: Envelope(
                                            date: nil,
                                            subject: "A",
                                            from: [],
                                            sender: [],
                                            reply: [],
                                            to: [],
                                            cc: [],
                                            bcc: [],
                                            inReplyTo: nil,
                                            messageID: nil
                                        ),
                                        body: .multipart(
                                            .init(
                                                parts: [
                                                    .singlepart(
                                                        .init(
                                                            kind: .basic(
                                                                .init(topLevel: .audio, sub: .alternative)
                                                            ),
                                                            fields: .init(
                                                                parameters: [:],
                                                                id: nil,
                                                                contentDescription: nil,
                                                                encoding: .binary,
                                                                octetCount: 1
                                                            )
                                                        )
                                                    ),
                                                    .singlepart(
                                                        .init(
                                                            kind: .basic(
                                                                .init(topLevel: .audio, sub: .alternative)
                                                            ),
                                                            fields: .init(
                                                                parameters: [:],
                                                                id: nil,
                                                                contentDescription: nil,
                                                                encoding: .binary,
                                                                octetCount: 2
                                                            )
                                                        )
                                                    ),
                                                ],
                                                mediaSubtype: .init("mixed")
                                            )
                                        ),
                                        lineCount: 321
                                    )
                                ),
                                fields: .init(
                                    parameters: [:],
                                    id: nil,
                                    contentDescription: nil,
                                    encoding: .binary,
                                    octetCount: 0
                                )
                            )
                        ),
                        .singlepart(
                            .init(
                                kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                fields: .init(
                                    parameters: [:],
                                    id: nil,
                                    contentDescription: nil,
                                    encoding: .binary,
                                    octetCount: 0
                                )
                            )
                        ),
                    ],
                    mediaSubtype: .init("mixed")
                )
            ),
            expectedParts: [
                (
                    [],
                    .multipart(
                        .init(
                            parts: [
                                .singlepart(
                                    .init(
                                        kind: .message(
                                            BodyStructure.Singlepart.Message(
                                                message: .rfc822,
                                                envelope: Envelope(
                                                    date: nil,
                                                    subject: "A",
                                                    from: [],
                                                    sender: [],
                                                    reply: [],
                                                    to: [],
                                                    cc: [],
                                                    bcc: [],
                                                    inReplyTo: nil,
                                                    messageID: nil
                                                ),
                                                body: .multipart(
                                                    .init(
                                                        parts: [
                                                            .singlepart(
                                                                .init(
                                                                    kind: .basic(
                                                                        .init(topLevel: .audio, sub: .alternative)
                                                                    ),
                                                                    fields: .init(
                                                                        parameters: [:],
                                                                        id: nil,
                                                                        contentDescription: nil,
                                                                        encoding: .binary,
                                                                        octetCount: 1
                                                                    )
                                                                )
                                                            ),
                                                            .singlepart(
                                                                .init(
                                                                    kind: .basic(
                                                                        .init(topLevel: .audio, sub: .alternative)
                                                                    ),
                                                                    fields: .init(
                                                                        parameters: [:],
                                                                        id: nil,
                                                                        contentDescription: nil,
                                                                        encoding: .binary,
                                                                        octetCount: 2
                                                                    )
                                                                )
                                                            ),
                                                        ],
                                                        mediaSubtype: .init("mixed")
                                                    )
                                                ),
                                                lineCount: 321
                                            )
                                        ),
                                        fields: .init(
                                            parameters: [:],
                                            id: nil,
                                            contentDescription: nil,
                                            encoding: .binary,
                                            octetCount: 0
                                        )
                                    )
                                ),
                                .singlepart(
                                    .init(
                                        kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                        fields: .init(
                                            parameters: [:],
                                            id: nil,
                                            contentDescription: nil,
                                            encoding: .binary,
                                            octetCount: 0
                                        )
                                    )
                                ),
                            ],
                            mediaSubtype: .init("mixed")
                        )
                    )
                ),
                (
                    [1],
                    .singlepart(
                        .init(
                            kind: .message(
                                BodyStructure.Singlepart.Message(
                                    message: .rfc822,
                                    envelope: Envelope(
                                        date: nil,
                                        subject: "A",
                                        from: [],
                                        sender: [],
                                        reply: [],
                                        to: [],
                                        cc: [],
                                        bcc: [],
                                        inReplyTo: nil,
                                        messageID: nil
                                    ),
                                    body: .multipart(
                                        .init(
                                            parts: [
                                                .singlepart(
                                                    .init(
                                                        kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                                        fields: .init(
                                                            parameters: [:],
                                                            id: nil,
                                                            contentDescription: nil,
                                                            encoding: .binary,
                                                            octetCount: 1
                                                        )
                                                    )
                                                ),
                                                .singlepart(
                                                    .init(
                                                        kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                                        fields: .init(
                                                            parameters: [:],
                                                            id: nil,
                                                            contentDescription: nil,
                                                            encoding: .binary,
                                                            octetCount: 2
                                                        )
                                                    )
                                                ),
                                            ],
                                            mediaSubtype: .init("mixed")
                                        )
                                    ),
                                    lineCount: 321
                                )
                            ),
                            fields: .init(
                                parameters: [:],
                                id: nil,
                                contentDescription: nil,
                                encoding: .binary,
                                octetCount: 0
                            )
                        )
                    )
                ),
                (
                    [1, 1],
                    .singlepart(
                        .init(
                            kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                            fields: .init(
                                parameters: [:],
                                id: nil,
                                contentDescription: nil,
                                encoding: .binary,
                                octetCount: 1
                            )
                        )
                    )
                ),
                (
                    [1, 2],
                    .singlepart(
                        .init(
                            kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                            fields: .init(
                                parameters: [:],
                                id: nil,
                                contentDescription: nil,
                                encoding: .binary,
                                octetCount: 2
                            )
                        )
                    )
                ),
                (
                    [2],
                    .singlepart(
                        .init(
                            kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                            fields: .init(
                                parameters: [:],
                                id: nil,
                                contentDescription: nil,
                                encoding: .binary,
                                octetCount: 0
                            )
                        )
                    )
                ),
            ]
        ),
        EnumeratePartsFixture(
            bodyStructure: .multipart(
                .init(
                    parts: [
                        .singlepart(
                            .init(
                                kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                fields: .init(
                                    parameters: [:],
                                    id: nil,
                                    contentDescription: nil,
                                    encoding: .binary,
                                    octetCount: 0
                                )
                            )
                        ),
                        .multipart(
                            .init(
                                parts: [
                                    .singlepart(
                                        .init(
                                            kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                            fields: .init(
                                                parameters: [:],
                                                id: nil,
                                                contentDescription: nil,
                                                encoding: .binary,
                                                octetCount: 0
                                            )
                                        )
                                    ),
                                    .multipart(
                                        .init(
                                            parts: [
                                                .singlepart(
                                                    .init(
                                                        kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                                        fields: .init(
                                                            parameters: [:],
                                                            id: nil,
                                                            contentDescription: nil,
                                                            encoding: .binary,
                                                            octetCount: 3
                                                        )
                                                    )
                                                ),
                                                .singlepart(
                                                    .init(
                                                        kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                                        fields: .init(
                                                            parameters: [:],
                                                            id: nil,
                                                            contentDescription: nil,
                                                            encoding: .binary,
                                                            octetCount: 4
                                                        )
                                                    )
                                                ),
                                                .singlepart(
                                                    .init(
                                                        kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                                        fields: .init(
                                                            parameters: [:],
                                                            id: nil,
                                                            contentDescription: nil,
                                                            encoding: .binary,
                                                            octetCount: 5
                                                        )
                                                    )
                                                ),
                                            ],
                                            mediaSubtype: .init("subtype")
                                        )
                                    ),
                                ],
                                mediaSubtype: .init("subtype")
                            )
                        ),
                    ],
                    mediaSubtype: .init("subtype")
                )
            ),
            expectedParts: [
                (
                    [],
                    .multipart(
                        .init(
                            parts: [
                                .singlepart(
                                    .init(
                                        kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                        fields: .init(
                                            parameters: [:],
                                            id: nil,
                                            contentDescription: nil,
                                            encoding: .binary,
                                            octetCount: 0
                                        )
                                    )
                                ),
                                .multipart(
                                    .init(
                                        parts: [
                                            .singlepart(
                                                .init(
                                                    kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                                    fields: .init(
                                                        parameters: [:],
                                                        id: nil,
                                                        contentDescription: nil,
                                                        encoding: .binary,
                                                        octetCount: 0
                                                    )
                                                )
                                            ),
                                            .multipart(
                                                .init(
                                                    parts: [
                                                        .singlepart(
                                                            .init(
                                                                kind: .basic(
                                                                    .init(topLevel: .audio, sub: .alternative)
                                                                ),
                                                                fields: .init(
                                                                    parameters: [:],
                                                                    id: nil,
                                                                    contentDescription: nil,
                                                                    encoding: .binary,
                                                                    octetCount: 3
                                                                )
                                                            )
                                                        ),
                                                        .singlepart(
                                                            .init(
                                                                kind: .basic(
                                                                    .init(topLevel: .audio, sub: .alternative)
                                                                ),
                                                                fields: .init(
                                                                    parameters: [:],
                                                                    id: nil,
                                                                    contentDescription: nil,
                                                                    encoding: .binary,
                                                                    octetCount: 4
                                                                )
                                                            )
                                                        ),
                                                        .singlepart(
                                                            .init(
                                                                kind: .basic(
                                                                    .init(topLevel: .audio, sub: .alternative)
                                                                ),
                                                                fields: .init(
                                                                    parameters: [:],
                                                                    id: nil,
                                                                    contentDescription: nil,
                                                                    encoding: .binary,
                                                                    octetCount: 5
                                                                )
                                                            )
                                                        ),
                                                    ],
                                                    mediaSubtype: .init("subtype")
                                                )
                                            ),
                                        ],
                                        mediaSubtype: .init("subtype")
                                    )
                                ),
                            ],
                            mediaSubtype: .init("subtype")
                        )
                    )
                ),
                (
                    [1],
                    .singlepart(
                        .init(
                            kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                            fields: .init(
                                parameters: [:],
                                id: nil,
                                contentDescription: nil,
                                encoding: .binary,
                                octetCount: 0
                            )
                        )
                    )
                ),
                (
                    [2],
                    .multipart(
                        .init(
                            parts: [
                                .singlepart(
                                    .init(
                                        kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                        fields: .init(
                                            parameters: [:],
                                            id: nil,
                                            contentDescription: nil,
                                            encoding: .binary,
                                            octetCount: 0
                                        )
                                    )
                                ),
                                .multipart(
                                    .init(
                                        parts: [
                                            .singlepart(
                                                .init(
                                                    kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                                    fields: .init(
                                                        parameters: [:],
                                                        id: nil,
                                                        contentDescription: nil,
                                                        encoding: .binary,
                                                        octetCount: 3
                                                    )
                                                )
                                            ),
                                            .singlepart(
                                                .init(
                                                    kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                                    fields: .init(
                                                        parameters: [:],
                                                        id: nil,
                                                        contentDescription: nil,
                                                        encoding: .binary,
                                                        octetCount: 4
                                                    )
                                                )
                                            ),
                                            .singlepart(
                                                .init(
                                                    kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                                    fields: .init(
                                                        parameters: [:],
                                                        id: nil,
                                                        contentDescription: nil,
                                                        encoding: .binary,
                                                        octetCount: 5
                                                    )
                                                )
                                            ),
                                        ],
                                        mediaSubtype: .init("subtype")
                                    )
                                ),
                            ],
                            mediaSubtype: .init("subtype")
                        )
                    )
                ),
                (
                    [2, 1],
                    .singlepart(
                        .init(
                            kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                            fields: .init(
                                parameters: [:],
                                id: nil,
                                contentDescription: nil,
                                encoding: .binary,
                                octetCount: 0
                            )
                        )
                    )
                ),
                (
                    [2, 2],
                    .multipart(
                        .init(
                            parts: [
                                .singlepart(
                                    .init(
                                        kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                        fields: .init(
                                            parameters: [:],
                                            id: nil,
                                            contentDescription: nil,
                                            encoding: .binary,
                                            octetCount: 3
                                        )
                                    )
                                ),
                                .singlepart(
                                    .init(
                                        kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                        fields: .init(
                                            parameters: [:],
                                            id: nil,
                                            contentDescription: nil,
                                            encoding: .binary,
                                            octetCount: 4
                                        )
                                    )
                                ),
                                .singlepart(
                                    .init(
                                        kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                                        fields: .init(
                                            parameters: [:],
                                            id: nil,
                                            contentDescription: nil,
                                            encoding: .binary,
                                            octetCount: 5
                                        )
                                    )
                                ),
                            ],
                            mediaSubtype: .init("subtype")
                        )
                    )
                ),
                (
                    [2, 2, 1],
                    .singlepart(
                        .init(
                            kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                            fields: .init(
                                parameters: [:],
                                id: nil,
                                contentDescription: nil,
                                encoding: .binary,
                                octetCount: 3
                            )
                        )
                    )
                ),
                (
                    [2, 2, 2],
                    .singlepart(
                        .init(
                            kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                            fields: .init(
                                parameters: [:],
                                id: nil,
                                contentDescription: nil,
                                encoding: .binary,
                                octetCount: 4
                            )
                        )
                    )
                ),
                (
                    [2, 2, 3],
                    .singlepart(
                        .init(
                            kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                            fields: .init(
                                parameters: [:],
                                id: nil,
                                contentDescription: nil,
                                encoding: .binary,
                                octetCount: 5
                            )
                        )
                    )
                ),
            ]
        ),
    ])
    func `enumerate parts`(_ fixture: EnumeratePartsFixture) {
        var result: [(SectionSpecifier.Part, BodyStructure)] = []
        fixture.bodyStructure.enumerateParts {
            result.append(($0, $1))
        }
        #expect(result.map(\.0) == fixture.expectedParts.map(\.0))
        #expect(result.map(\.1) == fixture.expectedParts.map(\.1))
    }
}

// MARK: -

private struct IndexNavigationFixture: Sendable, CustomTestStringConvertible {
    let bodyStructure: BodyStructure
    let expectedIndices: [SectionSpecifier.Part]

    var testDescription: String {
        "indices: \(expectedIndices)"
    }
}

private struct PositionFixture: Sendable, CustomTestStringConvertible {
    let bodyStructure: BodyStructure
    let index: SectionSpecifier.Part
    let expectedSubStructure: BodyStructure

    var testDescription: String {
        "position: \(index)"
    }
}

private struct MediaTypeFixture: Sendable, CustomTestStringConvertible {
    let bodyStructure: BodyStructure
    let expectedTopLevel: Media.TopLevelType
    let expectedSubtype: Media.Subtype

    var testDescription: String {
        "\(expectedTopLevel)/\(expectedSubtype)"
    }
}

private struct EnumeratePartsFixture: Sendable, CustomTestStringConvertible {
    let bodyStructure: BodyStructure
    let expectedParts: [(SectionSpecifier.Part, BodyStructure)]

    var testDescription: String {
        "parts: \(expectedParts.count)"
    }
}
