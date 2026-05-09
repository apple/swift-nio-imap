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

import Darwin
import Foundation
@testable import NIOIMAP
import System
import Testing
@testable import IMAPToolLib

@Suite("Append Files")
private enum Append_FilesTests {
    static func createFile(
        dir: FilePath,
        name: String,
        content: String
    ) throws -> FilePath {
        let path = dir.appending(name)
        try Data(content.utf8).write(to: URL(filePath: path)!)
        return path
    }

    static func createFiles(
        dir: FilePath,
        content: [String]
    ) throws -> [FilePath] {
        return try content.enumerated().map { index, content in
            try createFile(
                dir: dir,
                name: "\(index)",
                content: content
            )
        }
    }

    static func create3Files(
        dir: FilePath,
    ) throws -> (FilePath, FilePath, FilePath) {
        let all = try createFiles(
            dir: dir,
            content: [
                #"""
                From: a@example.apple.com
                Subject: A
                Message-id: <a-1@example.apple.com>
                Date: Tue, 13 Sep 2016 04:08:04 -0700

                a
                """#,
                #"""
                From: b@example.apple.com
                Subject: B
                Message-id: <b-2@example.apple.com>
                Date: Tue, 30 Apr 2024 14:31:07 +0000

                b
                """#,
                #"""
                From: c@example.apple.com
                Subject: C
                Message-id: <c-3@example.apple.com>
                Date: Thu, 25 Apr 2024 16:41:32 +0200

                c
                """#,
            ]
        )
        try #require(all.count == 3)
        let a = all[0]
        let b = all[1]
        let c = all[2]
        return (a, b, c)
    }

    @Test
    static func readingSingleFile() async throws {
        try await withTemporaryDirectory { dir in
            let all = try createFiles(
                dir: dir,
                content: [
                    #"""
                    From: a@example.apple.com
                    Subject: A
                    Message-id: <a-1@example.apple.com>
                    Date: Tue, 13 Sep 2016 04:08:04 -0700

                    a
                    """#
                ]
            )
            let path = try #require(all.first)

            let result = try await FileBasedMessageToAppendSequence.readSingleMessage(
                path: path,
                originalIndex: 95_824
            )
            #expect(
                result
                    == FileBasedMessageToAppendSequence.IndexedFilePath(
                        originalIndex: 95_824,
                        nestedIndex: 0,
                        path: .init(
                            filePath: path,
                            date: Date(timeIntervalSinceReferenceDate: 495_457_684)
                        )
                    )
            )
        }
    }

    @Test
    static func readingSingleFileWithInvalidDate() async throws {
        try await withTemporaryDirectory { dir in
            let all = try createFiles(
                dir: dir,
                content: [
                    #"""
                    From: a@example.apple.com
                    Subject: A
                    Message-id: <a-1@example.apple.com>
                    Date: foo bar baz

                    a
                    """#
                ]
            )
            let path = try #require(all.first)

            do {
                _ = try await FileBasedMessageToAppendSequence.readSingleMessage(
                    path: path,
                    originalIndex: 95_824
                )
                Issue.record("Should have thrown an error")
            } catch let error as FileBasedMessageToAppendSequence.UnableToParseFile {
                #expect(error.filePath == path)
                #expect(
                    (error.underlying as? FileBasedMessageToAppendSequence.UnableToParseDate)?.date == "foo bar baz"
                )
            }
        }
    }

    @Test
    static func readingSingleFileWithoutDate() async throws {
        try await withTemporaryDirectory { dir in
            let all = try createFiles(
                dir: dir,
                content: [
                    #"""
                    From: a@example.apple.com
                    Subject: A
                    Message-id: <a-1@example.apple.com>

                    a
                    """#
                ]
            )
            let path = try #require(all.first)

            do {
                _ = try await FileBasedMessageToAppendSequence.readSingleMessage(
                    path: path,
                    originalIndex: 95_824
                )
                Issue.record("Should have thrown an error")
            } catch let error as FileBasedMessageToAppendSequence.UnableToParseFile {
                #expect(error.filePath == path)
                #expect((error.underlying as? FileBasedMessageToAppendSequence.NoMessageDateInFile) != nil)
            }
        }
    }

    @Test
    static func readDirectory() async throws {
        try await withTemporaryDirectory { dir in
            let (a, b, c) = try create3Files(dir: dir)

            let files = try FileBasedMessageToAppendSequence.allRegularFiles(in: dir)
            #expect(Set(files) == Set([a, b, c]))

            let messages = try await FileBasedMessageToAppendSequence.readDirectory(
                directoryPath: dir,
                originalIndex: 75_465
            ).compactMap {
                try? $0.get()
            }.sorted(by: { $0.sortIndex < $1.sortIndex })
            #expect(messages.map { $0.originalIndex } == [75_465, 75_465, 75_465])
            #expect(messages.map { $0.nestedIndex } == [0, 1, 2])
            #expect(Set(messages.map { $0.path.filePath }) == Set([a, b, c]))
        }
    }

    @Test
    static func readDirectorySkippingUnreadableFiles() async throws {
        try await withTemporaryDirectory { dir in
            let all = try createFiles(
                dir: dir,
                content: [
                    #"""
                    This is not an email
                    """#,
                    #"""
                    From: a@example.apple.com
                    Subject: A
                    Message-id: <a-1@example.apple.com>
                    Date: Tue, 13 Sep 2016 04:08:04 -0700

                    a
                    """#,
                    #"""
                    From: b@example.apple.com
                    Subject: B
                    Message-id: <b-2@example.apple.com>
                    Date: invalid date

                    b
                    """#,
                ]
            )
            try #require(all.count == 3)
            let a = all[0]
            let b = all[1]
            let c = all[2]

            let files = try FileBasedMessageToAppendSequence.allRegularFiles(in: dir)
            #expect(Set(files) == Set(all))

            let result = try await FileBasedMessageToAppendSequence.readDirectory(
                directoryPath: dir,
                originalIndex: 75_465
            )
            let messages = result.compactMap {
                try? $0.get()
            }.sorted(by: { $0.sortIndex < $1.sortIndex })
            #expect(messages.map { $0.originalIndex } == [75_465])
            #expect(messages.map { $0.path.filePath } == [b])

            let errors: [FileBasedMessageToAppendSequence.UnableToParseFile] = result.compactMap {
                guard case .failure(let error) = $0 else { return nil }
                return error
            }
            #expect(Set(errors.map { $0.filePath }) == Set([a, c]))
        }
    }

    @Test
    static func sortedFileSequence() async throws {
        try await withTemporaryDirectory { dir in
            let (a, b, c) = try create3Files(dir: dir)

            let seq = FileBasedMessageToAppendSequence(
                paths: [
                    a,
                    b,
                    c,
                ],
                options: [.sort]  // <-- Messages should be sorted by date
            )

            let messages: [MessageToAppend<FilePath>] = try await seq.reduce(into: []) {
                $0.append($1)
            }

            #expect(
                messages.map { $0.id } == [a, c, b]
            )
            #expect(
                messages.map { $0.messageID } == [
                    MessageID("<a-1@example.apple.com>"),
                    MessageID("<c-3@example.apple.com>"),
                    MessageID("<b-2@example.apple.com>"),
                ]
            )

            #expect(
                messages.map { $0.serverMessageDate } == [
                    ServerMessageDate(
                        .init(year: 2016, month: 9, day: 13, hour: 11, minute: 8, second: 4, timeZoneMinutes: 0)!
                    ),
                    ServerMessageDate(
                        .init(year: 2024, month: 4, day: 25, hour: 14, minute: 41, second: 32, timeZoneMinutes: 0)!
                    ),
                    ServerMessageDate(
                        .init(year: 2024, month: 4, day: 30, hour: 14, minute: 31, second: 7, timeZoneMinutes: 0)!
                    ),
                ],
            )
        }
    }

    @Test
    static func unsortedFileSequence() async throws {
        try await withTemporaryDirectory { dir in
            let (a, b, c) = try create3Files(dir: dir)

            let seq = FileBasedMessageToAppendSequence(
                paths: [
                    a,
                    b,
                    c,
                ],
                options: []  // <-- no sorting
            )

            let messages: [MessageToAppend<FilePath>] = try await seq.reduce(into: []) {
                $0.append($1)
            }

            #expect(
                messages.map { $0.id } == [a, b, c]
            )
            #expect(
                messages.map { $0.messageID } == [
                    MessageID("<a-1@example.apple.com>"),
                    MessageID("<b-2@example.apple.com>"),
                    MessageID("<c-3@example.apple.com>"),
                ]
            )

            #expect(
                messages.map { $0.serverMessageDate } == [
                    ServerMessageDate(
                        .init(year: 2016, month: 9, day: 13, hour: 11, minute: 8, second: 4, timeZoneMinutes: 0)!
                    ),
                    ServerMessageDate(
                        .init(year: 2024, month: 4, day: 30, hour: 14, minute: 31, second: 7, timeZoneMinutes: 0)!
                    ),
                    ServerMessageDate(
                        .init(year: 2024, month: 4, day: 25, hour: 14, minute: 41, second: 32, timeZoneMinutes: 0)!
                    ),
                ],
            )
        }
    }

    @Test
    static func fileSequenceSkippingInvalid() async throws {
        try await withTemporaryDirectory { dir in
            let all = try createFiles(
                dir: dir,
                content: [
                    #"""
                    This is not an email
                    """#,
                    #"""
                    From: b@example.apple.com
                    Subject: B
                    Message-id: <b-2@example.apple.com>
                    Date: Tue, 30 Apr 2024 14:31:07 +0000

                    b
                    """#,
                ]
            )
            try #require(all.count == 2)
            let a = all[0]
            let b = all[1]
            let c = dir.appending("does-not-exist")

            let seq = FileBasedMessageToAppendSequence(
                paths: [
                    a,
                    b,
                    c,
                ],
                options: [.skipErrors]
            )

            let messages: [MessageToAppend<FilePath>] = try await seq.reduce(into: []) {
                $0.append($1)
            }

            #expect(
                messages.map { $0.id } == [b]
            )
            #expect(
                messages.map { $0.messageID } == [
                    MessageID("<b-2@example.apple.com>")
                ]
            )

            #expect(
                messages.map { $0.serverMessageDate } == [
                    ServerMessageDate(
                        .init(year: 2024, month: 4, day: 30, hour: 14, minute: 31, second: 7, timeZoneMinutes: 0)!
                    )
                ],
            )
        }
    }

    struct UnableToCreateDirectory: Swift.Error {}

    @Test
    static func fileSequenceWithDirectories() async throws {
        try await withTemporaryDirectory { topLevelDir in
            let dirA = topLevelDir.appending("A")
            try dirA.withPlatformString { path in
                guard mkdir(path, 0o777) == 0 else { throw UnableToCreateDirectory() }
            }

            let dirB = topLevelDir.appending("B")
            try dirB.withPlatformString { path in
                guard mkdir(path, 0o777) == 0 else { throw UnableToCreateDirectory() }
            }

            let filesA = try createFiles(
                dir: dirA,
                content: [
                    #"""
                    From: b@example.apple.com
                    Subject: B
                    Message-id: <b-2@example.apple.com>
                    Date: Tue, 30 Apr 2024 14:31:07 +0000

                    b
                    """#
                ]
            )
            try #require(filesA.count == 1)
            let b = filesA[0]

            let filesB = try createFiles(
                dir: dirB,
                content: [
                    #"""
                    This is not an email
                    """#,
                    #"""
                    From: a@example.apple.com
                    Subject: A
                    Message-id: <a-1@example.apple.com>
                    Date: Tue, 13 Sep 2016 04:08:04 -0700

                    a
                    """#,
                    #"""
                    From: c@example.apple.com
                    Subject: C
                    Message-id: <c-3@example.apple.com>
                    Date: Thu, 25 Apr 2024 16:41:32 +0200

                    c
                    """#,
                ]
            )
            try #require(filesB.count == 3)
            let a = filesB[1]
            let c = filesB[2]

            let seq = FileBasedMessageToAppendSequence(
                paths: [
                    dirA,
                    dirB,
                ],
                options: [.skipErrors, .sort]
            )

            let messages: [MessageToAppend<FilePath>] = try await seq.reduce(into: []) {
                $0.append($1)
            }

            #expect(
                messages.map { $0.id } == [a, c, b]
            )
        }
    }

    @Test
    static func flagExtraction_fromOptions() async throws {
        try await withTemporaryDirectory { dir in
            let (file, _, _) = try create3Files(dir: dir)
            let flags: [NIOIMAP.Flag] = [.seen, .flagged, .answered]

            let seq = FileBasedMessageToAppendSequence(
                paths: [file],
                options: [.flags(flags)]
            )

            let message = try await seq.first { _ in true }
            #expect(message?.flags == flags)
        }
    }

    @Test
    static func flagExtraction_noFlags() async throws {
        try await withTemporaryDirectory { dir in
            let (file, _, _) = try create3Files(dir: dir)

            let seq = FileBasedMessageToAppendSequence(
                paths: [file],
                options: []
            )

            let message = try await seq.first { _ in true }
            #expect(message?.flags == nil || message?.flags?.isEmpty == true)
        }
    }

    @Test
    static func flagExtraction_emptyFlags() async throws {
        try await withTemporaryDirectory { dir in
            let (file, _, _) = try create3Files(dir: dir)

            let seq = FileBasedMessageToAppendSequence(
                paths: [file],
                options: [.flags([])]
            )

            let message = try await seq.first { _ in true }
            #expect(message?.flags == nil)
        }
    }

    @Test
    static func flagExtraction_multipleFiles() async throws {
        try await withTemporaryDirectory { dir in
            let (a, b, c) = try create3Files(dir: dir)
            let flags: [NIOIMAP.Flag] = [.seen, .draft]

            let seq = FileBasedMessageToAppendSequence(
                paths: [a, b, c],
                options: [.flags(flags)]
            )

            let messages: [MessageToAppend<FilePath>] = try await seq.reduce(into: []) {
                $0.append($1)
            }

            // All messages should have the same flags
            for message in messages {
                #expect(message.flags == flags)
            }
        }
    }

    @Test
    static func flagExtraction_customFlags() async throws {
        try await withTemporaryDirectory { dir in
            let (file, _, _) = try create3Files(dir: dir)
            let customFlag = NIOIMAP.Flag("\\CustomFlag")
            let recentFlag = NIOIMAP.Flag("\\Recent")
            let flags: [NIOIMAP.Flag] = [.seen, customFlag, recentFlag]

            let seq = FileBasedMessageToAppendSequence(
                paths: [file],
                options: [.flags(flags)]
            )

            let message = try await seq.first { _ in true }
            #expect(message?.flags == flags)
        }
    }

    @Test
    static func flagExtraction_mixedOptions() async throws {
        try await withTemporaryDirectory { dir in
            let (file, _, _) = try create3Files(dir: dir)
            let flags: [NIOIMAP.Flag] = [.flagged, .answered]

            let seq = FileBasedMessageToAppendSequence(
                paths: [file],
                options: [.skipErrors, .sort, .flags(flags), .createMailbox([])]
            )

            let message = try await seq.first { _ in true }
            #expect(message?.flags == flags)
        }
    }
}
