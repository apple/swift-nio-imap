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

    @Test(arguments: [
        ParseFixture.bodyStructure(
            #"("text" "plain" ("CHARSET" "UTF-8") NIL NIL NIL 1423 44 NIL NIL NIL NIL)"#,
            "\r\n",
            expected: .success(
                .singlepart(
                    .init(
                        kind: .text(.init(mediaSubtype: "plain", lineCount: 44)),
                        fields: .init(
                            parameters: ["CHARSET": "UTF-8"],
                            id: nil,
                            contentDescription: nil,
                            encoding: nil,
                            octetCount: 1423
                        ),
                        extension: .init(
                            digest: nil,
                            dispositionAndLanguage: .init(
                                disposition: nil,
                                language: .init(languages: [], location: .init(location: nil, extensions: []))
                            )
                        )
                    )
                )
            )
        ),
        ParseFixture.bodyStructure(
            #"((("text" "plain" ("CHARSET" "UTF-8") NIL NIL NIL 1423 44 NIL NIL NIL NIL)("text" "html" ("CHARSET" "UTF-8") NIL NIL "quoted-printable" 2524 34 NIL NIL NIL NIL) "alternative" ("BOUNDARY" "000000000000ccac3a05a5ef76c3") NIL NIL NIL)("text" "plain" ("CHARSET" "us-ascii") NIL NIL "7bit" 151 4 NIL NIL NIL NIL) "mixed" ("BOUNDARY" "===============5781602957316160403==") NIL NIL NIL)"#,
            "\r\n",
            expected: .success(
                .multipart(
                    .init(
                        parts: [
                            .multipart(
                                .init(
                                    parts: [
                                        .singlepart(
                                            .init(
                                                kind: .text(.init(mediaSubtype: "plain", lineCount: 44)),
                                                fields: .init(
                                                    parameters: ["CHARSET": "UTF-8"],
                                                    id: nil,
                                                    contentDescription: nil,
                                                    encoding: nil,
                                                    octetCount: 1423
                                                ),
                                                extension: .init(
                                                    digest: nil,
                                                    dispositionAndLanguage: .init(
                                                        disposition: nil,
                                                        language: .init(
                                                            languages: [],
                                                            location: .init(location: nil, extensions: [])
                                                        )
                                                    )
                                                )
                                            )
                                        ),
                                        .singlepart(
                                            .init(
                                                kind: .text(.init(mediaSubtype: "html", lineCount: 34)),
                                                fields: .init(
                                                    parameters: ["CHARSET": "UTF-8"],
                                                    id: nil,
                                                    contentDescription: nil,
                                                    encoding: .quotedPrintable,
                                                    octetCount: 2524
                                                ),
                                                extension: .init(
                                                    digest: nil,
                                                    dispositionAndLanguage: .init(
                                                        disposition: nil,
                                                        language: .init(
                                                            languages: [],
                                                            location: .init(location: nil, extensions: [])
                                                        )
                                                    )
                                                )
                                            )
                                        ),
                                    ],
                                    mediaSubtype: .alternative,
                                    extension: .init(
                                        parameters: ["BOUNDARY": "000000000000ccac3a05a5ef76c3"],
                                        dispositionAndLanguage: .init(
                                            disposition: nil,
                                            language: .init(
                                                languages: [],
                                                location: .init(location: nil, extensions: [])
                                            )
                                        )
                                    )
                                )
                            ),
                            .singlepart(
                                .init(
                                    kind: .text(.init(mediaSubtype: "plain", lineCount: 4)),
                                    fields: .init(
                                        parameters: ["CHARSET": "us-ascii"],
                                        id: nil,
                                        contentDescription: nil,
                                        encoding: .sevenBit,
                                        octetCount: 151
                                    ),
                                    extension: .init(
                                        digest: nil,
                                        dispositionAndLanguage: .init(
                                            disposition: nil,
                                            language: .init(
                                                languages: [],
                                                location: .init(location: nil, extensions: [])
                                            )
                                        )
                                    )
                                )
                            ),
                        ],
                        mediaSubtype: .mixed,
                        extension: .init(
                            parameters: ["BOUNDARY": "===============5781602957316160403=="],
                            dispositionAndLanguage: .init(
                                disposition: nil,
                                language: .init(languages: [], location: .init(location: nil, extensions: []))
                            )
                        )
                    )
                )
            )
        ),
    ])
    func parse(_ fixture: ParseFixture<BodyStructure>) {
        fixture.checkParsing()
    }

    @Test(arguments: [
        ParseFixture.invalidBodyStructure(#"()"#, " UID 1", expected: .success(.invalid)),
        ParseFixture.invalidBodyStructure(#"(foo bar)"#, " UID 1", expected: .success(.invalid)),
        ParseFixture.invalidBodyStructure(
            #"((The (quick (brown (fox)) jumps) over (the (lazy dog.))) Suddenly, (the (sky (darkens (and (the (rain (begins to fall))))))))"#,
            " UID 1",
            expected: .success(.invalid)
        ),
        ParseFixture.invalidBodyStructure(
            #"("text" "plain" ("CHARSET" "UTF-8") NIL NIL NIL 1423 44 NIL NIL NIL NIL)"#,
            " UID 1",
            expected: .success(.invalid)
        ),
        ParseFixture.invalidBodyStructure(
            #"("text" "plain" ("CHARSET" {5}\#r\#nUTF-8) NIL NIL NIL 1423 44 NIL NIL NIL NIL)"#,
            " UID 1",
            expected: .success(.invalid)
        ),
        ParseFixture.invalidBodyStructure(
            #"("te(xt" "pl(ain" ("CHA(RSET" "UT(F-8") NIL NIL NIL 1423 44 NIL NIL NIL NIL)"#,
            " UID 1",
            expected: .success(.invalid)
        ),
        ParseFixture.invalidBodyStructure(
            #"("te)xt" "pl)ain" ("CHA)RSET" "UT)F-8") NIL NIL NIL 1423 44 NIL NIL NIL NIL)"#,
            " UID 1",
            expected: .success(.invalid)
        ),
        ParseFixture.invalidBodyStructure(
            #"("text" "plain" ("CHARSET" {7}\#r\#nU(TF-(8) NIL NIL NIL 1423 44 NIL NIL NIL NIL)"#,
            " UID 1",
            expected: .success(.invalid)
        ),
        ParseFixture.invalidBodyStructure(
            #"((("text" "plain" ("CHARSET" "UTF-8") NIL NIL NIL 1423 44 NIL NIL NIL NIL)("text" "html" ("CHARSET" "UTF-8") NIL NIL "quoted-printable" 2524 34 NIL NIL NIL NIL) "alternative" ("BOUNDARY" "000000000000ccac3a05a5ef76c3") NIL NIL NIL)("text" "plain" ("CHARSET" "us-ascii") NIL NIL "7bit" 151 4 NIL NIL NIL NIL) "mixed" ("BOUNDARY" "===============5781602957316160403==") NIL NIL NIL)"#,
            " UID 1",
            expected: .success(.invalid)
        ),
        ParseFixture.invalidBodyStructure(
            #"""
            (("TEXT" "PLAIN" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 14574 316 NIL NIL NIL NIL)(("TEXT" "HTML" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 125774 1805 NIL NIL NIL NIL)("IMAGE" "PNG" ("X-UNIX-MODE" "0666" "NAME" "gAQkIAEJSEACEpCABCQgAQlMTUBhxNRvwPtLQAISkIAEJCABCUhAAhKQgAQkIAEJSEACEpCABCQgAQlIQAISkIAEJDAagf8LBuKDy114N68AAAAASUVORK5CYII=.png") "<635BEE5F-D085-491C-B5AB-9E79BAC84B02>" NIL "BASE64" 21886 NIL ("INLINE" ("FILENAME" "gAQkIAEJSEACEpCABCQgAQlMTUBhxNRvwPtLQAISkIAEJCABCUhAAhKQgAQkIAEJSEACEpCABCQgAQlIQAISkIAEJDAagf8LBuKDy114N68AAAAASUVORK5CYII=.png")) NIL NIL)("IMAGE" "PNG" ("X-UNIX-MODE" "0666" "NAME" "AAIIIIAAAggkBAjYJkCYRQABBBBAAAEEEEAAAQQQQAABBBBAAAEEEEAAAQQQQAABBKolQMC2WtIcBwEEEEAAAQQQQAABBBBAAAEEEEAAAQQQQAABBBBAAAEEEEgIELBN") "<6BC5EC65-CF11-42BE-B878-C8E803376257>" NIL "BASE64" 115104 NIL ("INLINE" ("FILENAME" {4383}
            AACCCCAAAIIIIAAAggggAACCFRLgIBttaQ5DgIIIIAAAggggAACCCCAAAIIIIAAAggggAACCCCAAAIIIJAQIGCbAGEWAQQQQAABBBBAAAEEEEAAAQQQQAABBBBAAAEEEEAAAQQQqJYAAdtqSXMcBBBAAAEEEEAAAQQQQAABBBBAAAEEEEAAAQQQQAABBBBAICFAwDYBwiwCCCCAAAIIIIAAAggggAACCCCAAAIIIIAAAggggAACCCBQLQECttWS5jgIIIAAAggggAACCCCAAAIIIIAAAggggAACCCCAAAIIIIBAQoCAbQKEWQQQQAABBBBAAAEEEEAAAQQQQAABBBBAAAEEEEAAAQQQQKBaAgRsqyXNcRBAAAEEEEAAAQQQQAABBBBAAAEEEEAAAQQQQAABBBBAAIGEAAHbBAizCCCAAAIIIIAAAggggAACCCCAAAIIIIAAAggggAACCCCAQLUECNhWS5rjIIAAAggggAACCCCAAAIIIIAAAggggAACCCCAAAIIIIAAAgkBArYJEGYRQAABBBBAAAEEEEAAAQQQQAABBBBAAAEEEEAAAQQQQACBagkQsK2WNMdBAAEEEEAAAQQQQAABBBBAAAEEEEAAAQQQQAABBBBAAAEEEgIEbBMgzCKAAAIIIIAAAggggAACCCCAAAIIIIAAAggggAACCCCAAALVEiBgWy1pjoMAAggggAACCCCAAAIIIIAAAggggAACCCCAAAIIIIAAAggkBAjYJkCYRQABBBBAAAEEEEAAAQQQQAABBBBAAAEEEEAAAQQQQAABBKolQMC2WtIcBwEEEEAAAQQQQAABBBBAAAEEEEAAAQQQQAABBBBAAAEEEEgIELBNgDCLAAIIIIAAAggggAACCCCAAAIIIIAAAggggAACCCCAAAIIVEuAgG21pDkOAggggAACCCCAAAIIIIAAAggggAACCCCAAAIIIIAAAgggkBAgYJsAYRYBBBBAAAEEEEAAAQQQQAABBBBAAAEEEEAAAQQQQAABBBColgAB22pJcxwEEEAAAQQQQAABBBBAAAEEEEAAAQQQQAABBBBAAAEEEEAgIUDANgHCLAIIIIAAAggggAACCCCAAAIIIIAAAggggAACCCCAAAIIIFAtAQK21ZLmOAgggAACCCCAAAIIIIAAAggggAACCCCAAAIIIIAAAggggEBCgIBtAoRZBBBAAAEEEEAAAQQQQAABBBBAAAEEEEAAAQQQQAABBBBAoFoCBGyrJc1xEEAAAQQQQAABBBBAAAEEEEAAAQQQQAABBBBAAAEEEEAAgYQAAdsECLMIIIAAAggggAACCCCAAAIIIIAAAggggAACCCCAAAIIIIBAtQQI2FZLmuMggAACCCCAAAIIIIAAAggggAACCCCAAAIIIIAAAggggAACCQECtgkQZhFAAAEEEEAAAQQQQAABBBBAAAEEEEAAAQQQQAABBBBAAIFqCRCwrZY0x0EAAQQQQAABBBBAAAEEEEAAAQQQQAABBBBAAAEEEEAAAQQSAgRsEyDMIoAAAggggAACCCCAAAIIIIAAAggggAACCCCAAAIIIIAAAtUSIGBbLWmOgwACCCCAAAIIIIAAAggggAACCCCAAAIIIIAAAggggAACCCQECNgmQJhFAAEEEEAAAQQQQAABBBBAAAEEEEAAAQQQQAABBBBAAAEEqiVAwLZa0hwHAQQQQAABBBBAAAEEEEAAAQQQQAABBBBAAAEEEEAAAQQQSAgQsE2AMIsAAggggAACCCCAAAIIIIAAAggggAACCCCAAAIIIIAAAghUS4CAbbWkOQ4CCCCAAAIIIIAAAggggAACCCCAAAIIIIAAAggggAACCCCQECBgmwBhFgEEEEAAAQQQQAABBBBAAAEEEEAAAQQQQAABBBBAAAEEEKiWAAHbaklzHAQQQAABBBBAAAEEEEAAAQQQQAABBBBAAAEEEEAAAQQQQCAhQMA2AcIsAggggAACCCCAAAIIIIAAAggggAACCCCAAAIIIIAAAgggUC0BArbVkuY4CCCAAAIIIIAAAggggAACCCCAAAIIIIAAAggggAACCCCAQEKAgG0ChFkEEEAAAQQQQAABBBBAAAEEEEAAAQQQQAABBBBAAAEEEECgWgIEbKslzXEQQAABBBBAAAEEEEAAAQQQQAABBBBAAAEEEEAAAQQQQACBhAAB2wQIswgggAACCCCAAAIIIIAAAggggAACCCCAAAIIIIAAAggggEC1BAjYVkua4yCAAAIIIIAAAggggAACCCCAAAIIIIAAAggggAACCCCAAAIJAQK2CRBmEUAAAQQQQAABBBBAAAEEEEAAAQQQQAABBBBAAAEEEEAAgWoJELCtljTHQQABBBBAAAEEEEAAAQQQQAABBBBAAAEEEEAAAQQQQAABBBICBGwTIMwigAACCCCAAAIIIIAAAggggAACCCCAAAIIIIAAAggggAAC1RIgYFstaY6DAAIIIIAAAggggAACCCCAAAIIIIAAAggggAACCCCAAAIIJAQI2CZAmEUAAQQQQAABBBBAAAEEEEAAAQQQQAABBBBAAAEEEEAAAQSqJUDAtlrSHAcBBBBAAAEEEEAAAQQQQAABBBBAAAEEEEAAAQQQQAABBBBICBCwTYAwiwACCCCAAAIIIIAAAggggAACCCCAAAIIIIAAAggggAACCFRLgIBttaQ5DgIIIIAAAggggAACCCCAAAIIIIAAAggggAACCCCAAAIIIJAQIGCbAGEWAQQQQAABBBBAAAEEEEAAAQQQQAABBBBAAAEEEEAAAQQQqJYAAdtqSXMcBBBAAAEEEEAAAQQQQAABBBBAAAEEEEAAAQQQQAABBBBAICFAwDYBwiwCCCCAAAIIIIAAAggggAACCCCAAAIIIIAAAggggAACCCBQLQECttWS5jgIIIAAAggggAACCCCAAAIIIIAAAggggAACCCCAAAIIIIBAQoCAbQKEWQQQQAABBBBAAAEEEEAAAQQQQAABBBBAAAEEEEAAAQQQQKBaAgRsqyXNcRBAAAEEEEAAAQQQQAABBBBAAAEEEEAAAQQQQAABBBBAAIGEAAHbBAizCCCAAAIIIIAAAggggAACCCCAAAIIIIAAAggggAACCCCAQLUECNhWS5rjIIAAAggggAACCCCAAAIIIIAAAggggAACCCCAAAIIIIAAAgkBArYJEGYRQAABBBBAAAEEEEAAAQQQQAABBBBAAAEEEEAAAQQQQACBagkQsK2WNMdBAAEEEEAAAQQQQAABBBBAAAEEEEAAAQQQQAABBBBAAAEEEgIEbBMgzCKAAAIIIIAAAggggAACCCCAAAIIIIAAAggggAACCCCAAALVEiBgWy1pjoMAAggggAACCCCAAAIIIIAAAggggAACCCCAAAIIIIAAAggkBAjYJkCYRQABBBBAAAEEEEAAAQQQQAABBBBAAAEEEEAAAQQQQAABBKolQMC2WtIcBwEEEEAAAQQQQAABBBBAAAEEEEAAAQQQQAABBBBAAAEEEEgIELBNgDCLAAIIIIAAAggggAACCCCAAAIIIIAAAggggAACCCCAAAIIVEuAgG21pDkOAggggAACCCCAAAIII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AizCCCAAAIIIIAAAggggAACCCCAAAIIIIAAAggggAACCCCAQLUECNhWS5rjIIAAAggggAACCCCAAAIIIIAAAggggAACCCCAAAIIIIAAAgkBArYJEGYRQAABBBBAAAEEEEAAAQQQQAABBBBAAAEEEEAAAQQQQACBagkQsK2WNMdBAAEEEEAAAQQQQAABBBBAAAEEEEAAAQQQQAABBBBAAAEEEgIEbBMgzCKAAAIIIIAAAggggAACCCCAAAIIIIAAAggggAACCCCAAALVEiBgWy1pjoMAAggggAACCCCAAAIIIIAAAggggAACCCCAAAIIIIAAAggkBAjYJkCYRQABBBBAAAEEEEAAAQQQQAABBBBAAAEEEEAAAQQQQAABBKolQMC2WtIcBwEEEEAAAQQQQAABBBBAAAEEEEAAAQQQQAABBBBAAAEEEEgIELBNgDCLAAIIIIAAAggggAACCCCAAAIIIIAAAggggAACCCCAAAIIVEuAgG21pDkOAggggAACCCCAAAIIIIAAAggggAACCCCAAAIIIIAAAgggkBAgYJsAYRYBBBBAAAEEEEAAAQQQQAABBBBAAAEEEEAAAQQQQAABBBColgAB22pJcxwEEEAAAQQQQAABBBBAAAEEEEAAAQQQQAABBBBAAAEEEEAgIUDANgHCLAIIIIAAAggggAACCCCAAAIIIIAAAggggAACCCCAAAIIIFAtAQK21ZLmOAgggAACCCCAAAIIIIAAAggggAACCCCAAAIIIIAAAggggEBCgIBtAoRZBBBAAAEEEEAAAQQQQAABBBBAAAEEEEAAAQQQQAABBBBAoFoCBGyrJc1xEEAAAQQQQAABBBBAAAEEEEAAAQQQQAABBBBAAAEEEEAAgYQAAdsECLMIIIAAAggggAACCCCAAAIIIIAAAggggAACCCCAAAIIIIBAtQQI2FZLmuMggAACCCCAAAIIIIAAAggggAACCCCAAAIIIIAAAggggAACCQECtgkQZhFAAAEEEEAAAQQQQAABBBBAAAEEEEAAAQQQQAABBBBAAIFqCfwfVAp0YpLfY4IAAAAASUVORK5CYII=.png "FILENAME" "DiEhbZhPQIIIIAAAgggUB8CtKfqQ5V9IoAAAggggEC1BAjYVkua4yCAAAIIIIAAAggggAACCCCAAAIIIIAAAggggAACCCCAAAIJAbpEToAwiwACCCCAAAIIIIAAAggggAACCCCAAAIIIIAAAggggAACCFRLgIBttaQ5DgIIIIAAAggggAACCCCAAAIIIIAAAggggAACCCCAAAIIIJAQIGCbAGEWAQQQQAABBBBAAAEEEEAAAQQQQAABBBBAAAEEE")) NIL NIL)("IMAGE" "PNG" ("X-UNIX-MODE" "0666" "NAME" "i8ojQIAAAQIECBAgQIAAAQIECBAgQIAAAQIECBAgQIAAAQIEbgQcI26mUIQAAQIECBAgQIAAAQIECBAgQIAAAQIECBAgQIAAAQIECBCoBRwjalF5BAgQ") "<BA7C40D6-F478-4BF4-8108-21639F6A1D48>" NIL "BASE64" 30318 NIL ("INLINE" ("FILENAME" "BAgQIECAAAECBAgQIECAAAECBAgQIECAAAECNwKOETdTKEKAAAECBAgQIECAAAECBAgQIECAAAECBAgQIECAAAECBAjUAgMfXHqW3WwoCgAAAABJRU5ErkJggg==.png")) NIL NIL)("IMAGE" "PNG" ("X-UNIX-MODE" "0666" "NAME" "CBAgQIAAAQIECBAgQIAAAQIECBBoTUDAtrUakR8CBAgQIECAAAECBAgQIECAAAECBAgQIECAAAECBAYjIGA7mKpWUAIECBAgQIAAAQIECBAgQIAAAQIECBAgQIAAAQIE") "<F96654FB-2408-4DFF-A16E-37434146E777>" NIL "BASE64" 95892 NIL ("INLINE" ("FILENAME" "IUCAAAECBAgQIECAAAECBAgQIECAAAECBAgQIEBgMAICtoOpagUlQIAAAQIECBAgQIAAAQIECBAgQIAAAQIECBAgQKA1gf8F+1RZL0m5zlcAAAAASUVORK5CYII=.png")) NIL NIL) "RELATED" ("BOUNDARY" "Boundary_(ID_aG3DlMUYKLGRuq3B/20EQ0)" "TYPE" "text/html") NIL NIL NIL) "ALTERNATIVE" ("BOUNDARY" "Boundary_(ID_3tum4DPbQ14bQnzj/0hsgK)") NIL NIL NIL)
            """#,
            " UID 1",
            expected: .success(.invalid)
        ),
        ParseFixture.invalidBodyStructure(#" UID 1"#, " UID 1", expected: .failure),
        ParseFixture.invalidBodyStructure(#" ()"#, " UID 1", expected: .failure),
        ParseFixture.invalidBodyStructure(#") (a)"#, " UID 1", expected: .failure),
        ParseFixture.invalidBodyStructure(
            #"("text" "plain" ("CHARSET" {1234567}\#r\#nU(TF-(8) NIL NIL NIL 1423 44 NIL NIL NIL NIL)"#,
            " UID 1",
            expected: .failure
        ),
    ])
    func `parse invalid body`(_ fixture: ParseFixture<MessageAttribute.BodyStructure>) {
        fixture.checkParsing()
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

extension ParseFixture<BodyStructure> {
    fileprivate static func bodyStructure(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseBody
        )
    }
}

extension ParseFixture<MessageAttribute.BodyStructure> {
    fileprivate static func invalidBodyStructure(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseInvalidBody
        )
    }
}
