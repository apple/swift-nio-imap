//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import IMAPCommands
import Foundation
@testable import IMAPToolLib
import NIO
import NIOIMAP
import Testing

@Suite
enum DownloadTests {
    @Test
    static func downloadingUIDs() async throws {
        let section = SectionSpecifier(part: [], kind: .complete)

        let connection = TestConnection(
            expectedOrdering: .anyOrder,
            expectedCommands: [
                .init(
                    command: .uidFetch(
                        .set(UIDSetNonEmpty(range: 309_727...309_727)),
                        [.uid, .bodySection(peek: true, section, nil)],
                        []
                    ),
                    fetchResponses: [
                        .start(50_683),
                        .simpleAttribute(.uid(309_727)),
                        .streamingBegin(kind: .body(section: section, offset: nil), byteCount: 10),
                        .streamingBytes(ByteBuffer(string: "0123456")),
                        .streamingBytes(ByteBuffer(string: "789")),
                        .streamingEnd,
                        .finish,
                    ],
                    completion: .ok(.init(text: "Done"))
                ),
                .init(
                    command: .uidFetch(
                        .set(UIDSetNonEmpty(range: 967_986...967_986)),
                        [.uid, .bodySection(peek: true, SectionSpecifier(part: [], kind: .complete), nil)],
                        []
                    ),
                    fetchResponses: [
                        .start(81_434),
                        .simpleAttribute(.uid(967_986)),
                        .streamingBegin(kind: .body(section: section, offset: nil), byteCount: 10),
                        .streamingBytes(ByteBuffer(string: "abcdefghij")),
                        .streamingEnd,
                        .finish,
                    ],
                    completion: .ok(.init(text: "Done"))
                ),
            ]
        )
        try await withTemporaryDirectory { root in
            var dir = try DownloadDirectory.openDeletingInvalidFiles(
                directory: root,
                uidValidity: 543,
                deleteUnknown: false
            )
            try await download(
                connection: connection,
                uids: [309_727, 967_986],
                into: &dir
            )

            #expect(dir.downloadedUIDs == [309_727, 967_986])
            #expect(fileExists(at: root.appending("309727.021f.message")))
            #expect(fileExists(at: root.appending("967986.021f.message")))

            #expect(String(contentsOf: root.appending("309727.021f.message")) == "0123456789")
            #expect(String(contentsOf: root.appending("967986.021f.message")) == "abcdefghij")
        }
    }

    @Test
    static func skippingAlreadyExistingUIDs() async throws {
        // Should not download UID 309_727 because it already exists.
        let section = SectionSpecifier(part: [], kind: .complete)

        let connection = TestConnection(expectedCommands: [
            .init(
                command: .uidFetch(
                    .set(UIDSetNonEmpty(range: 967_986...967_986)),
                    [.uid, .bodySection(peek: true, SectionSpecifier(part: [], kind: .complete), nil)],
                    []
                ),
                fetchResponses: [
                    .start(81_434),
                    .simpleAttribute(.uid(967_986)),
                    .streamingBegin(kind: .body(section: section, offset: nil), byteCount: 10),
                    .streamingBytes(ByteBuffer(string: "abcdefghij")),
                    .streamingEnd,
                    .finish,
                ],
                completion: .ok(.init(text: "Done"))
            )
        ])
        try await withTemporaryDirectory { root in
            try "0123456789".write(to: root.appending("309727.021f.message"))
            var dir = try DownloadDirectory.openDeletingInvalidFiles(
                directory: root,
                uidValidity: 543,
                deleteUnknown: false
            )
            #expect(dir.downloadedUIDs == [309_727])

            try await download(
                connection: connection,
                uids: [309_727, 967_986],
                into: &dir
            )

            #expect(dir.downloadedUIDs == [309_727, 967_986])
            #expect(fileExists(at: root.appending("309727.021f.message")))
            #expect(fileExists(at: root.appending("967986.021f.message")))

            #expect(String(contentsOf: root.appending("309727.021f.message")) == "0123456789")
            #expect(String(contentsOf: root.appending("967986.021f.message")) == "abcdefghij")
        }
    }

    @Test
    static func downloadingNoUIDs() async throws {
        let connection = TestConnection(expectedCommands: [])
        try await withTemporaryDirectory { root in
            try "0123456789".write(to: root.appending("309727.021f.message"))
            try "abcdefghij".write(to: root.appending("967986.021f.message"))

            var dir = try DownloadDirectory.openDeletingInvalidFiles(
                directory: root,
                uidValidity: 543,
                deleteUnknown: false
            )
            #expect(dir.downloadedUIDs == [309_727, 967_986])

            try await download(
                connection: connection,
                uids: [309_727, 967_986],
                into: &dir
            )

            #expect(dir.downloadedUIDs == [309_727, 967_986])
            #expect(fileExists(at: root.appending("309727.021f.message")))
            #expect(fileExists(at: root.appending("967986.021f.message")))

            #expect(String(contentsOf: root.appending("309727.021f.message")) == "0123456789")
            #expect(String(contentsOf: root.appending("967986.021f.message")) == "abcdefghij")
        }
    }

    @Test
    static func downloadingManyUIDs() async throws {
        let section = SectionSpecifier(part: [], kind: .complete)

        let allUIDs = UIDSet([
            13_719, 15_358, 15_802, 16_274, 19_494, 25_159, 27_002, 34_672, 37_566, 38_755,
            38_787, 40_041, 42_625, 45_739, 49_607, 51_759, 60_241, 74_413, 74_769, 79_327,
            88_869, 93_311, 94_624, 94_799,
            128_233, 183_861, 222_318, 223_884, 349_921, 363_045, 410_554, 480_784, 497_318, 505_423,
            508_061, 549_435, 558_588, 583_859, 611_911, 617_912, 630_519, 727_792, 748_941, 762_112,
            778_651, 787_041, 788_830, 984_143,
        ])

        let expectedCommands: [TestConnection.CommandAndResponses] =
            allUIDs
            .enumerated()
            .map { index, uid in
                let seq = SequenceNumber.min.advanced(by: Int64(index))
                let messageA = "message"
                let messageB = "-\(uid)"
                return TestConnection.CommandAndResponses(
                    command: .uidFetch(
                        .set(UIDSetNonEmpty(range: uid...uid)),
                        [.uid, .bodySection(peek: true, section, nil)],
                        []
                    ),
                    fetchResponses: [
                        .start(seq),
                        .simpleAttribute(.uid(uid)),
                        .streamingBegin(
                            kind: .body(section: section, offset: nil),
                            byteCount: messageA.utf8.count + messageB.utf8.count
                        ),
                        .streamingBytes(ByteBuffer(string: messageA)),
                        .streamingBytes(ByteBuffer(string: messageB)),
                        .streamingEnd,
                        .finish,
                    ],
                    completion: .ok(.init(text: "Done \(uid)"))
                )
            }

        let connection = TestConnection(
            expectedOrdering: .anyOrder,
            expectedCommands: expectedCommands
        )
        try await withTemporaryDirectory { root in
            var dir = try DownloadDirectory.openDeletingInvalidFiles(
                directory: root,
                uidValidity: 543,
                deleteUnknown: false
            )
            try await download(
                connection: connection,
                uids: allUIDs,
                into: &dir
            )

            #expect(dir.downloadedUIDs == allUIDs)
            for uid in allUIDs {
                #expect(fileExists(at: root.appending("\(uid).021f.message")), "\(uid)")
                #expect(String(contentsOf: root.appending("\(uid).021f.message")) == "message-\(uid)", "\(uid)")
            }
        }
    }
}
