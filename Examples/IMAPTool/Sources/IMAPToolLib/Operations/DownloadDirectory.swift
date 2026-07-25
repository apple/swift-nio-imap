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

#if canImport(System)
import System
#else
import SystemPackage
#endif
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
import NIOIMAP
import Dispatch
import NIOConcurrencyHelpers

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
            guard
                Darwin.unlink(path) == 0
            else {
                let error = Errno(rawValue: errno)
                throw error
            }
        }
    }
}

// MARK: -

private let ioQueue = DispatchQueue(label: "download-io")

extension DownloadDirectory {
    struct Writer: ~Copyable {
        let uid: UID
        private let io: DispatchIO
        private let state: NIOLockedValueBox<State>

        enum State {
            /// Writing to the channel is in progress.
            case writing([CheckedContinuation<(), Never>])
            /// Writing succeeded, but the channel has not closed yet.
            ///
            /// The file moves into place when the channel closes.
            case doneWriting([CheckedContinuation<(), Never>])
            /// Writing failed, but the channel has not closed yet.
            case failed([CheckedContinuation<(), Never>])
            /// The channel’s completion handler has run.
            case didComplete

            mutating func markAsClosed(
                didSucceed: Bool
            ) {
                switch (self, didSucceed) {
                case (.writing(let c), true):
                    self = .doneWriting(c)
                case (.writing(let c), false):
                    self = .failed(c)
                case (.doneWriting, _), (.failed, _), (.didComplete, _):
                    break
                }
            }
        }

        init(
            uid: UID,
            path: FilePath,
            finalPath: FilePath
        ) throws {
            self.uid = uid
            let state = NIOLockedValueBox(State.writing([]))
            let io: DispatchIO
            guard
                let finalFilename = finalPath.lastComponent
            else { throw InvalidFilePath(path: finalPath) }
            io = try DispatchIO.streamWrite(
                path: path
            ) { error in
                enum Step {
                    case run(didSucceed: Bool, continuations: [CheckedContinuation<(), Never>], logMessage: Output?)
                    case alreadyCompleted
                }
                // Transition to `.didComplete` and take ownership of the parked
                // continuations *while holding the lock*. This closes the race with
                // `waitForCompletion()`: a continuation parked before this runs is
                // resumed here; one that races after observes `.didComplete` and
                // resumes itself. Either way none is orphaned.
                let step: Step = state.withLockedValue { s in
                    switch s {
                    case .writing(let c):
                        s = .didComplete
                        return .run(
                            didSucceed: false,
                            continuations: c,
                            logMessage:
                                "error: failed to write file '\(String(decoding: finalFilename))' (errno \(error)) — never called close()"
                        )
                    case .failed(let c):
                        s = .didComplete
                        return .run(
                            didSucceed: false,
                            continuations: c,
                            logMessage: "error: failed to write file '\(String(decoding: finalFilename))' (errno \(error))"
                        )
                    case .doneWriting(let c):
                        s = .didComplete
                        if error == 0 {
                            return .run(didSucceed: true, continuations: c, logMessage: nil)
                        } else {
                            return .run(
                                didSucceed: false,
                                continuations: c,
                                logMessage: "error: IO while writing file '\(String(decoding: finalFilename))' (errno \(error))"
                            )
                        }
                    case .didComplete:
                        return .alreadyCompleted
                    }
                }

                guard case .run(let didSucceed, let continuations, let logMessage) = step else { return }
                if let logMessage {
                    writeStatus(logMessage)
                }
                defer {
                    for c in continuations {
                        c.resume()
                    }
                }
                guard didSucceed else { return }
                rename(old: path, new: finalPath)
            }
            self.state = state
            self.io = io
        }

        func write(_ data: DispatchData) {
            io.write(offset: 0, data: data, queue: ioQueue, ioHandler: { _, _, _ in })
        }

        func closeAndFail() {
            close(didSucceed: false)
        }

        func closeAndSucceed() {
            close(didSucceed: true)
        }

        fileprivate func close(
            didSucceed: Bool
        ) {
            state.withLockedValue {
                $0.markAsClosed(didSucceed: didSucceed)
            }
            io.close()
        }

        func close() {
            io.close()
        }

        /// Waits for the underlying channel’s completion handler to run.
        ///
        /// Returns after the file is written, closed, and moved into place.
        func waitForCompletion() async {
            // Call close. This is a no-op if it’s already closed, but
            // will make sure that the completion closure will run if
            // the channel hasn’t already been closed.
            io.close()
            await withCheckedContinuation { c in
                let cc = state.withLockedValue { s -> CheckedContinuation<(), Never>? in
                    switch s {
                    case .writing(var continuations):
                        continuations.append(c)
                        s = .writing(continuations)
                        return nil
                    case .doneWriting(var continuations):
                        continuations.append(c)
                        s = .doneWriting(continuations)
                        return nil
                    case .failed(var continuations):
                        continuations.append(c)
                        s = .failed(continuations)
                        return nil
                    case .didComplete:
                        return c
                    }
                }
                cc?.resume()
            }
        }

        deinit {
            io.close()
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

private func rename(old: FilePath, new: FilePath) {
    old.withPlatformString { platformOld in
        new.withPlatformString { platformNew in
            let result = rename(platformOld, platformNew)
            if result != 0 {
                let error = errno
                let oldPath = String(decoding: old)
                if let filename = new.lastComponent {
                    writeStatus(
                        "error: failed to move file '\(String(decoding: filename))' into place (errno \(error)) — message was downloaded but remains at temp path '\(oldPath)'"
                    )
                } else {
                    writeStatus(
                        "error: failed to move file into place (errno \(error)) — message was downloaded but remains at temp path '\(oldPath)'"
                    )
                }
            }
        }
    }
}

extension DispatchIO {
    static func streamWrite(
        path: FilePath,
        cleanupHandler: @escaping (Int32) -> Void
    ) throws -> DispatchIO {
        let io = path.withPlatformString { platformPath in
            DispatchIO(
                type: .stream,
                path: platformPath,
                oflag: O_WRONLY | O_CREAT | O_EXCL,
                mode: 0o644,
                queue: ioQueue,
                cleanupHandler: cleanupHandler
            )
        }
        guard
            let io
        else {
            struct UnableToCreateFile: Swift.Error {}
            throw UnableToCreateFile()
        }
        return io
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
