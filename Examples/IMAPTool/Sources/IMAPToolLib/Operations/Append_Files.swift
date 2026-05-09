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

import IMAPCommands
import Dispatch
import NIO
import NIOIMAP
import System
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Uploads (`APPEND`s) the given messages into the given mailbox.
///
/// Selects the target mailbox first to receive any updates to it.
func append(
    connection: IMAPConnection,
    messages: [FilePath],
    options: Set<AppendOption>,
    into mailbox: MailboxName
) async throws -> [AppendedMessageInfo<FilePath>] {
    try await append(
        connection: connection,
        createMailbox: SelectCreateOption(options),
        messages: FileBasedMessageToAppendSequence(
            paths: messages,
            options: options
        ),
        into: mailbox
    )
}

/// Options that control the behavior of an `APPEND` operation.
enum AppendOption: Hashable, Sendable {
    /// Skips files that fail to parse instead of aborting.
    case skipErrors
    /// Sorts messages by date before uploading.
    case sort
    /// Creates the target mailbox with the given parameters if it does not exist.
    case createMailbox([CreateParameter])
    /// Sets these flags on all appended messages.
    case flags([NIOIMAP.Flag])
}

extension SelectCreateOption {
    init(
        _ other: Set<AppendOption>
    ) {
        for option in other {
            if case .createMailbox(let parameters) = option {
                self = .create(parameters)
                return
            }
        }
        self = .fail
    }
}

// MARK: -

/// An async sequence that reads email message files from disk and yields them as `MessageToAppend` values.
struct FileBasedMessageToAppendSequence: AsyncSequence, Sendable {
    typealias Element = MessageToAppend<FilePath>
    typealias Failure = any Swift.Error

    /// The file paths to read messages from.
    let paths: [FilePath]
    /// The options controlling how messages are read and processed.
    let options: Set<AppendOption>

    /// Creates a new sequence from the given file paths and options.
    init(
        paths: [FilePath],
        options: Set<AppendOption>
    ) {
        self.paths = paths
        self.options = options
    }

    struct AsyncIterator: AsyncIteratorProtocol {
        typealias Failure = any Swift.Error

        fileprivate let paths: [FilePath]
        fileprivate let options: Set<AppendOption>
        var remainingPaths: ArraySlice<FilePathWithDate>?
        private var sorted: Sorted = .initial

        fileprivate init(
            paths: [FilePath],
            options: Set<AppendOption>
        ) {
            self.paths = paths
            self.options = options
        }

        private enum Sorted {
            case initial
            case isReading
            case sorted([FilePathWithDate])
        }

        mutating func next() async throws -> MessageToAppend<FilePath>? {
            let flags = extractFlags(from: options)
            while true {
                guard
                    let pathWithDate = try await nextPath()
                else { return nil }
                do {
                    var message = try await MessageToAppend(
                        message: EmailMessage(filePath: pathWithDate.filePath),
                        id: pathWithDate.filePath
                    )
                    if !flags.isEmpty {
                        message.flags = flags
                    }
                    return message
                } catch {
                    writeStatus("error: failed to read message \(pathWithDate.filePath)")
                    guard options.contains(.skipErrors) else { throw error }
                }
            }
        }

        private func extractFlags(from options: Set<AppendOption>) -> [NIOIMAP.Flag] {
            for option in options {
                if case .flags(let flags) = option {
                    return flags
                }
            }
            return []
        }

        private mutating func nextPath() async throws -> FilePathWithDate? {
            var remaining: ArraySlice<FilePathWithDate>
            if let r = remainingPaths {
                remaining = r
            } else {
                remaining = try await sortedPaths()[...]
            }
            guard let next = remaining.popFirst() else { return nil }
            remainingPaths = remaining
            return next
        }

        private mutating func sortedPaths() async throws -> [FilePathWithDate] {
            switch sorted {
            case .initial:
                sorted = .isReading
                let paths = try await FileBasedMessageToAppendSequence.readAndSort(
                    paths: paths,
                    options: options
                )
                sorted = .sorted(paths)
                return paths
            case .isReading:
                fatalError("Recursively calling next() ?!?")
            case .sorted(let array):
                return array
            }
        }
    }

    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(
            paths: paths,
            options: options
        )
    }
}

extension FileBasedMessageToAppendSequence {
    struct IndexedFilePath: Hashable, Sendable {
        /// The index of the input argument (the order in which files were passed to the imap-tool).
        var originalIndex: UInt32
        /// If the input was a directory, this is the (relatively random) index within that directory.
        var nestedIndex: UInt32
        var path: FilePathWithDate

        var sortIndex: UInt64 {
            (UInt64(originalIndex) << 32) + UInt64(nestedIndex)
        }
    }

    /// The path of an email message file combined with its parsed `Date` header.
    ///
    /// This lets us sort input files based on their date.
    struct FilePathWithDate: Hashable, Sendable, Comparable {
        var filePath: FilePath
        var date: Date

        static func < (
            lhs: FileBasedMessageToAppendSequence.FilePathWithDate,
            rhs: FileBasedMessageToAppendSequence.FilePathWithDate
        ) -> Bool {
            lhs.date < rhs.date
        }
    }
}

extension FileBasedMessageToAppendSequence {
    /// Read an email message file, or all files inside a given directory.
    ///
    /// If `path` is a regular file, parse that file as a directory. If `path` is a directory,
    /// parse the files inside it.
    ///
    /// We attempt to read `path` as a single message first; only if that fails do we fall back
    /// to treating it as a directory. This skips an up-front `stat(2)` on the common case where
    /// the argument is a regular email file — the read itself tells us whether `path` is a file
    /// or directory, at the cost of a slightly less informative error when both interpretations
    /// fail.
    ///
    /// - Parameters:
    ///   - originalIndex: Used for (later) sorting messages according to their
    ///       original input order.
    static func readMessage(
        path: FilePath,
        originalIndex: Int
    ) async -> [Result<IndexedFilePath, UnableToParseFile>] {
        do {
            let result = try await readSingleMessage(
                path: path,
                originalIndex: originalIndex
            )
            return [.success(result)]
        } catch {
            // Try to see if this is a directory:
            guard let r = try? await readDirectory(directoryPath: path, originalIndex: originalIndex) else {
                return [.failure(error)]
            }
            return r
        }
    }

    /// Returns an array with one entry for each file in the directory at the given path.
    ///
    /// Throws an error if the directory can not be scanned, for example because it does not exist.
    static func readDirectory(
        directoryPath: FilePath,
        originalIndex: Int
    ) async throws -> [Result<IndexedFilePath, UnableToParseFile>] {
        let paths = try allRegularFiles(in: directoryPath)
        writeStatus("Did find \(paths.count) file(s) inside '\(directoryPath)'")

        var result: [Result<IndexedFilePath, UnableToParseFile>] = []
        for (subIndex, path) in paths.enumerated() {
            do {
                var r = try await readSingleMessage(
                    path: path,
                    originalIndex: originalIndex
                )
                r.nestedIndex = UInt32(subIndex)
                result.append(.success(r))
            } catch {
                result.append(.failure(error))
            }
        }
        return result
    }

    /// Returns the paths of all regular files inside the directory.
    ///
    /// This does _not_ recurse into sub-directories.
    static func allRegularFiles(
        in directoryPath: FilePath,
    ) throws -> [FilePath] {
        var paths: [FilePath] = []

        func add(dirent entry: UnsafePointer<dirent>) {
            let name = withRegularFileName(dirent: entry) { buffer -> FilePath.Component? in
                // `FilePath.Component(platformString:)` requires a NUL-terminated buffer;
                // `d_name` from `readdir` is not, so copy into a temp NUL-terminated buffer.
                withUnsafeTemporaryAllocation(
                    of: CInterop.PlatformChar.self,
                    capacity: buffer.count + 1
                ) { temp in
                    buffer.withMemoryRebound(to: CInterop.PlatformChar.self) { src in
                        let term = temp.initialize(from: src).index
                        temp[term] = 0
                    }
                    return temp.baseAddress.flatMap { FilePath.Component(platformString: $0) }
                }
            }
            guard let name else { return }
            paths.append(directoryPath.appending(name))
        }

        try scan(
            directory: directoryPath,
            closure: add(dirent:)
        )

        return paths
    }

    static func readSingleMessage(
        path: FilePath,
        originalIndex: Int
    ) async throws(UnableToParseFile) -> IndexedFilePath {
        do {
            // Read the first 100,000 bytes:
            let data = try await DispatchData(
                asyncContentsOf: path,
                length: 100_000
            )
            // Parse the date from it:
            guard
                let date = MessageHeaderParser.current.dateHeader(Data(data))
            else {
                throw NoMessageDateInFile()
            }
            guard
                let date = date.parse()
            else {
                throw UnableToParseDate(date: String(date))
            }
            return IndexedFilePath(
                originalIndex: UInt32(originalIndex),
                nestedIndex: 0,
                path: FilePathWithDate(
                    filePath: path,
                    date: date
                )
            )
        } catch {
            throw UnableToParseFile(
                filePath: path,
                underlying: error
            )
        }
    }
}

extension FileBasedMessageToAppendSequence {
    static func readAndSort(
        paths: [FilePath],
        options: Set<AppendOption>
    ) async throws -> [FilePathWithDate] {
        try await withThrowingTaskGroup { group in
            writeStatus("Reading and sorting \(paths.count) input path(s) by message date")
            for (index, path) in paths.enumerated() {
                group.addTask {
                    await readMessage(
                        path: path,
                        originalIndex: index
                    )
                }
            }

            // Bin results by `originalIndex` so input order is preserved without sorting.
            // Within each bin `nestedIndex` is in ascending order because `readDirectory`
            // assigns it from `enumerated()`.
            var bins: [[FilePathWithDate]] = Array(repeating: [], count: paths.count)
            while true {
                do {
                    guard
                        let nextBatch = try await group.next()
                    else { break }
                    for next in nextBatch {
                        switch next {
                        case .success(let s):
                            bins[Int(s.originalIndex)].append(s.path)
                        case .failure(let error):
                            writeErrorStatus(error: error)
                            guard options.contains(.skipErrors) else { throw error }
                        }
                    }
                } catch {
                    writeStatus("error: \(error)")
                    guard options.contains(.skipErrors) else { throw error }
                }
            }
            let inOrder = bins.flatMap { $0 }
            guard options.contains(.sort) else { return inOrder }
            return inOrder.sorted()
        }
    }
}

extension FileBasedMessageToAppendSequence {
    static func writeErrorStatus(
        error: UnableToParseFile
    ) {
        switch error.underlying {
        case is NoMessageDateInFile:
            writeStatus("error: message is missing 'date' header ('\(error.filePath)')")
        case let u as UnableToParseDate:
            writeStatus(
                "error: message 'date' header '\(u.date)' is not a valid RFC 5322 'date-time' ('\(error.filePath)')"
            )
        default:
            writeStatus("error: unable to parse file: \(error.underlying) ('\(error.filePath)')")
        }
    }

    struct NoMessageDateInFile: Swift.Error, Hashable {}

    struct UnableToParseDate: Swift.Error, Hashable {
        var date: String
    }

    struct UnableToParseFile: Swift.Error {
        var filePath: FilePath
        var underlying: any Swift.Error
    }
}
