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
import NIOIMAP
#if canImport(System)
import System
#else
import SystemPackage
#endif
import Testing
@testable import IMAPToolLib

@Suite
enum DownloadDirectoryTests {
    @Test
    static func filePathComponent() async throws {
        #expect(
            FilePath.Component(DownloadDirectory.Filename.message(1, 1)).description
                == "1.01.message"
        )
        #expect(
            FilePath.Component(DownloadDirectory.Filename.message(790_954, 212_451)).description
                == "790954.033de3.message"
        )
        #expect(
            FilePath.Component(DownloadDirectory.Filename.message(121_047_307, 8_445_624)).description
                == "121047307.80deb8.message"
        )
        #expect(
            FilePath.Component(DownloadDirectory.Filename.temporary("12bt3x434A56")).description
                == ".12bt3x434A56.message"
        )
    }

    @Test(arguments: [
        (
            "790954.033de3.message",
            DownloadDirectory.Filename.message(790_954, 212_451)
        ),
        (
            "1.01.message",
            DownloadDirectory.Filename.message(1, 1)
        ),
        (
            ".12bt3x434A56.message",
            DownloadDirectory.Filename.temporary("12bt3x434A56")
        ),
    ])
    static func initFromFilename(
        fixture: (String, DownloadDirectory.Filename)
    ) async throws {
        var name = fixture.0
        name.withUTF8 { buffer in
            #expect(
                DownloadDirectory.Filename(regularFilename: buffer)
                    == fixture.1
            )
        }
    }

    /// Malformed filenames — in particular ones whose UID or UID-validity would
    /// overflow `UInt32` — must be rejected (returning `nil`) without trapping,
    /// so a stray file in the download directory is simply skipped.
    @Test(arguments: [
        "9999999999.0001.message",  // UID overflows UInt32
        "4294967296.01.message",  // UID = UInt32.max + 1
        "0.01.message",  // UID 0 is invalid
        "1.ffffffffff.message",  // UID-validity overflows UInt32
        "1.0100000000.message",  // UID-validity = UInt32.max + 1
    ])
    static func initFromFilenameRejectsOverflow(name: String) async throws {
        var name = name
        name.withUTF8 { buffer in
            #expect(DownloadDirectory.Filename(regularFilename: buffer) == nil)
        }
    }

    @Test
    static func directoryEnumeration() async throws {
        try await withTemporaryDirectory { dir in
            func create(name: FilePath.Component) throws {
                let path = dir.appending(name)
                try Data().write(to: URL(filePath: path)!)
            }

            try create(name: "790954.033de3.message")
            try create(name: ".12bt3x434A56.message")
            try create(name: "121047307.80deb8.message")
            try create(name: ".aXmooQRwysCmrgQG.message")

            var all = Set<DownloadDirectory.Filename>()
            var count = 0
            try DownloadDirectory.withFilenames(in: dir) {
                count += 1
                all.insert($0)
            }

            #expect(count == 4)
            #expect(
                all == [
                    .message(790_954, 212_451),
                    .message(121_047_307, 8_445_624),
                    .temporary("12bt3x434A56"),
                    .temporary("aXmooQRwysCmrgQG"),
                ]
            )
        }
    }

    @Test
    static func deletingOtherFiles() async throws {
        try await withTemporaryDirectory { dir in
            func create(name: FilePath.Component) throws {
                let path = dir.appending(name)
                try Data().write(to: URL(filePath: path)!)
            }

            try create(name: "790954.033de3.message")
            try create(name: ".12bt3x434A56.message")
            try create(name: "121047307.80deb8.message")
            try create(name: ".aXmooQRwysCmrgQG.message")
            try create(name: "545548.033de3.message")

            let sut = try DownloadDirectory.openDeletingInvalidFiles(
                directory: dir,
                uidValidity: 212_451,
                deleteUnknown: true
            )

            #expect(fileExists(at: dir.appending("790954.033de3.message")))
            #expect(!fileExists(at: dir.appending(".12bt3x434A56.message")))
            #expect(!fileExists(at: dir.appending("121047307.80deb8.message")))
            #expect(!fileExists(at: dir.appending(".aXmooQRwysCmrgQG.message")))
            #expect(fileExists(at: dir.appending("545548.033de3.message")))

            #expect(sut.root == dir)
            #expect(sut.downloadedUIDs == [790_954, 545_548])
        }
    }

    @Test
    static func notDeletingOtherFiles() async throws {
        try await withTemporaryDirectory { dir in
            func create(name: FilePath.Component) throws {
                let path = dir.appending(name)
                try Data().write(to: URL(filePath: path)!)
            }

            try create(name: "790954.033de3.message")
            try create(name: ".12bt3x434A56.message")
            try create(name: "121047307.80deb8.message")
            try create(name: ".aXmooQRwysCmrgQG.message")
            try create(name: "545548.033de3.message")

            let sut = try DownloadDirectory.openDeletingInvalidFiles(
                directory: dir,
                uidValidity: 212_451,
                deleteUnknown: false
            )

            #expect(fileExists(at: dir.appending("790954.033de3.message")))
            #expect(fileExists(at: dir.appending(".12bt3x434A56.message")))
            #expect(fileExists(at: dir.appending("121047307.80deb8.message")))
            #expect(fileExists(at: dir.appending(".aXmooQRwysCmrgQG.message")))
            #expect(fileExists(at: dir.appending("545548.033de3.message")))

            #expect(sut.root == dir)
            #expect(sut.downloadedUIDs == [790_954, 545_548])
        }
    }

    @Test
    static func fileWriter() async throws {
        try await withTemporaryDirectory { dir in
            print("A: ", String(decoding: dir))

            let sut = try DownloadDirectory.openDeletingInvalidFiles(
                directory: dir,
                uidValidity: 212_451,
                deleteUnknown: false
            )

            do {
                let writer = try sut.makeWriter(uid: 790_954)
                let bytesA: [UInt8] = [0x1, 0x2, 0x3, 0x4]
                bytesA.withUnsafeBufferPointer { buffer in
                    writer.write(DispatchData(bytes: UnsafeRawBufferPointer(buffer)))
                }
                let bytesB: [UInt8] = [0xa1, 0xa2, 0xa3, 0xa4]
                bytesB.withUnsafeBufferPointer { buffer in
                    writer.write(DispatchData(bytes: UnsafeRawBufferPointer(buffer)))
                }
                writer.closeAndSucceed()
                await writer.waitForCompletion()

                #expect(fileExists(at: dir.appending("790954.033de3.message")))

                #expect(
                    Data(contentsOf: dir.appending("790954.033de3.message"))
                        == Data([0x1, 0x2, 0x3, 0x4, 0xa1, 0xa2, 0xa3, 0xa4])
                )
            }

            do {
                let writer = try sut.makeWriter(uid: 545_548)
                let bytesA: [UInt8] = [0x1, 0x2, 0x3, 0x4]
                bytesA.withUnsafeBufferPointer { buffer in
                    writer.write(DispatchData(bytes: UnsafeRawBufferPointer(buffer)))
                }
                let bytesB: [UInt8] = [0xa1, 0xa2, 0xa3, 0xa4]
                bytesB.withUnsafeBufferPointer { buffer in
                    writer.write(DispatchData(bytes: UnsafeRawBufferPointer(buffer)))
                }
                writer.closeAndFail()  // <- Failing here.
                await writer.waitForCompletion()

                #expect(!fileExists(at: dir.appending("545548.033de3.message")))
            }
        }
    }
}

// MARK: -

func fileExists(at path: FilePath) -> Bool {
    (try? URL(filePath: path)?.checkResourceIsReachable()) == true
}

extension Data {
    init?(contentsOf path: FilePath) {
        guard
            let url = URL(filePath: path),
            let data = try? Data(contentsOf: url)
        else { return nil }
        self = data
    }
}

extension String {
    init?(contentsOf path: FilePath) {
        guard
            let data = Data(contentsOf: path)
        else { return nil }
        self = String(decoding: data, as: UTF8.self)
    }

    func write(to path: FilePath) throws {
        guard
            let url = URL(filePath: path)
        else { throw FilePathIsInvalid(path: path) }
        try Data(utf8).write(to: url)
    }
}

private struct FilePathIsInvalid: Swift.Error {
    var path: String
    init(path: String) {
        self.path = path
    }
    init(path: FilePath) {
        self.init(path: String(decoding: path))
    }
}
