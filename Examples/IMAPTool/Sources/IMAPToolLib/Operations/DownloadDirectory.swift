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

import SystemPackage
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
import NIOCore
import NIOFileSystem
import NIOIMAP

/// Tracks which message files exist in a download directory and determines file names for new downloads.
struct DownloadDirectory: Sendable {
    let root: FilePath
    let uidValidity: UIDValidity
    private(set) var downloadedUIDs: UIDSet
    private var tempFilePrefix = Int.random(in: 1_000...9_999)
}

extension DownloadDirectory {
    /// Opens the directory, deleting temporary files and files with a different UID validity.
    ///
    /// - Parameter directory: The path to an existing directory for downloading messages.
    /// - Parameter uidValidity: The current UID validity of the mailbox on the server.
    static func openDeletingInvalidFiles(
        directory root: FilePath,
        uidValidity: UIDValidity,
        deleteUnknown: Bool
    ) throws -> DownloadDirectory {
        var dir = DownloadDirectory(
            root: root,
            uidValidity: uidValidity,
            downloadedUIDs: UIDSet()
        )
        try Self.withFilenames(in: root) { filename in
            switch filename {
            case .message(let uid, uidValidity):
                dir.downloadedUIDs.insert(uid)
            case .message(let uid, let other):
                guard deleteUnknown else { break }
                writeStatus("Deleting message with wrong UID validity \(other), UID \(uid)")
                dir.unlink(file: filename)
            case .temporary:
                guard deleteUnknown else { break }
                writeStatus("Deleting temporary message")
                dir.unlink(file: filename)
            }
        }
        if dir.downloadedUIDs.isEmpty {
            writeStatus("Did find no previously downloaded messages")
        } else {
            writeStatus("Did find \(dir.downloadedUIDs.count) previously downloaded message(s)")
        }
        return dir
    }
}

// MARK: -

extension DownloadDirectory {
    /// Delete the given file in the directory.
    func unlink(file: Filename) {
        do {
            try root.appending(file).unlink()
        } catch {
            writeStatus("error: failed to delete '\(String(decoding: FilePath.Component(file)))' (\(error))")
        }
    }

    mutating func unlinkFiles(notIncludedIn uids: UIDSet) {
        let toDelete = downloadedUIDs.subtracting(uids)
        guard !toDelete.isEmpty else { return }
        writeStatus("Deleting \(toDelete.count) downloaded message(s) that no longer exist on the server")
        for uid in toDelete {
            unlink(file: .message(uid, uidValidity))
        }
        downloadedUIDs.subtract(toDelete)
    }
}

extension FilePath {
    func appending(_ filename: DownloadDirectory.Filename) -> FilePath {
        appending(FilePath.Component(filename))
    }

    func unlink() throws {
        try withPlatformString { path in
            // Qualified because an unqualified `unlink` would resolve to this method.
            #if canImport(Glibc)
            let result = Glibc.unlink(path)
            #elseif canImport(Darwin)
            let result = Darwin.unlink(path)
            #endif
            guard
                result == 0
            else {
                let error = Errno(rawValue: errno)
                throw error
            }
        }
    }
}

// MARK: -

extension DownloadDirectory {
    /// Writes a downloaded message to a temporary file, then moves it into place.
    ///
    /// Writing to `NIOFileSystem` is `async`, but callers hand over chunks synchronously as
    /// they arrive off the connection. The chunks therefore go into a stream that a
    /// detached task drains, and the file is opened, written, closed, and renamed entirely
    /// inside that task. `waitForCompletion()` awaits it.
    struct Writer: ~Copyable {
        let uid: UID
        private let continuation: AsyncStream<Chunk>.Continuation
        private let task: Task<Void, Never>

        /// A unit of work handed to the writing task.
        fileprivate enum Chunk: Sendable {
            case write(ByteBuffer)
            /// Stop writing and discard the file.
            case fail
        }

        init(
            uid: UID,
            path: FilePath,
            finalPath: FilePath
        ) throws {
            self.uid = uid
            guard
                let finalFilename = finalPath.lastComponent
            else { throw InvalidFilePath(path: finalPath) }
            let name = String(decoding: finalFilename)

            let (stream, continuation) = AsyncStream.makeStream(of: Chunk.self)
            self.continuation = continuation
            self.task = Task {
                await Writer.run(
                    stream: stream,
                    path: path,
                    finalPath: finalPath,
                    name: name
                )
            }
        }

        /// Consumes `stream`, writing each chunk to the file at `path`.
        ///
        /// The file is renamed to `finalPath` only if the stream completes without a
        /// `.fail` chunk and every write succeeds.
        private static func run(
            stream: AsyncStream<Chunk>,
            path: FilePath,
            finalPath: FilePath,
            name: String
        ) async {
            do {
                let didSucceed = try await FileSystem.shared.withFileHandle(
                    forWritingAt: path,
                    options: .newFile(replaceExisting: true)
                ) { handle -> Bool in
                    var offset: Int64 = 0
                    for await chunk in stream {
                        switch chunk {
                        case .write(let buffer):
                            offset += try await handle.write(
                                contentsOf: buffer.readableBytesView,
                                toAbsoluteOffset: offset
                            )
                        case .fail:
                            return false
                        }
                    }
                    return true
                }
                guard didSucceed else {
                    await Writer.removeTemporaryFile(at: path)
                    return
                }
                try await FileSystem.shared.moveItem(at: path, to: finalPath)
            } catch {
                writeStatus("error: failed to write file '\(name)' (\(error))")
                await Writer.removeTemporaryFile(at: path)
            }
        }

        /// Removes the partially written file, ignoring the case where it was never created.
        private static func removeTemporaryFile(at path: FilePath) async {
            do {
                _ = try await FileSystem.shared.removeItem(at: path)
            } catch {
                writeStatus("error: failed to remove temporary file '\(path)' (\(error))")
            }
        }

        func write(_ buffer: ByteBuffer) {
            continuation.yield(.write(buffer))
        }

        func closeAndFail() {
            continuation.yield(.fail)
            continuation.finish()
        }

        func closeAndSucceed() {
            continuation.finish()
        }

        func close() {
            continuation.finish()
        }

        /// Waits for the file to be written, closed, and moved into place.
        func waitForCompletion() async {
            // Finishing is a no-op if the stream is already finished, but it makes sure
            // the writing task can run to completion rather than waiting for more chunks.
            continuation.finish()
            await task.value
        }

        deinit {
            continuation.finish()
        }
    }

    /// Creates a `Writer` to write data for the given message.
    func makeWriter(
        uid: UID
    ) throws -> Writer {
        try Writer(
            uid: uid,
            path: root.appending(.temporary("\(tempFilePrefix).\(uid)")),
            finalPath: root.appending(.message(uid, uidValidity))
        )
    }

    mutating func didDownload(uid: UID) {
        downloadedUIDs.insert(uid)
    }
}

private struct InvalidFilePath: Swift.Error {
    var path: String
    init(path: FilePath) {
        self.path = String(decoding: path)
    }
}

// MARK: - Enumerating (Existing) Files

extension DownloadDirectory {
    static func withFilenames(
        in directory: FilePath,
        closure: (Filename) -> Void
    ) throws {
        try scan(directory: directory) { entry in
            guard let f = Filename(dirent: entry) else { return }
            closure(f)
        }
    }
}

extension FilePath.Component {
    init(_ other: DownloadDirectory.Filename) {
        switch other {
        case .message(let uid, let validity):
            // UIDVALIDITY is encoded as hex padded to an even number of digits.
            // The parser (`scanUIDValidity`) consumes the hex two digits at a time,
            // so writer and reader must agree on this padding.
            let b = String(UInt32(validity), radix: 16)
            self.init("\(UInt32(uid)).\(((b.count % 2) == 0) ? "" : "0")\(b).message")!
        case .temporary(let id):
            self.init(".\(id).message")!
        }
    }
}

extension DownloadDirectory.Filename {
    init?(dirent entry: UnsafePointer<dirent>) {
        guard
            let parsed = withRegularFileName(
                dirent: entry,
                { buffer in
                    DownloadDirectory.Filename(regularFilename: buffer)
                }
            )
        else { return nil }
        self = parsed
    }

    init?(
        regularFilename filename: borrowing UnsafeBufferPointer<Unicode.UTF8.CodeUnit>
    ) {
        var remainder = filename[...]
        if remainder.popDot() {
            guard
                remainder.dropMessageSuffix(),
                let s = String(validating: remainder, as: UTF8.self)
            else { return nil }
            self = .temporary(s)
        } else {
            guard
                remainder.dropMessageSuffix(),
                let uid = remainder.scanUID(),
                remainder.popDot(),
                let validity = remainder.scanUIDValidity(),
                remainder.isEmpty
            else { return nil }
            self = .message(uid, validity)
        }
    }
}

// MARK: - File Names

extension DownloadDirectory {
    enum Filename: Hashable, Sendable {
        case message(UID, UIDValidity)
        case temporary(String)
    }
}

private let fileExtension: StaticString = ".message"

extension Slice<UnsafeBufferPointer<Unicode.UTF8.CodeUnit>> {
    /// If the buffer has a ".message" suffix remove it and return `true`,
    /// return `false` otherwise.
    fileprivate mutating func dropMessageSuffix() -> Bool {
        guard
            fileExtension.utf8CodeUnitCount < self.count
        else { return false }
        // Check for ".message" file extension
        let start = self.index(self.endIndex, offsetBy: -fileExtension.utf8CodeUnitCount)
        let a = self[start...]
        let b = UnsafeBufferPointer(
            start: fileExtension.utf8Start,
            count: fileExtension.utf8CodeUnitCount
        )[...]
        guard
            zip(a, b).allSatisfy({ $0.0 == $0.1 })
        else { return false }

        self = self[..<start]
        return true
    }

    fileprivate mutating func scanUID() -> UID? {
        guard
            var result = popNumber().map({ UInt32($0) })
        else { return nil }
        while true {
            guard
                let next = popNumber()
            else { return UID(exactly: result) }
            // Widen to `UInt64` _before_ multiplying so an overflowing filename
            // (e.g. `9999999999.0001.message`) makes the guard below skip the
            // file rather than trapping on `UInt32` overflow.
            let a = UInt64(result) * 10 + UInt64(next)
            guard
                let b = UInt32(exactly: a)
            else { return nil }
            result = b
        }
    }

    fileprivate mutating func scanUIDValidity() -> UIDValidity? {
        guard
            var result = popDoubleHex().map({ UInt32($0) })
        else { return nil }
        while true {
            guard
                let next = popDoubleHex()
            else { return UIDValidity(exactly: result) }
            // Widen to `UInt64` _before_ multiplying so an overflowing validity
            // segment makes the guard below skip the file rather than trapping.
            let a = UInt64(result) * 256 + UInt64(next)
            guard
                let b = UInt32(exactly: a)
            else { return nil }
            result = b
        }
    }

    fileprivate mutating func popDot() -> Bool {
        guard first == UTF8.CodeUnit(ascii: ".") else { return false }
        self = dropFirst()
        return true
    }

    fileprivate mutating func popNumber() -> UInt8? {
        guard
            let f = first,
            UTF8.CodeUnit(ascii: "0") <= f,
            f <= UTF8.CodeUnit(ascii: "9")
        else { return nil }
        self = dropFirst()
        return f - UTF8.CodeUnit(ascii: "0")
    }

    fileprivate mutating func popDoubleHex() -> UInt8? {
        guard
            2 <= count
        else { return nil }
        guard
            let a = self[self.startIndex].hexValue,
            let b = self[self.index(after: self.startIndex)].hexValue
        else { return nil }
        self = dropFirst(2)
        return a << 4 + b
    }
}

extension UTF8.CodeUnit {
    fileprivate var hexValue: UInt8? {
        switch self {
        case UTF8.CodeUnit(ascii: "0")...UTF8.CodeUnit(ascii: "9"):
            self - UTF8.CodeUnit(ascii: "0")
        case UTF8.CodeUnit(ascii: "a")...UTF8.CodeUnit(ascii: "f"):
            self - UTF8.CodeUnit(ascii: "a") + 10
        case UTF8.CodeUnit(ascii: "A")...UTF8.CodeUnit(ascii: "F"):
            self - UTF8.CodeUnit(ascii: "A") + 10
        default:
            nil
        }
    }
}
